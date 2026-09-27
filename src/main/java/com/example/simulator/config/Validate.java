package com.example.simulator.config;

import java.util.Set;
import java.util.UUID;

/**
 * Strict input validation for values that arrive from a browser.
 *
 * <p>The rule here is <em>reject</em>, not repair. Sanitising silently accepts a request the caller
 * did not make — a 300 KB team name quietly truncated to 80 is data nobody typed — and every
 * escaping scheme eventually meets a context it was not written for. A value that does not match its
 * declared shape is refused with a message the student can act on, and nothing is stored.
 *
 * <p>Every failure is an {@link IllegalArgumentException}, which the global handler already maps to
 * a 400 carrying the message. The messages are written for students, so they are safe to show.
 *
 * <p>Note on escaping: rejecting bad input is the first layer, not the only one. SQL is parameterised
 * throughout (no concatenation anywhere in the repositories) and React escapes text nodes on render,
 * so a value that does get through is still inert in both places.
 */
public final class Validate {

	private Validate() {
	}

	/**
	 * Control characters other than tab/newline/carriage-return. These have no meaning in any field
	 * a student types and are a standard way to smuggle terminal escapes or line breaks into logs.
	 */
	private static final String CONTROL_CHARS = ".*[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F].*";

	/**
	 * A required single-line value: present, non-blank once trimmed, within {@code maxLength}, and
	 * free of control characters. Returns the trimmed value.
	 */
	public static String requiredText(String value, String field, int maxLength) {
		String trimmed = value == null ? "" : value.trim();
		if (trimmed.isEmpty()) {
			throw new IllegalArgumentException(field + " is required");
		}
		return checkedText(trimmed, field, maxLength);
	}

	/**
	 * An optional single-line value. {@code null}/blank stays {@code null}; anything present is held
	 * to the same standard as a required value.
	 */
	public static String optionalText(String value, String field, int maxLength) {
		String trimmed = value == null ? "" : value.trim();
		if (trimmed.isEmpty()) {
			return null;
		}
		return checkedText(trimmed, field, maxLength);
	}

	/** A required multi-line value (free-text answers) — newlines allowed, length still capped. */
	public static String requiredProse(String value, String field, int maxLength) {
		String trimmed = value == null ? "" : value.trim();
		if (trimmed.isEmpty()) {
			throw new IllegalArgumentException(field + " is required");
		}
		return checkedProse(trimmed, field, maxLength);
	}

	/** An optional multi-line value. */
	public static String optionalProse(String value, String field, int maxLength) {
		String trimmed = value == null ? "" : value.trim();
		if (trimmed.isEmpty()) {
			return null;
		}
		return checkedProse(trimmed, field, maxLength);
	}

	/** A value that must be one of a fixed set, compared case-insensitively. Returns it upper-cased. */
	public static String oneOf(String value, String field, Set<String> allowed) {
		String trimmed = value == null ? "" : value.trim().toUpperCase();
		if (!allowed.contains(trimmed)) {
			throw new IllegalArgumentException(field + " is not one of the allowed values");
		}
		return trimmed;
	}

	/** A value matching an exact format, e.g. a join code or a role code. Returns it trimmed. */
	public static String matching(String value, String field, String regex, int maxLength,
			String requirement) {
		String trimmed = value == null ? "" : value.trim();
		if (trimmed.isEmpty()) {
			throw new IllegalArgumentException(field + " is required");
		}
		if (trimmed.length() > maxLength || !trimmed.matches(regex)) {
			throw new IllegalArgumentException(field + " " + requirement);
		}
		return trimmed;
	}

	/**
	 * A required UUID.
	 *
	 * <p>Parsed here rather than with a bare {@code UUID.fromString}, whose own exception message
	 * ("Invalid UUID string: &lt;whatever was sent&gt;") echoes the caller's input straight back into
	 * the response body.
	 */
	public static UUID uuid(String value, String field) {
		String trimmed = value == null ? "" : value.trim();
		if (trimmed.isEmpty()) {
			throw new IllegalArgumentException(field + " is required");
		}
		try {
			return UUID.fromString(trimmed);
		} catch (IllegalArgumentException e) {
			throw new IllegalArgumentException(field + " is not a valid id");
		}
	}

	/** An optional UUID: {@code null}/blank returns {@code null}. */
	public static UUID optionalUuid(String value, String field) {
		String trimmed = value == null ? "" : value.trim();
		return trimmed.isEmpty() ? null : uuid(trimmed, field);
	}

	/** An integer that must sit inside an inclusive range. */
	public static int inRange(int value, String field, int min, int max) {
		if (value < min || value > max) {
			throw new IllegalArgumentException(field + " must be between " + min + " and " + max);
		}
		return value;
	}

	private static String checkedText(String trimmed, String field, int maxLength) {
		if (trimmed.length() > maxLength) {
			throw new IllegalArgumentException(field + " must be " + maxLength + " characters or fewer");
		}
		if (trimmed.matches(CONTROL_CHARS) || trimmed.indexOf('\n') >= 0 || trimmed.indexOf('\r') >= 0) {
			throw new IllegalArgumentException(field + " contains characters that are not allowed");
		}
		return trimmed;
	}

	private static String checkedProse(String trimmed, String field, int maxLength) {
		if (trimmed.length() > maxLength) {
			throw new IllegalArgumentException(field + " must be " + maxLength + " characters or fewer");
		}
		if (trimmed.matches(CONTROL_CHARS)) {
			throw new IllegalArgumentException(field + " contains characters that are not allowed");
		}
		return trimmed;
	}
}
