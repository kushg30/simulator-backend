package com.example.simulator.sim2;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Grades a typed answer against the faculty-only answer key.
 *
 * <p>Per the simulation spec, Analytical Rigor is verified "via each round's answer-check, not
 * formula inspection" — so the uploaded workbook is stored for faculty review but never parsed.
 */
@Service
@Transactional(readOnly = true)
public class Sim2GradingService {

	private final Sim2Repository repository;

	public Sim2GradingService(Sim2Repository repository) {
		this.repository = repository;
	}

	/**
	 * Outcome of an answer check. v6: no round is all-or-nothing — {@code outcomePct} is the 0-100
	 * per-field weighted Outcome; {@code correct} is a convenience for {@code outcomePct == 100}.
	 */
	public record GradeResult(boolean correct, int outcomePct, String answerType, String normalizedAnswer,
			String reason) {
	}

	/** True when the round has a canonical answer to check against (i.e. not a free-text round). */
	public boolean isGradable(UUID runId, int roundNumber) {
		Map<String, Object> key = repository.findAnswerKey(runId, roundNumber);
		return key != null && key.get("answerType") != null
				&& !"FREE_TEXT".equals(String.valueOf(key.get("answerType")));
	}

	public GradeResult grade(UUID runId, int roundNumber, String typedAnswer) {

		Map<String, Object> key = repository.findAnswerKey(runId, roundNumber);
		if (key == null || key.get("canonicalAnswer") == null) {
			throw new IllegalStateException("No answer key configured for round " + roundNumber);
		}

		String answerType = String.valueOf(key.get("answerType"));
		String submitted = typedAnswer == null ? "" : typedAnswer.trim();
		if (submitted.isEmpty()) {
			return new GradeResult(false, 0, answerType, submitted, "empty answer");
		}

		// v6 per-field partial-credit Outcome (0-100%). Each field contributes its own share.
		int outcome = switch (roundNumber) {
			case 1 -> outcomeRound1(submitted);
			case 2 -> outcomeRound2(submitted);
			case 3 -> outcomeRound3(submitted);
			case 4 -> outcomeRound4(submitted);
			default -> gradeMulti(submitted, String.valueOf(key.get("canonicalAnswer"))).correct() ? 100 : 0;
		};
		return new GradeResult(outcome >= 100, outcome, answerType, submitted, "Outcome " + outcome + "%");
	}

	// ── v6 per-round Outcome (0-100%) ─────────────────────────────────────────
	// The typed answer arrives as "gradedFields | label: ... | label: ...". The
	// graded numeric/text fields are the part before the first "|"; the tags and
	// tool/chart selects are labelled segments after it.

	/** Text before the first "|", split into the round's graded fields. */
	private String[] fields(String submitted) {
		int bar = submitted.indexOf('|');
		String head = bar >= 0 ? submitted.substring(0, bar) : submitted;
		return head.split(";");
	}

	private String field(String submitted, int i) {
		String[] f = fields(submitted);
		return i < f.length ? f[i].trim() : "";
	}

	/** Labelled segment, e.g. seg(s,"issues:") from "... | issues: A, B | note: ...". */
	private String seg(String s, String label) {
		int i = s.toLowerCase().indexOf(label.toLowerCase());
		if (i < 0) {
			return "";
		}
		String rest = s.substring(i + label.length());
		int bar = rest.indexOf('|');
		return (bar >= 0 ? rest.substring(0, bar) : rest).trim();
	}

	private boolean within(String value, double target, double absTol, boolean pct) {
		BigDecimal n = firstNumber(value);
		if (n == null) {
			return false;
		}
		double allowed = pct ? Math.abs(target) * absTol : absTol;
		return Math.abs(n.doubleValue() - target) <= allowed + 1e-9;
	}

	private BigDecimal firstNumber(String s) {
		try {
			return new BigDecimal(stripNumericNoise(s));
		} catch (NumberFormatException e) {
			List<BigDecimal> n = extractNumbers(s);
			return n.isEmpty() ? null : n.get(0);
		}
	}

	/** R1 data-issue tag credit: 1.0 full (all three, no false positive), 0.5 for exactly two, else 0. */
	double round1TagFraction(String submitted) {
		String tags = seg(submitted, "issues:").toLowerCase();
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

	/** R1: 70% Bluetooth revenue within 1% (full or zero) + 30% the data-issue tag match. */
	private int outcomeRound1(String s) {
		int rev = within(field(s, 0), 62667, 0.01, true) ? 70 : 0;
		int tags = (int) Math.round(round1TagFraction(s) * 30);
		return rev + tags;
	}

	/** R2: 50% root cause = People + 50% attainment gap within ±1 of 25.5. */
	private int outcomeRound2(String s) {
		int cause = normalizeText(field(s, 0)).contains("people") ? 50 : 0;
		int gap = within(field(s, 1), 25.5, 1.0, false) ? 50 : 0;
		return cause + gap;
	}

	/** R3: 50% combined row count exactly 270 + 50% combined revenue within 1% of 1,381,546. */
	private int outcomeRound3(String s) {
		BigDecimal rows = firstNumber(field(s, 0));
		int rowPts = rows != null && rows.compareTo(new BigDecimal(270)) == 0 ? 50 : 0;
		int revPts = within(field(s, 1), 1381546, 0.01, true) ? 50 : 0;
		return rowPts + revPts;
	}

	/** R4: 25% each — most-ordered product, its count, peak month, its count. */
	private int outcomeRound4(String s) {
		int p = normalizeText(field(s, 0)).contains("notebook set") ? 25 : 0;
		BigDecimal pc = firstNumber(field(s, 1));
		int pcp = pc != null && pc.compareTo(new BigDecimal(35)) == 0 ? 25 : 0;
		int m = normalizeText(field(s, 2)).contains("april") ? 25 : 0;
		BigDecimal mc = firstNumber(field(s, 3));
		int mcp = mc != null && mc.compareTo(new BigDecimal(90)) == 0 ? 25 : 0;
		return p + pcp + m + mcp;
	}

	// ── Per-field feedback ("what you missed") ────────────────────────────────
	// Mirrors the Outcome formulas above, but returns a per-field verdict + the
	// correct value for the ones missed. Faculty-facing (it names the expected
	// answer), so it powers the debrief and the team report — never a student's
	// live screen. Round 5 is free text, so it returns an empty list.

	/** Per-graded-field feedback for a round's submission: [{label, ok, detail}]. */
	public List<Map<String, Object>> fieldBreakdown(int round, String typedAnswer) {
		String s = typedAnswer == null ? "" : typedAnswer.trim();
		List<Map<String, Object>> out = new ArrayList<>();
		switch (round) {
			case 1 -> {
				out.add(fb("Bluetooth revenue", within(field(s, 0), 62667, 0.01, true), "expected 62,667"));
				out.add(round1TagFeedback(s));
			}
			case 2 -> {
				out.add(fb("Root cause", normalizeText(field(s, 0)).contains("people"),
						"expected People (Training & Skill Gap)"));
				out.add(fb("Attainment gap", within(field(s, 1), 25.5, 1.0, false), "expected ≈ 25.5"));
			}
			case 3 -> {
				BigDecimal rows = firstNumber(field(s, 0));
				out.add(fb("Combined row count", rows != null && rows.compareTo(new BigDecimal(270)) == 0,
						"expected 270"));
				out.add(fb("Combined revenue", within(field(s, 1), 1381546, 0.01, true),
						"expected 1,381,546"));
			}
			case 4 -> {
				out.add(fb("Most-ordered product", normalizeText(field(s, 0)).contains("notebook set"),
						"expected Notebook Set"));
				BigDecimal pc = firstNumber(field(s, 1));
				out.add(fb("Product order count", pc != null && pc.compareTo(new BigDecimal(35)) == 0,
						"expected 35"));
				out.add(fb("Peak month", normalizeText(field(s, 2)).contains("april"), "expected April"));
				BigDecimal mc = firstNumber(field(s, 3));
				out.add(fb("Peak-month order count", mc != null && mc.compareTo(new BigDecimal(90)) == 0,
						"expected 90"));
			}
			default -> { /* Round 5 is a free-text reflection — not field-graded. */ }
		}
		return out;
	}

	private Map<String, Object> fb(String label, boolean ok, String expected) {
		Map<String, Object> m = new LinkedHashMap<>();
		m.put("label", label);
		m.put("ok", ok);
		m.put("detail", ok ? "correct" : expected);
		return m;
	}

	/** R1 data-issue tags, as one feedback line naming which of the three were matched or missed. */
	private Map<String, Object> round1TagFeedback(String s) {
		String tags = seg(s, "issues:").toLowerCase();
		String[] all = { "improper formatting", "incomplete", "duplicated" };
		String[] nice = { "Improper Formatting", "Incomplete", "Duplicated" };
		List<String> missed = new ArrayList<>();
		int matched = 0;
		for (int i = 0; i < all.length; i++) {
			if (tags.contains(all[i])) {
				matched++;
			} else {
				missed.add(nice[i]);
			}
		}
		boolean falsePositive = tags.contains("incorrect");
		boolean ok = matched == 3 && !falsePositive;
		String detail;
		if (ok) {
			detail = "all 3 flagged";
		} else if (matched == 0) {
			detail = "no valid issues flagged";
		} else {
			detail = "flagged " + matched + " of 3 — missed " + String.join(", ", missed);
			if (falsePositive) {
				detail += " (and a false positive)";
			}
		}
		Map<String, Object> m = new LinkedHashMap<>();
		m.put("label", "Data-issue tags");
		m.put("ok", ok);
		m.put("detail", detail);
		return m;
	}

	/**
	 * Every expected figure in a semicolon-separated canonical (e.g. "62667;59") must appear among the
	 * numbers found in the submitted answer, so "Bluetooth 62,667 / Refunds 59" grades correct.
	 */
	private GradeResult gradeNumericMulti(String submitted, String canonical) {
		List<BigDecimal> found = new ArrayList<>();
		try {
			found.add(new BigDecimal(stripNumericNoise(submitted)));
		} catch (NumberFormatException ignored) {
			// fall through to extraction
		}
		found.addAll(extractNumbers(submitted));

		List<String> missing = new ArrayList<>();
		for (String part : canonical.split(";")) {
			BigDecimal expected;
			try {
				expected = new BigDecimal(stripNumericNoise(part));
			} catch (NumberFormatException e) {
				continue;
			}
			boolean hit = found.stream().anyMatch(n -> n.compareTo(expected) == 0);
			if (!hit) {
				missing.add(expected.toPlainString());
			}
		}
		boolean ok = missing.isEmpty();
		return new GradeResult(ok, ok ? 100 : 0, "NUMERIC_MULTI", submitted,
				ok ? "all figures matched" : "missing figure(s): " + String.join(", ", missing));
	}

	/**
	 * A mix of required parts, semicolon-separated. Each part is graded as an exact number if it looks
	 * numeric, otherwise as a contained text phrase. Every part must be present. Used for the v3
	 * two-part answers, e.g. "training;25.5" (a word + a figure) or "Notebook Set;April" (two words).
	 */
	private GradeResult gradeMulti(String submitted, String canonical) {
		List<BigDecimal> nums = new ArrayList<>();
		try {
			nums.add(new BigDecimal(stripNumericNoise(submitted)));
		} catch (NumberFormatException ignored) {
			// fall through to extraction
		}
		nums.addAll(extractNumbers(submitted));
		String norm = normalizeText(submitted);

		List<String> missing = new ArrayList<>();
		for (String raw : canonical.split(";")) {
			String part = raw.trim();
			if (part.isEmpty()) {
				continue;
			}
			BigDecimal exp = tryDecimal(part);
			if (exp != null) {
				if (nums.stream().noneMatch(n -> n.compareTo(exp) == 0)) {
					missing.add(part);
				}
			} else if (!norm.contains(normalizeText(part))) {
				missing.add(part);
			}
		}
		boolean ok = missing.isEmpty();
		return new GradeResult(ok, ok ? 100 : 0, "MULTI", submitted,
				ok ? "all parts matched" : "missing: " + String.join(", ", missing));
	}

	private BigDecimal tryDecimal(String s) {
		try {
			return new BigDecimal(stripNumericNoise(s));
		} catch (NumberFormatException e) {
			return null;
		}
	}

	/**
	 * Lenient text check: the canonical phrase must appear in the submission after normalising, so a
	 * category name grades correct even when the student adds the supporting figure ("Beauty & Personal
	 * Care, 56.99%"). Handles the "&" vs "and" and punctuation variations.
	 */
	private GradeResult gradeText(String submitted, String canonical) {
		String s = normalizeText(submitted);
		String c = normalizeText(canonical);
		boolean ok = !c.isEmpty() && (s.equals(c) || s.contains(c));
		return new GradeResult(ok, ok ? 100 : 0, "TEXT", submitted, ok ? "text match" : "no match");
	}

	private GradeResult gradeNumeric(String submitted, String canonical, BigDecimal tolAbs, BigDecimal tolPct) {

		BigDecimal expected;
		try {
			expected = new BigDecimal(stripNumericNoise(canonical));
		} catch (NumberFormatException e) {
			return new GradeResult(false, 0, "NUMERIC", canonical, "answer key value is not numeric");
		}

		// Some rounds ask for a sentence containing the figure, e.g. Round 5 wants
		// "Yes/No, with the figure". Try the whole string first, then fall back to any
		// number found inside it, so a correct figure is not marked wrong for the prose
		// wrapped around it.
		List<BigDecimal> candidates = new ArrayList<>();
		try {
			candidates.add(new BigDecimal(stripNumericNoise(submitted)));
		} catch (NumberFormatException ignored) {
			candidates.addAll(extractNumbers(submitted));
		}
		if (candidates.isEmpty()) {
			return new GradeResult(false, 0, "NUMERIC", submitted, "no number found in the answer");
		}

		BigDecimal actual = candidates.get(0);
		BigDecimal diff = actual.subtract(expected).abs();
		for (BigDecimal c : candidates) {
			BigDecimal d = c.subtract(expected).abs();
			if (d.compareTo(diff) < 0) {
				diff = d;
				actual = c;
			}
		}

		// No tolerance configured => exact match (Round 1 reconciliation total).
		if (tolAbs == null && tolPct == null) {
			boolean ok = diff.compareTo(BigDecimal.ZERO) == 0;
			return new GradeResult(ok, ok ? 100 : 0, "NUMERIC", actual.toPlainString(),
					ok ? "exact match" : "expected exact match, off by " + diff.toPlainString());
		}

		BigDecimal allowed = BigDecimal.ZERO;
		if (tolAbs != null) {
			allowed = allowed.max(tolAbs);
		}
		if (tolPct != null) {
			allowed = allowed.max(expected.abs().multiply(tolPct).movePointLeft(2));
		}

		boolean ok = diff.compareTo(allowed) <= 0;
		return new GradeResult(ok, ok ? 100 : 0, "NUMERIC", actual.toPlainString(),
				"off by " + diff.toPlainString() + ", allowed " + allowed.toPlainString());
	}

	/** Accepts "1,302,602", "1302602.00", "₹1302602" and "53.4%". */
	private String stripNumericNoise(String s) {
		return s.replaceAll("[,\\s₹$%]", "").replaceAll("(?i)^inr", "").replaceAll("(?i)inr$", "").trim();
	}

	/** Pulls every number out of a sentence, e.g. "Yes - India Stores: 230,739 INR" -> [230739]. */
	private List<BigDecimal> extractNumbers(String s) {
		List<BigDecimal> out = new ArrayList<>();
		Matcher m = Pattern.compile("-?\\d[\\d,]*(?:\\.\\d+)?").matcher(s);
		while (m.find()) {
			try {
				out.add(new BigDecimal(m.group().replace(",", "")));
			} catch (NumberFormatException ignored) {
				// not a usable number, skip
			}
		}
		return out;
	}

	private String normalizeText(String s) {
		return s.toLowerCase()
				.replace("&", " and ")
				.replaceAll("[^a-z0-9 ]", " ")
				.replaceAll("\\s+", " ")
				.trim();
	}

	private BigDecimal toDecimal(Object o) {
		if (o == null) {
			return null;
		}
		return (o instanceof BigDecimal bd) ? bd : new BigDecimal(String.valueOf(o));
	}
}
