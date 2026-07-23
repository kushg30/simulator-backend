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
			case "CHOICE" -> new GradeResult(submitted.equalsIgnoreCase(canonical), answerType, submitted,
					"exact choice match");
			default -> new GradeResult(normalizeText(submitted).equals(normalizeText(canonical)), answerType,
					submitted, "normalized text match");
		};
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
		return s.trim().toLowerCase().replaceAll("\\s+", " ");
	}

	private BigDecimal toDecimal(Object o) {
		if (o == null) {
			return null;
		}
		return (o instanceof BigDecimal bd) ? bd : new BigDecimal(String.valueOf(o));
	}
}
