package com.example.simulator.config;

import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

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

    /** Business-rule / validation violations: the message is intentionally user-facing. */
    @ExceptionHandler({IllegalStateException.class, IllegalArgumentException.class})
    public ResponseEntity<Map<String, Object>> handleBadRequest(RuntimeException ex) {
        String message = ex.getMessage() == null ? "Invalid request" : ex.getMessage();
        return ResponseEntity.badRequest().body(Map.of("error", message));
    }

    /** Malformed path/query parameter (e.g. a value that is not a valid UUID). */
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<Map<String, Object>> handleTypeMismatch(MethodArgumentTypeMismatchException ex) {
        return ResponseEntity.badRequest().body(Map.of("error", "Invalid request parameter"));
    }

    /** Anything unexpected: log the detail, return a generic message + a reference id. */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleUnexpected(Exception ex) {
        String ref = Long.toHexString(System.nanoTime());
        log.error("Unhandled error [ref={}]", ref, ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(Map.of("error", "Something went wrong. Please try again.", "ref", ref));
    }
}
