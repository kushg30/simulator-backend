package com.example.simulator.faculty;

/**
 * The caller authenticated fine but is not allowed to do this.
 *
 * <p>Distinct from the validation exceptions on purpose: those mean "your request was malformed"
 * and map to 400. This means "you are who you say you are, and the answer is still no", which is a
 * 403 — a difference the console needs, because one warrants an error message next to a field and
 * the other warrants hiding the control entirely.
 */
public class FacultyForbiddenException extends RuntimeException {

    public FacultyForbiddenException(String message) {
        super(message);
    }
}
