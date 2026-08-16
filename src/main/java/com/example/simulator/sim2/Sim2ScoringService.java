package com.example.simulator.sim2;

import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Computes the five Meridian constructs (v6).
 *
 * <p>v6 scores every round on a 0-100 <em>Outcome</em> (per-field partial credit), never all-or-
 * nothing. Analytical Rigor is a 3-point model (process check + justification + evidence). Judgment
 * Calibration keys on whether the Outcome hit 100%. Data Trust Score and Board Clarity are run-level
 * and finalised at engagement end. Per-round scoring runs <em>before</em> the submission row is
 * written, so it reads the passed typed answer directly; the run-level finaliser reads from the
 * ledger.
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

	// ═══ per-round scoring for the graded rounds 1-4 ═══════════════════════════
	public void scoreRound(UUID runId, int roundNumber, int outcomePct, String confidence,
			int activeSecondsUsed, int roundDurationMinutes, String typedAnswer) {

		boolean full = outcomePct >= 100;

		int rigor = analyticalRigor(roundNumber, typedAnswer);
		repository.upsertConstructScore(runId, roundNumber, ANALYTICAL_RIGOR, rigor, "SCORED",
				"process check + justification + evidence = " + rigor + "/100");

		int judgment = calibration(full, confidence);
		repository.upsertConstructScore(runId, roundNumber, JUDGMENT_CALIBRATION, judgment, "SCORED",
				"Outcome " + outcomePct + "%, confidence=" + confidence);

		int discipline = discipline(activeSecondsUsed, roundDurationMinutes);
		repository.upsertConstructScore(runId, roundNumber, TURNAROUND_DISCIPLINE, discipline, "SCORED",
				"used " + activeSecondsUsed + "s of " + (roundDurationMinutes * 60) + "s active time");

		repository.upsertConstructScore(runId, roundNumber, DATA_TRUST, null, "NOT_YET_SCORED",
				"Cumulative; finalised from Rounds 1 and 3 at engagement end");
		repository.upsertConstructScore(runId, roundNumber, INSIGHT_COMMUNICATION, null, "NOT_YET_SCORED",
				"Board Clarity finalised at engagement end + Final Presentation");
	}

	// ═══ Round 5 — the SCQA synthesis (no numeric Outcome) ═════════════════════
	public void scoreRound5(UUID runId, int activeSecondsUsed, int roundDurationMinutes,
			String typedAnswer, String confidence) {

		String comp = complicationMatch(typedAnswer); // FULL / PARTIAL / NONE
		boolean full = "FULL".equals(comp);

		int rigor = rigorRound5(typedAnswer, comp);
		repository.upsertConstructScore(runId, 5, ANALYTICAL_RIGOR, rigor, "SCORED",
				"SCQA completeness + Complication " + comp + " = " + rigor + "/100");

		int judgment = calibration(full, confidence);
		repository.upsertConstructScore(runId, 5, JUDGMENT_CALIBRATION, judgment, "SCORED",
				"Complication " + comp + " (stands in for Outcome), confidence=" + confidence);

		int discipline = discipline(activeSecondsUsed, roundDurationMinutes);
		repository.upsertConstructScore(runId, 5, TURNAROUND_DISCIPLINE, discipline, "SCORED",
				"used " + activeSecondsUsed + "s of " + (roundDurationMinutes * 60) + "s active time");

		repository.upsertConstructScore(runId, 5, DATA_TRUST, null, "NOT_APPLICABLE",
				"Round 5 draws on earlier Data Trust findings; contributes no new value");
		repository.upsertConstructScore(runId, 5, INSIGHT_COMMUNICATION, null, "NOT_YET_SCORED",
				"Board Clarity finalised at engagement end + Final Presentation");
	}

	/** Fallback for any round with no answer key (kept for safety; not used by v6 rounds 1-5). */
	public void scoreRoundNoAnswer(UUID runId, int roundNumber, int activeSecondsUsed,
			int roundDurationMinutes) {
		int discipline = discipline(activeSecondsUsed, roundDurationMinutes);
		repository.upsertConstructScore(runId, roundNumber, TURNAROUND_DISCIPLINE, discipline, "SCORED",
				"used " + activeSecondsUsed + "s of " + (roundDurationMinutes * 60) + "s active time");
		repository.upsertConstructScore(runId, roundNumber, ANALYTICAL_RIGOR, null, "NOT_APPLICABLE",
				"No answer to check");
		repository.upsertConstructScore(runId, roundNumber, JUDGMENT_CALIBRATION, null, "NOT_APPLICABLE",
				"No correctness to calibrate against");
		repository.upsertConstructScore(runId, roundNumber, DATA_TRUST, null, "NOT_APPLICABLE",
				"Finalised at engagement end");
		repository.upsertConstructScore(runId, roundNumber, INSIGHT_COMMUNICATION, null, "NOT_APPLICABLE",
				"Finalised at engagement end");
	}

	// ═══ engagement finalisation (round 0) ═════════════════════════════════════
	public void finalizeEngagement(UUID runId) {

		finalizeMean(runId, ANALYTICAL_RIGOR);
		finalizeMean(runId, JUDGMENT_CALIBRATION);
		finalizeMean(runId, TURNAROUND_DISCIPLINE);

		// Data Trust Score (cumulative, Rounds 1 & 3 only): 45% R1 Outcome + 15% R1 tag
		// match + 40% R3 Outcome. Spot-Audit -20 is a facilitator override.
		int r1o = outcomeOf(runId, 1);
		int r3o = outcomeOf(runId, 3);
		double tagFrac = round1TagFractionFromDb(runId); // 0 / 0.5 / 1
		int tagPts = (int) Math.round(15 * tagFrac);
		int trust = (int) Math.round(0.45 * r1o + 0.40 * r3o + 15 * tagFrac);
		trust = Math.max(0, Math.min(100, trust));
		repository.upsertConstructScore(runId, 0, DATA_TRUST, trust, "SCORED",
				"R1 Outcome " + r1o + "%×0.45, R1 tags " + tagPts + "/15, R3 Outcome " + r3o + "%×0.40");

		repository.upsertConstructScore(runId, 0, INSIGHT_COMMUNICATION, boardClarity(runId), "SCORED",
				"Provisional Board Clarity from free-text (R1/2/3 + R5); refined live by the Final Board Presentation");
	}

	private void finalizeMean(UUID runId, String construct) {
		Integer mean = repository.findConstructMean(runId, construct);
		if (mean != null) {
			repository.upsertConstructScore(runId, 0, construct, mean, "SCORED", "Mean across played rounds");
		} else {
			repository.upsertConstructScore(runId, 0, construct, null, "NOT_APPLICABLE",
					"No scored rounds to average");
		}
	}

	private int outcomeOf(UUID runId, int round) {
		Integer o = repository.findRoundOutcome(runId, round);
		return o == null ? 0 : o;
	}

	// ═══ Analytical Rigor — v6 3-point model ═══════════════════════════════════
	/** process check (1) + justification non-blank ≥15 chars (1) + justification contains a number (1). */
	private int analyticalRigor(int round, String s) {
		boolean process = processCheck(round, s);
		String just = seg(s, "note:");
		boolean justOk = just.trim().length() >= 15;
		boolean evidence = just.matches(".*\\d.*");
		int pts = (process ? 1 : 0) + (justOk ? 1 : 0) + (evidence ? 1 : 0);
		return Math.round(pts / 3f * 100);
	}

	private boolean processCheck(int round, String s) {
		switch (round) {
			case 1:
				return round1TagFraction(s) >= 1.0; // all three tags, no false positive
			case 2: {
				String n = seg(s, "note:").toLowerCase();
				return (n.contains("training") || n.contains("hours")) && n.matches(".*\\d.*");
			}
			case 3: {
				String macro = seg(s, "macro:").toLowerCase();
				String n = seg(s, "note:").toLowerCase();
				return macro.contains("yes") && (n.contains("macro") || n.contains("record") || n.contains("vba"));
			}
			case 4: {
				String c = seg(s, "chart:").toLowerCase();
				return c.contains("bar chart") || c.contains("line chart");
			}
			default:
				return false;
		}
	}

	/** R5 Rigor: full (100) when every SCQA field ≥15 chars and the Complication fully matches; 50 for a
	 *  full-but-incomplete or partial Complication; 0 otherwise. */
	private int rigorRound5(String s, String comp) {
		boolean allOk = seg(s, "situation:").length() >= 15 && seg(s, "complication:").length() >= 15
				&& seg(s, "question:").length() >= 15 && seg(s, "answer:").length() >= 15;
		if ("FULL".equals(comp)) {
			return allOk ? 100 : 50;
		}
		return "PARTIAL".equals(comp) ? 50 : 0;
	}

	// ═══ Board Clarity ═════════════════════════════════════════════════════════
	private int boardClarity(UUID runId) {
		int[] scores = {
				clarityForRound(runId, 1, "note:", 10),
				clarityForRound(runId, 2, "note:", 10),
				clarityForRound(runId, 3, "note:", 10),
				round5Clarity(runId),
		};
		int sum = 0;
		int n = 0;
		for (int v : scores) {
			if (v >= 0) {
				sum += v;
				n++;
			}
		}
		return n == 0 ? 0 : Math.round((float) sum / n);
	}

	/** 50 pts if the round's one-liner meets its length bar, +50 if it cites a number; -1 if not submitted. */
	private int clarityForRound(UUID runId, int roundNumber, String label, int minLen) {
		if (repository.findSubmission(runId, roundNumber) == null) {
			return -1;
		}
		String text = segmentFromDb(runId, roundNumber, label);
		int pts = 0;
		if (text.length() >= minLen) pts += 50;
		if (text.matches(".*\\d.*")) pts += 50;
		return pts;
	}

	/** R5 Board Clarity (v6): the Complication keyword check (50) plus a non-trivial Answer field (50). */
	private int round5Clarity(UUID runId) {
		Map<String, Object> sub = repository.findSubmission(runId, 5);
		if (sub == null) {
			return -1;
		}
		String typed = String.valueOf(sub.get("typedAnswer"));
		String comp = complicationMatch(typed);
		int compPts = "FULL".equals(comp) ? 50 : "PARTIAL".equals(comp) ? 25 : 0;
		int answerPts = seg(typed, "answer:").length() >= 15 ? 50 : 0;
		return compPts + answerPts;
	}

	// ═══ shared helpers ════════════════════════════════════════════════════════

	/** Complication keyword check: ≥3 of the 4 round fact-sets → FULL, 2 → PARTIAL, else NONE. */
	private String complicationMatch(String typed) {
		String c = seg(typed, "complication:").toLowerCase();
		int matched = 0;
		if (c.contains("62667") || c.contains("62,667") || c.contains("duplicate") || c.contains("trust")) matched++;
		if (c.contains("people") || c.contains("training") || c.contains("25.5")) matched++;
		if (c.contains("270") || c.contains("1381546") || c.contains("1,381,546") || c.contains("macro")) matched++;
		if (c.contains("notebook set") || c.contains("april")) matched++;
		if (matched >= 3) return "FULL";
		if (matched == 2) return "PARTIAL";
		return "NONE";
	}

	/** R1 tag credit from a typed-answer string: 1.0 full, 0.5 for two, else 0. */
	double round1TagFraction(String s) {
		String tags = seg(s, "issues:").toLowerCase();
		if (tags.isBlank()) {
			return 0;
		}
		boolean falsePositive = tags.contains("incorrect");
		int matched = 0;
		if (tags.contains("improper formatting")) matched++;
		if (tags.contains("incomplete")) matched++;
		if (tags.contains("duplicated")) matched++;
		if (matched == 3 && !falsePositive) return 1.0;
		if (matched == 2 && !falsePositive) return 0.5;
		return 0;
	}

	private double round1TagFractionFromDb(UUID runId) {
		Map<String, Object> sub = repository.findSubmission(runId, 1);
		return sub == null ? 0 : round1TagFraction(String.valueOf(sub.get("typedAnswer")));
	}

	/** Labelled segment from a typed-answer string, e.g. seg(s,"note:"). */
	private String seg(String s, String label) {
		if (s == null) {
			return "";
		}
		int i = s.toLowerCase().indexOf(label.toLowerCase());
		if (i < 0) {
			return "";
		}
		String rest = s.substring(i + label.length());
		int bar = rest.indexOf('|');
		return (bar >= 0 ? rest.substring(0, bar) : rest).trim();
	}

	private String segmentFromDb(UUID runId, int roundNumber, String label) {
		Map<String, Object> sub = repository.findSubmission(runId, roundNumber);
		return sub == null || sub.get("typedAnswer") == null ? ""
				: seg(String.valueOf(sub.get("typedAnswer")), label);
	}

	/** v6 confidence × Outcome matrix. Outcome 100%: High 100 / Med 75 / Low 60. Below 100%: Low 40 / Med 25 / High 0. */
	int calibration(boolean outcomeFull, String confidence) {
		String c = confidence == null ? "MEDIUM" : confidence.toUpperCase();
		if (outcomeFull) {
			return switch (c) {
				case "HIGH" -> 100;
				case "MEDIUM" -> 75;
				default -> 60;
			};
		}
		return switch (c) {
			case "HIGH" -> 0;
			case "MEDIUM" -> 25;
			default -> 40;
		};
	}

	/** 100 while inside the round window, tapering to 0 once the window is doubled (percentile is a cohort refinement). */
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
