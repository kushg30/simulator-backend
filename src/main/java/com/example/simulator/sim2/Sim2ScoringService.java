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
