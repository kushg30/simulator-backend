package com.example.simulator.config;

import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.servlet.NoHandlerFoundException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

/**
 * Central error handling for the API.
 *
 * <p>Controllers already catch their own {@link IllegalStateException}/{@link IllegalArgumentException}
 * and return a clean {@code {"error": ...}} body — those messages are written to be safe for users
 * (e.g. "Round 2 has already been submitted"). This advice is the safety net for everything that
 * slips past: it maps validation-style exceptions to a 4xx with their (safe) message, and maps any
 * <em>unexpected</em> exception to a generic 500 while logging the full detail server-side with a
 * reference id. That way a stack trace, SQL fragment or file path never reaches the client.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    private static final String GENERIC_BAD_REQUEST = "That request could not be processed.";
    private static final String GENERIC_ERROR = "Something went wrong. Please try again.";

    /** Longest message that will be passed through; anything longer is a dump, not a sentence. */
    private static final int MAX_MESSAGE_LENGTH = 300;

    /**
     * Fingerprints of a message describing the <em>implementation</em> rather than the caller's
     * mistake: JDBC/Hibernate chatter, class and package names, file paths, SQL.
     *
     * <p>A denylist rather than an allowlist on purpose. The user-facing messages this API returns
     * are hand-written across dozens of services; an allowlist would silently swallow the useful
     * ones ("Round 2 has already been submitted") the first time somebody added a new check, and a
     * student would be told "that request could not be processed" for a rule they could have fixed.
     */
    private static final String[] LEAKY_FRAGMENTS = {
        "sql", "jdbc", "hibernate", "constraint", "could not execute", "batch update",
        "org.", "com.example", "java.", "jakarta.", "javax.", "sun.",
        "exception", "stacktrace", "nested", "relation \"", "column \"",
        "c:\\", "/home/", "/usr/", "/opt/", "/var/", ".java", "invalid uuid string"
    };

    /** Business-rule / validation violations: the message is intentionally user-facing. */
    @ExceptionHandler({IllegalStateException.class, IllegalArgumentException.class})
    public ResponseEntity<Map<String, Object>> handleBadRequest(RuntimeException ex) {
        return ResponseEntity.badRequest().body(Map.of("error", safeMessage(ex)));
    }

    /** Malformed path/query parameter (e.g. a value that is not a valid UUID). */
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<Map<String, Object>> handleTypeMismatch(MethodArgumentTypeMismatchException ex) {
        return ResponseEntity.badRequest().body(Map.of("error", "Invalid request parameter"));
    }

    /** Body that is not valid JSON, or a missing required form field. */
    @ExceptionHandler({HttpMessageNotReadableException.class,
            MissingServletRequestParameterException.class})
    public ResponseEntity<Map<String, Object>> handleMalformedRequest(Exception ex) {
        // Deliberately does not echo the parser's own message: it quotes the offending payload back.
        return ResponseEntity.badRequest().body(Map.of("error", GENERIC_BAD_REQUEST));
    }

    /**
     * No route matches the URL. Without this the catch-all below turns every mistyped or probed URL
     * into a 500 — the wrong status, and an ERROR-level stack trace in the logs for each one, which
     * buries real failures under scanner noise.
     */
    @ExceptionHandler({NoResourceFoundException.class, NoHandlerFoundException.class})
    public ResponseEntity<Map<String, Object>> handleNotFound(Exception ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "Not found"));
    }

    /** Upload larger than the configured multipart ceiling. */
    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<Map<String, Object>> handleTooLarge(MaxUploadSizeExceededException ex) {
        return ResponseEntity.status(HttpStatus.PAYLOAD_TOO_LARGE)
                .body(Map.of("error", "That file is too large to upload."));
    }

    /**
     * Anything the database raised. Always generic to the caller: these messages carry table names,
     * column names, constraint names and fragments of the statement itself.
     */
    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, Object>> handleDataAccess(DataAccessException ex) {
        String ref = reference();
        log.error("Database error [ref={}]", ref, ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", GENERIC_ERROR, "ref", ref));
    }

    /** Anything unexpected: log the detail, return a generic message + a reference id. */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleUnexpected(Exception ex) {
        String ref = reference();
        log.error("Unhandled error [ref={}]", ref, ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", GENERIC_ERROR, "ref", ref));
    }

    /**
     * The exception's own message when it reads as something written for a person; the generic
     * fallback when it reads as internals. Full detail is logged either way with a reference id, so
     * nothing is lost for debugging — it just stops at the server instead of reaching the browser.
     */
    private String safeMessage(RuntimeException ex) {
        String message = ex.getMessage();
        if (message == null || message.isBlank() || message.length() > MAX_MESSAGE_LENGTH) {
            String ref = reference();
            log.warn("Suppressed unusable error message [ref={}]", ref, ex);
            return GENERIC_BAD_REQUEST;
        }
        String lower = message.toLowerCase();
        for (String fragment : LEAKY_FRAGMENTS) {
            if (lower.contains(fragment)) {
                String ref = reference();
                log.warn("Suppressed leaky error message [ref={}]", ref, ex);
                return GENERIC_BAD_REQUEST;
            }
        }
        return message;
    }

    private String reference() {
        return Long.toHexString(System.nanoTime());
    }
}
