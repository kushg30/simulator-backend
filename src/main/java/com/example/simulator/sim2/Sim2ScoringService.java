package com.example.simulator.sim2;

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

		// --- Data Trust Score: did the numbers survive without silent breakage? ---
		int trust = 100;
		StringBuilder trustWhy = new StringBuilder();
		Boolean r5 = repository.findRoundCorrect(runId, 5); // fidelity check vs the R3 figure
		if (Boolean.FALSE.equals(r5)) {
			trust -= 35;
			trustWhy.append("R5 fidelity check failed (numbers did not reproduce); ");
		} else if (r5 == null) {
			trust -= 15;
			trustWhy.append("R5 fidelity check not attempted; ");
		}
		if (Boolean.FALSE.equals(repository.findRoundCorrect(runId, 3))) {
			trust -= 15;
			trustWhy.append("R3 source figure was wrong; ");
		}
		if ("DELETE_ROWS".equals(repository.findRoundAction(runId, 1))) {
			trust -= 20;
			trustWhy.append("R1 rows deleted (traceability lost); ");
		}
		if ("DROP_UNMATCHED".equals(repository.findRoundAction(runId, 4))) {
			trust -= 20;
			trustWhy.append("R4 stores dropped (coverage lost); ");
		}
		trust = Math.max(0, Math.min(100, trust));
		repository.upsertConstructScore(runId, 0, DATA_TRUST, trust, "SCORED",
				trustWhy.length() == 0 ? "Numbers survived across rounds with no breakage signals"
						: trustWhy.toString().trim());

		// --- Insight Communication: an argument the Board could act on ---
		// The clearest structured signal is the R3 "keep it to one screen" framing decision.
		String framing = repository.findRoundAction(runId, 3);
		int insight;
		String insightWhy;
		if ("CUT_TO_ESSENTIAL".equals(framing)) {
			insight = 100;
			insightWhy = "R3: cut to essential fields — a clean, Board-actionable summary";
		} else if ("SHRINK_TO_FIT".equals(framing)) {
			insight = 60;
			insightWhy = "R3: shrank everything to fit — readable but not prioritised";
		} else if ("SPLIT_TWO_SCREENS".equals(framing)) {
			insight = 25;
			insightWhy = "R3: split across two screens — ignored the Board's one-screen constraint";
		} else {
			insight = 50;
			insightWhy = "No R3 framing decision on record; neutral default pending facilitator review";
		}
		repository.upsertConstructScore(runId, 0, INSIGHT_COMMUNICATION, insight, "SCORED", insightWhy);
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
		String c = confidence == null ? "MEDIUM" : confidence.toUpperCase();
		if (correct) {
			return switch (c) {
				case "HIGH" -> 100;
				case "MEDIUM" -> 80;
				default -> 60; // right, but did not back itself
			};
		}
		return switch (c) {
			case "HIGH" -> 0; // confidently wrong
			case "MEDIUM" -> 35;
			default -> 55; // wrong, but flagged the doubt
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
