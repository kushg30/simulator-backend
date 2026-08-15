package com.example.simulator.sim2;

import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Computes the five Meridian constructs for a completed round.
 *
 * <p>Round 1 can genuinely score only three of them. Data Trust Score is defined as whether a
 * team's numbers survive <em>later</em> rounds, and Insight Communication has no signal until the
 * dashboard//framing rounds (R3, R6). Both are therefore recorded as {@code NOT_YET_SCORED} with a
 * null value rather than 0 — scoring them zero would silently understate every team on the
 * cohort leaderboard.
 */
@Service
@Transactional
public class Sim2ScoringService {

	public static final String DATA_TRUST = "DATA_TRUST_SCORE";
	public static final String ANALYTICAL_RIGOR = "ANALYTICAL_RIGOR";
	public static final String INSIGHT_COMMUNICATION = "INSIGHT_COMMUNICATION";
	public static final String JUDGMENT_CALIBRATION = "JUDGMENT_CALIBRATION";
	public static final String TURNAROUND_DISCIPLINE = "TURNAROUND_DISCIPLINE";

	private final Sim2Repository repository;

	public Sim2ScoringService(Sim2Repository repository) {
		this.repository = repository;
	}

	public void scoreRound(UUID runId, int roundNumber, boolean correct, String confidence,
			int activeSecondsUsed, int roundDurationMinutes) {

		// --- Analytical Rigor: did the answer-check pass? -------------------
		int rigor = correct ? 100 : 0;
		repository.upsertConstructScore(runId, roundNumber, ANALYTICAL_RIGOR, rigor, "SCORED",
				correct ? "Answer matched the canonical value" : "Answer did not match the canonical value");

		// --- Judgment Calibration: stated confidence vs actual correctness ---
		int calibration = calibration(correct, confidence);
		repository.upsertConstructScore(runId, roundNumber, JUDGMENT_CALIBRATION, calibration, "SCORED",
				"confidence=" + confidence + ", correct=" + correct);

		// --- Turnaround Discipline: finished inside the round window? -------
		// Uses ACTIVE time (wall-clock minus faculty-paused duration), so a paused
		// team is never penalised for time it did not have.
		int discipline = discipline(activeSecondsUsed, roundDurationMinutes);
		repository.upsertConstructScore(runId, roundNumber, TURNAROUND_DISCIPLINE, discipline, "SCORED",
				"used " + activeSecondsUsed + "s of " + (roundDurationMinutes * 60) + "s active time");

		// --- Deferred constructs: recorded explicitly, never as zero ---------
		repository.upsertConstructScore(runId, roundNumber, DATA_TRUST, null, "NOT_YET_SCORED",
				"Requires later rounds: measures whether these numbers survive without silent breakage");
		repository.upsertConstructScore(runId, roundNumber, INSIGHT_COMMUNICATION, null, "NOT_YET_SCORED",
				"No framing artifact in this round; first scored at R3/R6");
	}

	/**
	 * Scores a round that has no canonical answer (Round 6, the free-text consolidation round).
	 *
	 * <p>Only Turnaround Discipline can be measured. Analytical Rigor and Judgment Calibration
	 * depend on an answer check, so they are recorded as NOT_APPLICABLE for this round rather than
	 * zero, which would misrepresent a round that had nothing to get wrong. Data Trust Score and
	 * Insight Communication are run-level and are finalised separately at engagement end.
	 */
	public void scoreRoundNoAnswer(UUID runId, int roundNumber, int activeSecondsUsed,
			int roundDurationMinutes) {

		int discipline = discipline(activeSecondsUsed, roundDurationMinutes);
		repository.upsertConstructScore(runId, roundNumber, TURNAROUND_DISCIPLINE, discipline, "SCORED",
				"used " + activeSecondsUsed + "s of " + (roundDurationMinutes * 60) + "s active time");

		repository.upsertConstructScore(runId, roundNumber, ANALYTICAL_RIGOR, null, "NOT_APPLICABLE",
				"Consolidation round has no answer to check");
		repository.upsertConstructScore(runId, roundNumber, JUDGMENT_CALIBRATION, null, "NOT_APPLICABLE",
				"No correctness to calibrate against in the free-text round");
		repository.upsertConstructScore(runId, roundNumber, DATA_TRUST, null, "NOT_APPLICABLE",
				"Finalised at engagement end, not per round");
		repository.upsertConstructScore(runId, roundNumber, INSIGHT_COMMUNICATION, null, "NOT_APPLICABLE",
				"Finalised at engagement end, not per round");
	}

	/**
	 * Computes the five final construct scores for the whole run and stores them at round 0.
	 *
	 * <p>Three of them roll up the per-round scores. The remaining two - Data Trust Score and
	 * Insight Communication - are the run-level constructs deferred through Rounds 1-5, and are
	 * derived here from structured signals already captured (answer-checks and recorded twist
	 * choices). No file is parsed and no prose is interpreted; every input traces to something in
	 * the ledger, and each score carries a detail string explaining how it was reached so a
	 * facilitator can defend or override it.
	 */
	public void finalizeEngagement(UUID runId) {

		// --- the three answer-driven constructs: mean across played rounds ---
		finalizeMean(runId, ANALYTICAL_RIGOR);
		finalizeMean(runId, JUDGMENT_CALIBRATION);
		finalizeMean(runId, TURNAROUND_DISCIPLINE);

		// --- Data Trust Score (v4 cumulative weighting): 45% Round 1 outcome,
		// 15% Round 1 data-issue tag match, 40% Round 3 outcome. The Spot-Audit
		// penalty (-20, one team only) is applied by the facilitator as an override,
		// and a Round 4/5 fidelity mismatch is logged as a debrief flag, not weighted.
		boolean r1 = Boolean.TRUE.equals(repository.findRoundCorrect(runId, 1));
		boolean r3 = Boolean.TRUE.equals(repository.findRoundCorrect(runId, 3));
		int tagPts = round1TagPoints(runId); // 0..15
		int trust = (r1 ? 45 : 0) + tagPts + (r3 ? 40 : 0);
		trust = Math.max(0, Math.min(100, trust));
		String trustWhy = "R1 outcome " + (r1 ? "45" : "0") + "/45, R1 tag match " + tagPts
				+ "/15, R3 outcome " + (r3 ? "40" : "0") + "/40";
		repository.upsertConstructScore(runId, 0, DATA_TRUST, trust, "SCORED", trustWhy);

		// --- Board Clarity: provisional score from the captured free-text fields
		// (Rounds 1, 2, 3, and the R5 Board Brief), 50 pts for a field of adequate
		// length + 50 pts for citing a specific number. The Final Board Presentation
		// score entered live by the facilitator overrides this value.
		repository.upsertConstructScore(runId, 0, INSIGHT_COMMUNICATION, boardClarity(runId), "SCORED",
				"Provisional Board Clarity from free-text fields — refined live by the Final Board Presentation");
	}

	/**
	 * Round 1 data-issue tag match, worth up to 15 Data-Trust points. Full credit (15) only when all
	 * three required tags — Improper Formatting, Incomplete, Duplicated — are present with no false
	 * positive (Incorrect selected); partial credit (7) for exactly two of three, no false positive.
	 */
	private int round1TagPoints(UUID runId) {
		String tags = segment(runId, 1, "issues:").toLowerCase();
		if (tags.isBlank()) {
			return 0;
		}
		boolean falsePositive = tags.contains("incorrect");
		int matched = 0;
		if (tags.contains("improper formatting")) matched++;
		if (tags.contains("incomplete")) matched++;
		if (tags.contains("duplicated")) matched++;
		if (matched == 3 && !falsePositive) return 15;
		if (matched == 2 && !falsePositive) return 7;
		return 0;
	}

	/**
	 * Mean provisional Board Clarity across the free-text rounds: the Round 1/2/3 one-liners
	 * (length + cites a number) and the v5 Round 5 SCQA Complication (a keyword synthesis check).
	 */
	private int boardClarity(UUID runId) {
		int[] scores = {
				clarityForRound(runId, 1, "note:", 10),
				clarityForRound(runId, 2, "note:", 10),
				clarityForRound(runId, 3, "note:", 10),
				round5Clarity(runId),
		};
		int sum = 0;
		int n = 0;
		for (int s : scores) {
			if (s >= 0) {
				sum += s;
				n++;
			}
		}
		return n == 0 ? 0 : Math.round((float) sum / n);
	}

	/**
	 * v5 Round 5 synthesis clarity: a deterministic keyword check on the SCQA Complication field.
	 * Full credit (100) when it references facts from at least three of the four prior rounds,
	 * partial (50) for two, none below that. Returns -1 when Round 5 was not submitted.
	 */
	private int round5Clarity(UUID runId) {
		Map<String, Object> sub = repository.findSubmission(runId, 5);
		if (sub == null) {
			return -1;
		}
		String c = segment(runId, 5, "complication:").toLowerCase();
		int matched = 0;
		if (c.contains("62667") || c.contains("62,667") || c.contains("duplicate") || c.contains("trust")) matched++;
		if (c.contains("people") || c.contains("training") || c.contains("25.5")) matched++;
		if (c.contains("270") || c.contains("1381546") || c.contains("1,381,546") || c.contains("macro")) matched++;
		if (c.contains("notebook set") || c.contains("april")) matched++;
		if (matched >= 3) return 100;
		if (matched == 2) return 50;
		return 0;
	}

	/** 50 pts if the round's free-text field meets its length bar, +50 if it cites a number; -1 if absent. */
	private int clarityForRound(UUID runId, int roundNumber, String label, int minLen) {
		Map<String, Object> sub = repository.findSubmission(runId, roundNumber);
		if (sub == null) {
			return -1; // round not submitted — excluded from the mean, not scored zero
		}
		String text = segment(runId, roundNumber, label);
		int pts = 0;
		if (text.length() >= minLen) pts += 50;
		if (text.matches(".*\\d.*")) pts += 50;
		return pts;
	}

	/** Extracts a labelled segment from a stored typed answer, e.g. the text after "issues:" up to the next "|". */
	private String segment(UUID runId, int roundNumber, String label) {
		Map<String, Object> sub = repository.findSubmission(runId, roundNumber);
		if (sub == null || sub.get("typedAnswer") == null) {
			return "";
		}
		String s = String.valueOf(sub.get("typedAnswer"));
		int i = s.toLowerCase().indexOf(label.toLowerCase());
		if (i < 0) {
			return "";
		}
		String rest = s.substring(i + label.length());
		int bar = rest.indexOf('|');
		if (bar >= 0) {
			rest = rest.substring(0, bar);
		}
		return rest.trim();
	}

	private void finalizeMean(UUID runId, String construct) {
		Integer mean = repository.findConstructMean(runId, construct);
		if (mean != null) {
			repository.upsertConstructScore(runId, 0, construct, mean, "SCORED",
					"Mean across played rounds");
		} else {
			repository.upsertConstructScore(runId, 0, construct, null, "NOT_APPLICABLE",
					"No scored rounds to average");
		}
	}

	/**
	 * Confidence x correctness. High-and-wrong is the worst cell in the matrix — it is the exact
	 * pattern the facilitator debrief is asked to surface. Low-and-right is mildly penalised as
	 * under-confidence; low-and-wrong is well-calibrated and scores mid.
	 */
	int calibration(boolean correct, String confidence) {
		// v4 confidence x correctness matrix (consolidated construct definitions).
		String c = confidence == null ? "MEDIUM" : confidence.toUpperCase();
		if (correct) {
			return switch (c) {
				case "HIGH" -> 100;
				case "MEDIUM" -> 75;
				default -> 60; // right, but did not back itself
			};
		}
		return switch (c) {
			case "HIGH" -> 0; // confidently wrong
			case "MEDIUM" -> 25;
			default -> 40; // wrong, but flagged the doubt
		};
	}

	/** 100 while comfortably inside the window, tapering to 0 once the window is doubled. */
	int discipline(int activeSecondsUsed, int roundDurationMinutes) {
		int windowSeconds = Math.max(1, roundDurationMinutes * 60);
		double ratio = (double) activeSecondsUsed / windowSeconds;
		if (ratio <= 1.0) {
			return 100;
		}
		if (ratio >= 2.0) {
			return 0;
		}
		return (int) Math.round((2.0 - ratio) * 100);
	}
}
