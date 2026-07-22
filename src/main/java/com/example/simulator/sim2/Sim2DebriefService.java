package com.example.simulator.sim2;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Cohort debrief for Simulator 2 — the final-reveal analytics from spec section 8.
 *
 * <p>Produces the cross-team leaderboard, a single team's standing within the cohort, and the two
 * facilitator highlights the spec calls for: the round where Data Trust first dropped and whether it
 * compounded, and any round answered with High confidence but wrong.
 */
@Service
@Transactional(readOnly = true)
public class Sim2DebriefService {

	private final Sim2Repository repository;

	public Sim2DebriefService(Sim2Repository repository) {
		this.repository = repository;
	}

	private static final List<String> CONSTRUCTS = List.of(
			Sim2ScoringService.DATA_TRUST, Sim2ScoringService.ANALYTICAL_RIGOR,
			Sim2ScoringService.INSIGHT_COMMUNICATION, Sim2ScoringService.JUDGMENT_CALIBRATION,
			Sim2ScoringService.TURNAROUND_DISCIPLINE);

	/** One finalised team and its five construct values. Rows arrive ordered latest-finished first. */
	private record TeamScores(UUID runId, String teamName, String simulationName, Object startedAt,
			Object finishedAt, Map<String, Integer> values) {
	}

	private List<TeamScores> cohort(UUID simulationId) {
		Map<UUID, TeamScores> byRun = new LinkedHashMap<>();
		for (Map<String, Object> row : repository.findCohortFinalScores(simulationId)) {
			UUID runId = (UUID) row.get("runId");
			TeamScores t = byRun.computeIfAbsent(runId,
					k -> new TeamScores(runId, (String) row.get("teamName"),
							(String) row.get("simulationName"), row.get("startedAt"),
							row.get("finishedAt"), new LinkedHashMap<>()));
			Object v = row.get("value");
			if (v != null) {
				t.values().put((String) row.get("construct"), ((Number) v).intValue());
			}
		}
		return new ArrayList<>(byRun.values()); // insertion order = finished-at desc
	}

	// ------------------------------------------------------------- leaderboard

	/**
	 * Per construct, teams ranked high to low, each with its rank and percentile. Percentile is the
	 * share of the cohort a team scored at least as high as, so the top team is 100.
	 */
	public Map<String, Object> leaderboard(UUID simulationId) {
		List<TeamScores> teams = cohort(simulationId);
		Map<String, Object> out = new LinkedHashMap<>();
		out.put("teamCount", teams.size());

		Map<String, Object> byConstruct = new LinkedHashMap<>();
		for (String construct : CONSTRUCTS) {
			List<TeamScores> ranked = teams.stream()
					.filter(t -> t.values().containsKey(construct))
					.sorted(Comparator.comparingInt((TeamScores t) -> t.values().get(construct)).reversed())
					.toList();

			List<Map<String, Object>> rows = new ArrayList<>();
			for (TeamScores t : ranked) {
				Map<String, Object> r = new LinkedHashMap<>();
				r.put("teamName", t.teamName());
				r.put("value", t.values().get(construct));
				r.put("rank", competitionRank(ranked, t, construct));
				r.put("percentile", percentile(ranked, t, construct));
				rows.add(r);
			}
			byConstruct.put(construct, rows);
		}
		out.put("constructs", byConstruct);
		return out;
	}

	/** Where one team sits in the cohort, per construct: value, rank of N, and percentile. */
	public List<Map<String, Object>> teamStanding(UUID simulationId, UUID runId) {
		List<TeamScores> teams = cohort(simulationId);
		List<Map<String, Object>> out = new ArrayList<>();

		for (String construct : CONSTRUCTS) {
			List<TeamScores> ranked = teams.stream()
					.filter(t -> t.values().containsKey(construct))
					.sorted(Comparator.comparingInt((TeamScores t) -> t.values().get(construct)).reversed())
					.toList();

			TeamScores me = ranked.stream().filter(t -> t.runId().equals(runId)).findFirst().orElse(null);
			if (me == null) {
				continue;
			}
			Map<String, Object> r = new LinkedHashMap<>();
			r.put("construct", construct);
			r.put("value", me.values().get(construct));
			r.put("rank", competitionRank(ranked, me, construct));
			r.put("outOf", ranked.size());
			r.put("percentile", percentile(ranked, me, construct));
			out.add(r);
		}
		return out;
	}

	/** Standard competition ranking: 1 + the number of teams that scored strictly higher, so ties share a rank. */
	private int competitionRank(List<TeamScores> ranked, TeamScores team, String construct) {
		int myValue = team.values().get(construct);
		long above = ranked.stream().filter(t -> t.values().get(construct) > myValue).count();
		return (int) above + 1;
	}

	private int percentile(List<TeamScores> ranked, TeamScores team, String construct) {
		if (ranked.size() <= 1) {
			return 100;
		}
		int myValue = team.values().get(construct);
		long atOrBelow = ranked.stream().filter(t -> t.values().get(construct) <= myValue).count();
		return (int) Math.round(100.0 * atOrBelow / ranked.size());
	}

	// --------------------------------------------------------------- flags

	/** Full facilitator debrief: every finalised team with its scores and the highlight flags. */
	public Map<String, Object> debrief(UUID simulationId) {
		List<TeamScores> teams = cohort(simulationId);
		List<Map<String, Object>> rows = new ArrayList<>();

		for (TeamScores t : teams) {
			Map<String, Object> r = new LinkedHashMap<>();
			r.put("runId", t.runId());
			r.put("teamName", t.teamName());
			r.put("startedAt", t.startedAt());
			r.put("finishedAt", t.finishedAt());
			r.put("scores", t.values());
			r.putAll(flags(t.runId()));
			rows.add(r);
		}

		Map<String, Object> out = new LinkedHashMap<>();
		out.put("simulationName", teams.isEmpty() ? null : teams.get(0).simulationName());
		out.put("teams", rows); // latest finished first
		out.put("leaderboard", leaderboard(simulationId));
		return out;
	}

	/**
	 * The two spec highlights for one team:
	 * <ul>
	 *   <li>the round where Data Trust first dropped, and whether it compounded;</li>
	 *   <li>rounds answered with High confidence but wrong.</li>
	 * </ul>
	 * Data Trust is a run-level construct, so its per-round trajectory is reconstructed from the
	 * same recorded signals that produced the final score.
	 */
	public Map<String, Object> flags(UUID runId) {
		// Rounds that damaged data trust, in order.
		List<Integer> dropRounds = new ArrayList<>();
		if ("DELETE_ROWS".equals(repository.findRoundAction(runId, 1))) {
			dropRounds.add(1);
		}
		if (Boolean.FALSE.equals(repository.findRoundCorrect(runId, 3))) {
			dropRounds.add(3);
		}
		if ("DROP_UNMATCHED".equals(repository.findRoundAction(runId, 4))) {
			dropRounds.add(4);
		}
		if (Boolean.FALSE.equals(repository.findRoundCorrect(runId, 5))) {
			dropRounds.add(5);
		}

		Map<String, Object> out = new LinkedHashMap<>();
		out.put("dataTrustFirstDropRound", dropRounds.isEmpty() ? null : dropRounds.get(0));
		out.put("dataTrustDropCount", dropRounds.size());
		// "Compounded" if it dropped more than once; "held" if it dropped once and never again.
		out.put("dataTrustPattern",
				dropRounds.isEmpty() ? "never dropped"
						: dropRounds.size() > 1 ? "compounded across rounds"
								: "dropped once, then held");
		out.put("highConfidenceWrongRounds", repository.findHighConfidenceWrongRounds(runId));
		return out;
	}
}
