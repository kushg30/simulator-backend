package com.example.simulator.sim1;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The end-of-simulation Final Results Screen (script section 8).
 *
 * <p>Everything here is recomputed from the decision log rather than read from the engine's rolling
 * 0-100 state, for three reasons: the screen reports the script's RAW point totals, it needs those
 * totals sliced per round for the trajectory chart, and the rolling state averages across
 * participants in a way that would understate a variable only two roles ever touch.
 */
@Service
@Transactional(readOnly = true)
public class Sim1ResultsService {

	/** Points are stored multiplied by this, so a raw ±1 can still move the live 0-100 band. */
	static final int SCALE = 10;

	private final Sim1ResultsRepository repo;
	private final Sim1ReportRepository reportRepo;

	public Sim1ResultsService(Sim1ResultsRepository repo, Sim1ReportRepository reportRepo) {
		this.repo = repo;
		this.reportRepo = reportRepo;
	}

	/** Display order, and the one variable where a bigger number is the worse result. */
	private static final List<String> VARS = List.of("trust", "governance", "rigor", "exposure");
	private static final String EXPOSURE = "exposure";

	public Map<String, Object> results(UUID runId) {
		Map<String, Object> header = reportRepo.findRunHeader(runId);
		if (header == null || header.isEmpty()) {
			throw new IllegalStateException("No such run");
		}
		UUID simulationId = (UUID) header.get("simulationId");

		// ── per-round points, answered and unanswered folded together ─────────
		Map<Integer, Map<String, Integer>> byRound = new LinkedHashMap<>();
		for (int r = 1; r <= 4; r++) {
			Map<String, Integer> zero = new LinkedHashMap<>();
			VARS.forEach(v -> zero.put(v, 0));
			byRound.put(r, zero);
		}
		addRows(byRound, repo.findAnsweredPointsByRound(runId, SCALE));
		addRows(byRound, repo.findSilencePointsByRound(runId, SCALE));

		Map<String, Integer> totals = new LinkedHashMap<>();
		VARS.forEach(v -> totals.put(v, 0));
		List<Map<String, Object>> trajectory = new ArrayList<>();
		for (int r = 1; r <= 4; r++) {
			Map<String, Object> point = new LinkedHashMap<>();
			point.put("round", r);
			for (String v : VARS) {
				totals.merge(v, byRound.get(r).get(v), Integer::sum);
				// Running total, which is what makes the chart show WHICH round set the result.
				point.put(v, totals.get(v));
			}
			trajectory.add(point);
		}

		// ── bands, from the range the authored table actually allows (3.4) ────
		Map<String, Object> range = repo.findPossibleRange(simulationId, SCALE);
		List<Map<String, Object>> variables = new ArrayList<>();
		for (String v : VARS) {
			int min = num(range.get("min" + cap(v)));
			int max = num(range.get("max" + cap(v)));
			Map<String, Object> m = new LinkedHashMap<>();
			m.put("key", v);
			m.put("points", totals.get(v));
			m.put("band", band(totals.get(v), min, max));
			m.put("min", min);
			m.put("max", max);
			m.put("lowerIsBetter", EXPOSURE.equals(v));
			variables.add(m);
		}
		Map<String, Object> out = new LinkedHashMap<>();
		out.put("teamName", header.get("teamName"));
		out.put("variables", variables);
		out.put("trajectory", trajectory);

		// ── composite, rank, and the cohort's shape (3.5) ─────────────────────
		int composite = composite(totals);
		out.put("composite", composite);

		// The composite is a SIGNED total — the three favourable variables minus the adverse one — so
		// it runs well below zero at the bad end. A bare "-27" read as a percentage or a mark out of
		// 100 is alarming and wrong; shipping the range it sits in makes it interpretable.
		int compMin = 0;
		int compMax = 0;
		for (String v : VARS) {
			int min = num(range.get("min" + cap(v)));
			int max = num(range.get("max" + cap(v)));
			if (EXPOSURE.equals(v)) {
				compMin -= max; // worst case takes on the most exposure
				compMax -= min;
			} else {
				compMin += min;
				compMax += max;
			}
		}
		out.put("compositeMin", compMin);
		out.put("compositeMax", compMax);

		List<int[]> cohort = new ArrayList<>(); // [composite, exposure, isYou]
		for (Map<String, Object> row : repo.findCohortTotals(simulationId, SCALE)) {
			Map<String, Integer> t = new LinkedHashMap<>();
			for (String v : VARS) {
				t.put(v, num(row.get(v)));
			}
			boolean isYou = runId.equals(row.get("runId"));
			cohort.add(new int[] { composite(t), t.get(EXPOSURE), isYou ? 1 : 0 });
		}
		// Highest composite first; between equal composites the team carrying less forward-looking
		// risk ranks higher, which is the script's stated tie-break.
		cohort.sort(Comparator.<int[]>comparingInt(a -> -a[0]).thenComparingInt(a -> a[1]));

		List<Map<String, Object>> bars = new ArrayList<>();
		int rank = 0;
		for (int i = 0; i < cohort.size(); i++) {
			int[] row = cohort.get(i);
			if (row[2] == 1) {
				rank = i + 1;
			}
			Map<String, Object> bar = new LinkedHashMap<>();
			// Anonymous by design: the chart exists so a team can see its result against the SHAPE of
			// the cohort. Naming the other teams would turn a distribution into a leaderboard, and no
			// team's result is anyone else's to read.
			bar.put("composite", row[0]);
			bar.put("isYou", row[2] == 1);
			bars.add(bar);
		}
		out.put("rank", rank);
		out.put("teamCount", cohort.size());
		out.put("cohort", bars);

		// ── the four framings, and the pattern they make (3.6) ────────────────
		Integer[] path = new Integer[4];
		List<Map<String, Object>> framings = new ArrayList<>();
		Map<Integer, Map<String, Object>> byRoundFraming = new LinkedHashMap<>();
		for (Map<String, Object> row : repo.findFramings(runId)) {
			byRoundFraming.put(num(row.get("round")), row);
		}
		for (int r = 1; r <= 4; r++) {
			Map<String, Object> row = byRoundFraming.get(r);
			Map<String, Object> f = new LinkedHashMap<>();
			f.put("round", r);
			boolean submitted = row != null && !"SILENCE".equals(row.get("action")) && row.get("optionNumber") != null;
			f.put("submitted", submitted);
			f.put("option", submitted ? num(row.get("optionNumber")) : null);
			f.put("label", submitted ? row.get("label") : null);
			if (submitted) {
				path[r - 1] = num(row.get("optionNumber"));
			}
			framings.add(f);
		}
		out.put("framings", framings);
		out.put("framingCommitment", framingCommitment(path));
		return out;
	}

	private int composite(Map<String, Integer> t) {
		// Exposure is subtracted, not added — it is the one variable where less is better.
		return t.get("trust") + t.get("governance") + t.get("rigor") - t.get(EXPOSURE);
	}

	/**
	 * Framing Commitment (script 3.6): a descriptive label for whether the team's framing hardened or
	 * moved, computed only from which numbered option the CEO picked each round. Never scored, never
	 * part of the ranking.
	 *
	 * <p>A round with no submitted decision is a GAP, not a zero: only pairs of rounds that both
	 * carry a real option are compared, so a missing round never manufactures a move in either
	 * direction. Two or more gaps leaves too little to label at all.
	 */
	private Map<String, Object> framingCommitment(Integer[] path) {
		List<Integer> present = new ArrayList<>();
		for (Integer p : path) {
			if (p != null) {
				present.add(p);
			}
		}

		Map<String, Object> out = new LinkedHashMap<>();
		out.put("path", new ArrayList<>(java.util.Arrays.asList(path))); // nulls preserved as gaps

		if (present.size() <= 2) {
			out.put("label", "Incomplete");
			out.put("note", "Two or more rounds have no submitted decision, so there is not enough of a "
					+ "path to name a pattern. The rounds that were submitted are shown above.");
			return out;
		}

		// Anchored first: one frame held for most of the simulation.
		for (int option = 1; option <= 3; option++) {
			int n = 0;
			for (int p : present) {
				if (p == option) {
					n++;
				}
			}
			if (n >= 3) {
				out.put("label", "Anchored");
				out.put("note", "The team held one framing for most of the simulation.");
				return out;
			}
		}

		// Direction is measured only between rounds that both carry a real option.
		int up = 0, down = 0;
		Integer prev = null;
		for (Integer p : path) {
			if (p == null) {
				continue;
			}
			if (prev != null) {
				if (p > prev) {
					up++;
				} else if (p < prev) {
					down++;
				}
			}
			prev = p;
		}
		if (up >= 2) {
			out.put("label", "Escalating");
			out.put("note", "The framing moved toward more formal governance ownership as the rounds went on.");
		} else if (down >= 2) {
			out.put("label", "De-escalating");
			out.put("note", "The team stepped back from an earlier, more formal framing.");
		} else {
			out.put("label", "Responsive");
			out.put("note", "The framing moved without a single clear direction. Whether that was adaptation "
					+ "to new evidence or inconsistency is a debrief question, not something this label decides.");
		}
		return out;
	}

	/**
	 * Bands are thirds of the range the authored table actually permits (3.4), not fixed thresholds —
	 * so editing the scoring table moves the band edges with it rather than silently skewing them.
	 * Note this bands the NUMBER, not its desirability: a High on Ethical Exposure is a bad result,
	 * which is why the screen labels that variable "lower is better" separately.
	 */
	private String band(int value, int min, int max) {
		if (max <= min) {
			return "Medium";
		}
		double third = (max - min) / 3.0;
		if (value >= min + 2 * third) {
			return "High";
		}
		return value >= min + third ? "Medium" : "Low";
	}

	private void addRows(Map<Integer, Map<String, Integer>> byRound, List<Map<String, Object>> rows) {
		for (Map<String, Object> row : rows) {
			Map<String, Integer> target = byRound.get(num(row.get("round")));
			if (target == null) {
				continue;
			}
			for (String v : VARS) {
				target.merge(v, num(row.get(v)), Integer::sum);
			}
		}
	}

	private static String cap(String s) {
		return Character.toUpperCase(s.charAt(0)) + s.substring(1);
	}

	private int num(Object o) {
		return o == null ? 0 : ((Number) o).intValue();
	}
}
