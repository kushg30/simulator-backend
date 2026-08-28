package com.example.simulator.sim2;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import java.util.Set;

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
	private final Sim2GradingService grading;

	public Sim2DebriefService(Sim2Repository repository, Sim2GradingService grading) {
		this.repository = repository;
		this.grading = grading;
	}

	private static final List<String> CONSTRUCTS = List.of(
			Sim2ScoringService.DATA_TRUST, Sim2ScoringService.ANALYTICAL_RIGOR,
			Sim2ScoringService.INSIGHT_COMMUNICATION, Sim2ScoringService.JUDGMENT_CALIBRATION,
			Sim2ScoringService.TURNAROUND_DISCIPLINE);

	private static final Set<String> VALID_CONSTRUCTS = Set.copyOf(CONSTRUCTS);

	/** One finalised team and its five construct values. Rows arrive ordered latest-finished first. */
	private record TeamScores(UUID runId, String teamName, String simulationName, Object startedAt,
			Object finishedAt, Map<String, Integer> values, Map<String, String> overrides) {
	}

	private List<TeamScores> cohort(UUID simulationId) {
		Map<UUID, TeamScores> byRun = new LinkedHashMap<>();
		for (Map<String, Object> row : repository.findCohortFinalScores(simulationId)) {
			UUID runId = (UUID) row.get("runId");
			TeamScores t = byRun.computeIfAbsent(runId,
					k -> new TeamScores(runId, (String) row.get("teamName"),
							(String) row.get("simulationName"), row.get("startedAt"),
							row.get("finishedAt"), new LinkedHashMap<>(), new LinkedHashMap<>()));
			Object v = row.get("value");
			String construct = (String) row.get("construct");
			if (v != null) {
				t.values().put(construct, ((Number) v).intValue());
			}
			if (row.get("overriddenBy") != null) {
				t.overrides().put(construct, (String) row.get("overriddenBy"));
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

	/**
	 * Partial reveal shown between Rounds 2 and 3: Data Trust (running/provisional) and Turnaround
	 * Discipline only, ranked across every team that has completed Round 2. The other three
	 * constructs and the final rank stay hidden until the end. Data Trust here is provisional —
	 * derived from the data-quality signals available so far (the R2 SKU-twist resolution and the
	 * R1/R2 answer-checks); the final Data Trust adds the later-round signals.
	 */
	public Map<String, Object> partialLeaderboard(UUID simulationId) {
		List<Map<String, Object>> rows = new ArrayList<>();
		for (Map<String, Object> run : repository.findRunsCompletedRound(simulationId, 2)) {
			UUID runId = (UUID) run.get("runId");
			int trust = 100;
			if ("APPLY_TO_ALL_SALES".equals(repository.findRoundAction(runId, 2))) {
				trust -= 20;
			}
			if (Boolean.FALSE.equals(repository.findRoundCorrect(runId, 1))) {
				trust -= 15;
			}
			if (Boolean.FALSE.equals(repository.findRoundCorrect(runId, 2))) {
				trust -= 15;
			}
			trust = Math.max(0, Math.min(100, trust));
			Integer turnaround = repository.findConstructMean(runId, Sim2ScoringService.TURNAROUND_DISCIPLINE);

			Map<String, Object> r = new LinkedHashMap<>();
			r.put("teamName", run.get("teamName"));
			r.put("dataTrust", trust);
			r.put("turnaround", turnaround);
			rows.add(r);
		}
		rows.sort((a, b) -> {
			int c = Integer.compare((int) b.get("dataTrust"), (int) a.get("dataTrust"));
			if (c != 0) {
				return c;
			}
			int ta = a.get("turnaround") == null ? 0 : (int) a.get("turnaround");
			int tb = b.get("turnaround") == null ? 0 : (int) b.get("turnaround");
			return Integer.compare(tb, ta);
		});
		for (int i = 0; i < rows.size(); i++) {
			rows.get(i).put("rank", i + 1);
		}
		Map<String, Object> out = new LinkedHashMap<>();
		out.put("teams", rows);
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

	// --------------------------------------------------------------- override

	/**
	 * Overrides a finalised construct for a team. Data Trust and Insight Communication are
	 * proxy-derived, so a facilitator with the workbook in hand may adjust them; any construct can
	 * be overridden. The auto value is preserved for revert, and the change is logged.
	 */
	@Transactional
	public Map<String, Object> override(UUID runId, String construct, int value, String actor,
			String reason) {
		if (!VALID_CONSTRUCTS.contains(construct)) {
			throw new IllegalArgumentException("Unknown construct: " + construct);
		}
		if (value < 0 || value > 100) {
			throw new IllegalArgumentException("A construct score must be between 0 and 100");
		}
		if (repository.countFinalConstruct(runId, construct) == 0) {
			throw new IllegalStateException(
					"This team has no finalised " + construct + " to override yet");
		}
		repository.overrideConstruct(runId, construct, value, actor == null ? "facilitator" : actor,
				reason);
		repository.logOverride(runId,
				"Override " + construct + " -> " + value + (reason == null ? "" : " (" + reason + ")"),
				actor == null ? "facilitator" : actor,
				"{\"construct\":\"" + construct + "\",\"value\":" + value + "}");
		return Map.of("runId", runId, "construct", construct, "value", value, "overridden", true);
	}

	@Transactional
	public Map<String, Object> revert(UUID runId, String construct, String actor) {
		if (!VALID_CONSTRUCTS.contains(construct)) {
			throw new IllegalArgumentException("Unknown construct: " + construct);
		}
		repository.revertConstruct(runId, construct);
		repository.logOverride(runId, "Revert " + construct + " to the auto-computed score",
				actor == null ? "facilitator" : actor,
				"{\"construct\":\"" + construct + "\",\"reverted\":true}");
		return Map.of("runId", runId, "construct", construct, "reverted", true);
	}

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
			r.put("overrides", t.overrides()); // construct -> facilitator who overrode it
			// Per-round answers for the grid: [{roundNumber, correct, outcomePct, confidence,
			// typedAnswer, feedback:[{label, ok, detail}]}] — feedback names the fields missed.
			List<Map<String, Object>> subs = new ArrayList<>();
			for (Map<String, Object> row : repository.findSubmissionTimeline(t.runId())) {
				Map<String, Object> sub = new LinkedHashMap<>(row);
				Object rn = row.get("roundNumber");
				if (rn != null) {
					Object ans = row.get("typedAnswer");
					sub.put("feedback",
							grading.fieldBreakdown(((Number) rn).intValue(), ans == null ? "" : ans.toString()));
				}
				subs.add(sub);
			}
			r.put("submissions", subs);
			r.put("participants", repository.findRunParticipants(t.runId())); // roster for the report
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
		// Rounds that damaged data trust, in order (v2 signals).
		List<Integer> dropRounds = new ArrayList<>();
		if ("APPLY_TO_ALL_SALES".equals(repository.findRoundAction(runId, 2))
				|| Boolean.FALSE.equals(repository.findRoundCorrect(runId, 2))) {
			dropRounds.add(2);
		}
		if (Boolean.FALSE.equals(repository.findRoundCorrect(runId, 3))) {
			dropRounds.add(3);
		}
		if (Boolean.FALSE.equals(repository.findRoundCorrect(runId, 5))) {
			dropRounds.add(5);
		}

		Map<String, Object> out = new LinkedHashMap<>();
		out.put("dataTrustFirstDropRound", dropRounds.isEmpty() ? null : dropRounds.get(0));
		out.put("dataTrustDropRounds", dropRounds); // full list, for the trajectory chart
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
