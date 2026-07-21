package com.example.simulator.sim2;

import java.math.BigDecimal;
import java.util.Map;
import java.util.UUID;

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
		BigDecimal actual;
		try {
			expected = new BigDecimal(stripNumericNoise(canonical));
			actual = new BigDecimal(stripNumericNoise(submitted));
		} catch (NumberFormatException e) {
			return new GradeResult(false, "NUMERIC", submitted, "not a number");
		}

		BigDecimal diff = actual.subtract(expected).abs();

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
		return s.replaceAll("[,\\s₹$%]", "").replaceAll("(?i)^inr", "").trim();
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
