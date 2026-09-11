package com.example.simulator.sim1;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The Simulator 1 team report and the cohort ranking behind it.
 *
 * <p>One payload serves both audiences. The facilitator opens it per team from the console; the team
 * itself opens it from the results screen once the simulation is complete. It carries no other team's
 * name — a team sees its own rank and percentile within the cohort, never the ordered list — so the
 * same endpoint is safe on a student route.
 *
 * <p>Set-A values stay out of the student payload as numbers: the four hidden variables are revealed
 * qualitatively (High / Medium / Low) exactly as the facilitator reveals them in the room.
 */
@Service
@Transactional(readOnly = true)
public class Sim1ReportService {

	private final Sim1ReportRepository repo;
	private final Sim1ConstructService constructs;
	private final com.example.simulator.simulation.Sim1DebriefRepository debriefRepo;

	public Sim1ReportService(Sim1ReportRepository repo, Sim1ConstructService constructs,
			com.example.simulator.simulation.Sim1DebriefRepository debriefRepo) {
		this.repo = repo;
		this.constructs = constructs;
		this.debriefRepo = debriefRepo;
	}

	/** Set-A keys in report order. Trust and Execution read high-is-good; the other two are adverse. */
	private static final List<String> SET_A = List.of(
			"stakeholder_trust", "organizational_risk", "execution_quality", "ethical_exposure");
	private static final Set<String> SET_A_ADVERSE = Set.of("organizational_risk", "ethical_exposure");

	// ------------------------------------------------------------------ report

	/** The facilitator's copy: identical layout, but with the scoring internals left in. */
	public Map<String, Object> report(UUID runId) {
		return report(runId, true);
	}

	/**
	 * Everything the team report renders, for one run.
	 *
	 * @param includeInternals true for the facilitator. When false the payload is stripped for a
	 *        student audience: construct bands without the 0-100 values behind them, no per-participant
	 *        scores (a teammate's individual profile is not the team's to read), and none of the
	 *        Option-Space interaction terms — those are the scoring model itself, and publishing them in
	 *        a downloadable PDF would hand over enough to reconstruct it.
	 */
	public Map<String, Object> report(UUID runId, boolean includeInternals) {
		Map<String, Object> header = repo.findRunHeader(runId);
		if (header == null || header.isEmpty()) {
			throw new IllegalStateException("No such run");
		}
		UUID simulationId = (UUID) header.get("simulationId");

		Map<String, Object> out = new LinkedHashMap<>();
		out.put("runId", runId);
		out.put("teamName", header.get("teamName"));
		out.put("simulationName", header.get("simulationName"));
		out.put("startedAt", header.get("startedAt"));
		out.put("status", header.get("status"));
		out.put("roundsReached", repo.findRoundsReached(runId));

		// ── roster: who sat in which seat, and how much of their feed they answered ──
		List<Map<String, Object>> roster = new ArrayList<>();
		int teamAnswered = 0;
		int teamSilent = 0;
		for (Map<String, Object> r : repo.findRoster(runId)) {
			int answered = num(r.get("answered"));
			int silent = num(r.get("noResponses"));
			teamAnswered += answered;
			teamSilent += silent;
			Map<String, Object> m = new LinkedHashMap<>();
			m.put("role", r.get("role"));
			m.put("name", r.get("name"));
			m.put("answered", answered);
			m.put("noResponses", silent);
			m.put("addressed", answered + silent);
			roster.add(m);
		}
		out.put("participants", roster);
		out.put("decisionsAnswered", teamAnswered);
		out.put("noResponses", teamSilent);

		// ── the trail, and the CEO framing that closed each round ──
		List<Map<String, Object>> trail = new ArrayList<>();
		Map<Integer, Map<String, Object>> framings = new LinkedHashMap<>();
		for (Map<String, Object> row : repo.findDecisionTrail(runId)) {
			boolean silence = "SILENCE".equals(row.get("action"));
			Map<String, Object> m = new LinkedHashMap<>();
			m.put("round", num(row.get("round")));
			m.put("artifactTitle", row.get("artifactTitle"));
			m.put("role", row.get("role"));
			m.put("name", row.get("name"));
			m.put("action", row.get("action"));
			// A No Response is its own outcome, never one of the authored options — so it has no label
			// and the report must not borrow one.
			m.put("label", silence ? null : row.get("label"));
			m.put("noResponse", silence);
			m.put("decidedAt", row.get("decidedAt"));
			// EXPLICIT decisions are the deliberate, scripted choice points; IMPLICIT ones are the
			// ambient reactions. The report curates on this rather than printing all 78 rows.
			m.put("decisionType", row.get("decisionType"));
			boolean isFinal = Boolean.TRUE.equals(row.get("isFinal"));
			m.put("isFinal", isFinal);
			trail.add(m);
			if (isFinal) {
				framings.put(num(row.get("round")), m);
			}
		}
		// The decision trail is the facilitator's audit view. It is not in the student report: a team
		// already lived its own decisions, and the artifact titles plus the exact option wording are the
		// most directly copyable part of the scenario. Omitted from the payload, not just the page, so
		// it cannot be read out of the network response either.
		if (includeInternals) {
			out.put("trail", trail);
		}

		List<Map<String, Object>> rounds = new ArrayList<>();
		for (int n = 1; n <= 4; n++) {
			Map<String, Object> f = framings.get(n);
			Map<String, Object> m = new LinkedHashMap<>();
			m.put("round", n);
			m.put("framing", f == null ? null : f.get("label"));
			m.put("submitted", f != null && !Boolean.TRUE.equals(f.get("noResponse")));
			rounds.add(m);
		}
		out.put("rounds", rounds);

		// ── Set A, as bands only ──
		Map<String, Object> setA = new LinkedHashMap<>();
		Map<String, Integer> setAValues = teamSetA(simulationId, runId);
		for (String c : SET_A) {
			Integer v = setAValues.get(c);
			Map<String, Object> m = new LinkedHashMap<>();
			m.put("band", v == null ? null : bandLabel(v));
			m.put("adverse", SET_A_ADVERSE.contains(c));
			setA.put(c, m);
		}
		out.put("setA", setA);

		// ── Set B, with the team's standing in the cohort ──
		Map<String, Object> b = constructs.constructs(runId);
		out.put("setB", includeInternals ? b.get("team") : studentSafeSetB(b.get("team")));
		if (includeInternals) {
			out.put("setBParticipants", b.get("participants"));
		}
		out.put("constructOrder", Sim1ConstructService.CONSTRUCTS);
		out.put("standing", standing(simulationId, runId));
		return out;
	}

	/**
	 * The team-level Set-B block with the scoring internals removed: each construct keeps its band but
	 * loses the 0-100 value, and the Option-Space effects collapse to the one qualitative fact the
	 * report actually states — whether the Round-1 silence threshold was crossed.
	 */
	@SuppressWarnings("unchecked")
	private Map<String, Object> studentSafeSetB(Object team) {
		Map<String, Object> src = (Map<String, Object>) team;
		Map<String, Object> out = new LinkedHashMap<>();

		Map<String, Object> cons = new LinkedHashMap<>();
		Map<String, Object> srcCons = (Map<String, Object>) src.get("constructs");
		for (String c : Sim1ConstructService.CONSTRUCTS) {
			Map<String, Object> node = (Map<String, Object>) srcCons.get(c);
			cons.put(c, node == null ? null : Map.of("band", node.get("band")));
		}
		out.put("constructs", cons);
		out.put("dominantPattern", src.get("dominantPattern"));
		out.put("insights", src.get("insights"));

		Map<String, Object> effects = (Map<String, Object>) src.get("effects");
		out.put("effects", Map.of("escalationForeclosed",
				Boolean.TRUE.equals(effects.get("escalationForeclosed"))));
		return out;
	}

	/** A team's rank and percentile per Set-B construct, without naming any other team. */
	private Map<String, Object> standing(UUID simulationId, UUID runId) {
		Map<String, Object> board = leaderboard(simulationId);
		Map<String, Object> out = new LinkedHashMap<>();
		out.put("teamCount", board.get("teamCount"));
		@SuppressWarnings("unchecked")
		Map<String, List<Map<String, Object>>> byConstruct =
				(Map<String, List<Map<String, Object>>>) board.get("constructs");
		Map<String, Object> mine = new LinkedHashMap<>();
		for (String c : Sim1ConstructService.CONSTRUCTS) {
			for (Map<String, Object> row : byConstruct.getOrDefault(c, List.of())) {
				if (runId.equals(row.get("runId"))) {
					Map<String, Object> m = new LinkedHashMap<>();
					m.put("rank", row.get("rank"));
					m.put("percentile", row.get("percentile"));
					m.put("outOf", board.get("teamCount"));
					mine.put(c, m);
					break;
				}
			}
		}
		out.put("constructs", mine);
		return out;
	}

	// ------------------------------------------------------------- leaderboard

	/**
	 * Cohort ranking per Set-B construct, mirroring Sim 2: teams ordered best-first with a competition
	 * rank and a percentile.
	 *
	 * <p>"Best" is not the same as "highest" here. Early Signal Legitimization is the only construct
	 * where a high value is good; the other four measure pressure building against the team, so those
	 * are ranked ASCENDING. Ranking all five by raw value would put the worst-performing team at the
	 * top of four of the five boards.
	 */
	public Map<String, Object> leaderboard(UUID simulationId) {
		List<Map<String, Object>> teams = new ArrayList<>();
		for (Map<String, Object> run : constructsCohort(simulationId)) {
			teams.add(run);
		}

		Map<String, Object> out = new LinkedHashMap<>();
		out.put("teamCount", teams.size());

		Map<String, Object> byConstruct = new LinkedHashMap<>();
		for (String c : Sim1ConstructService.CONSTRUCTS) {
			boolean adverse = Sim1ConstructService.ADVERSE.contains(c);
			List<Map<String, Object>> ranked = new ArrayList<>(teams);
			Comparator<Map<String, Object>> byValue = Comparator.comparingInt(t -> valueOf(t, c));
			ranked.sort(adverse ? byValue : byValue.reversed());

			List<Map<String, Object>> rows = new ArrayList<>();
			for (Map<String, Object> t : ranked) {
				int v = valueOf(t, c);
				// Standard competition ranking on the "better" direction, so ties share a rank.
				long better = ranked.stream()
						.filter(o -> adverse ? valueOf(o, c) < v : valueOf(o, c) > v)
						.count();
				long atOrBehind = ranked.stream()
						.filter(o -> adverse ? valueOf(o, c) >= v : valueOf(o, c) <= v)
						.count();
				Map<String, Object> r = new LinkedHashMap<>();
				r.put("runId", t.get("runId"));
				r.put("teamName", t.get("teamName"));
				r.put("value", v);
				r.put("band", bandLabel(v));
				r.put("rank", (int) better + 1);
				r.put("percentile", ranked.size() <= 1 ? 100
						: (int) Math.round(100.0 * atOrBehind / ranked.size()));
				rows.add(r);
			}
			byConstruct.put(c, rows);
		}
		out.put("constructs", byConstruct);
		out.put("adverse", Sim1ConstructService.ADVERSE);
		return out;
	}

	/** One flat row per team: runId, teamName, and the team-level value of each Set-B construct. */
	@SuppressWarnings("unchecked")
	private List<Map<String, Object>> constructsCohort(UUID simulationId) {
		List<Map<String, Object>> out = new ArrayList<>();
		Map<String, Object> cohort = constructs.cohort(simulationId);
		for (Map<String, Object> t : (List<Map<String, Object>>) cohort.get("teams")) {
			Map<String, Object> team = (Map<String, Object>) t.get("team");
			Map<String, Object> cons = (Map<String, Object>) team.get("constructs");
			Map<String, Object> row = new LinkedHashMap<>();
			row.put("runId", t.get("runId"));
			row.put("teamName", t.get("teamName"));
			for (String c : Sim1ConstructService.CONSTRUCTS) {
				Map<String, Object> node = (Map<String, Object>) cons.get(c);
				row.put(c, node == null ? 50 : num(node.get("value")));
			}
			out.add(row);
		}
		return out;
	}

	private int valueOf(Map<String, Object> team, String construct) {
		return num(team.get(construct));
	}

	// -------------------------------------------------------------- Set A roll-up

	/** Team means of the four hidden variables, from the same rows the faculty debrief reads. */
	private Map<String, Integer> teamSetA(UUID simulationId, UUID runId) {
		Map<String, int[]> acc = new LinkedHashMap<>(); // construct -> [sum, n]
		for (Map<String, Object> row : debriefRepo.findConstructRows(simulationId)) {
			if (!runId.equals(row.get("runId"))) {
				continue;
			}
			String c = (String) row.get("construct");
			Object v = row.get("value");
			if (c == null || v == null) {
				continue;
			}
			int[] a = acc.computeIfAbsent(c, k -> new int[2]);
			a[0] += ((Number) v).intValue();
			a[1]++;
		}
		Map<String, Integer> out = new LinkedHashMap<>();
		acc.forEach((c, a) -> out.put(c, a[1] == 0 ? null : Math.round((float) a[0] / a[1])));
		return out;
	}

	// ------------------------------------------------------------------ helpers

	/** Banding matches the console and the student reveal exactly: >=67 High, >=34 Medium, else Low. */
	private String bandLabel(int v) {
		return v >= 67 ? "High" : v >= 34 ? "Medium" : "Low";
	}

	private int num(Object o) {
		return o == null ? 0 : ((Number) o).intValue();
	}
}
