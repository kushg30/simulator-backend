package com.example.simulator.sim2;

import java.math.BigDecimal;
import java.util.ArrayList;
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

	/** Outcome of an answer check. {@code correct} is the only thing scoring depends on. */
	public record GradeResult(boolean correct, String answerType, String normalizedAnswer, String reason) {
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

		String canonical = String.valueOf(key.get("canonicalAnswer"));
		String answerType = String.valueOf(key.get("answerType"));
		BigDecimal tolAbs = toDecimal(key.get("toleranceAbs"));
		BigDecimal tolPct = toDecimal(key.get("tolerancePct"));

		String submitted = typedAnswer == null ? "" : typedAnswer.trim();
		if (submitted.isEmpty()) {
			return new GradeResult(false, answerType, submitted, "empty answer");
		}

		return switch (answerType) {
			case "NUMERIC" -> gradeNumeric(submitted, canonical, tolAbs, tolPct);
			// v2 Round 1 asks for two figures in one answer (revenue AND count); both must match.
			case "NUMERIC_MULTI" -> gradeNumericMulti(submitted, canonical);
			// v3: a semicolon-separated mix of text and numeric parts, all required
			// (e.g. "training;25.5", "Notebook Set;April").
			case "MULTI" -> gradeMulti(submitted, canonical);
			case "CHOICE" -> new GradeResult(submitted.equalsIgnoreCase(canonical), answerType, submitted,
					"exact choice match");
			default -> gradeText(submitted, canonical);
		};
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
		return new GradeResult(ok, "NUMERIC_MULTI", submitted,
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
		return new GradeResult(ok, "MULTI", submitted,
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
		return new GradeResult(ok, "TEXT", submitted, ok ? "text match" : "no match");
	}

	private GradeResult gradeNumeric(String submitted, String canonical, BigDecimal tolAbs, BigDecimal tolPct) {

		BigDecimal expected;
		try {
			expected = new BigDecimal(stripNumericNoise(canonical));
		} catch (NumberFormatException e) {
			return new GradeResult(false, "NUMERIC", canonical, "answer key value is not numeric");
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
			return new GradeResult(false, "NUMERIC", submitted, "no number found in the answer");
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
			return new GradeResult(ok, "NUMERIC", actual.toPlainString(),
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
		return new GradeResult(ok, "NUMERIC", actual.toPlainString(),
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
