package com.example.simulator.faculty;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Map;
import java.util.UUID;

import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.http.HttpStatus;

import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * Guards every {@code /api/faculty/**} endpoint and establishes WHO is calling.
 *
 * <p>Two credentials are accepted, deliberately:
 *
 * <ul>
 *   <li><b>A per-faculty access key.</b> Resolved against {@code faculty_user} by SHA-256 hash and
 *       carrying the caller's organisation, so a request can be scoped to the institution that
 *       actually bought the simulation. This is the credential everything should move to.</li>
 *   <li><b>The legacy shared token.</b> Still accepted, mapped to a platform-admin identity. It is
 *       kept because the alternative is breaking every bookmarked console and running session on
 *       the day tenancy ships. Turn it off with {@code faculty.legacy-token-enabled=false} once
 *       every facilitator holds a real key — a config change, not a deploy.</li>
 * </ul>
 *
 * <p>The credential travels in the {@code X-Faculty-Token} header only, never a query parameter:
 * query strings leak into browser history, server access logs and Referer headers.
 *
 * <p>If neither credential matches, the filter refuses rather than failing open.
 */
@Configuration
public class FacultyAuthFilter {

	public static final String HEADER = "X-Faculty-Token";
	/** Where the resolved caller is parked for the rest of the request. */
	public static final String PRINCIPAL_ATTRIBUTE = "caserun.facultyPrincipal";

	private static final String PROTECTED_PREFIX = "/api/faculty";

	@Bean
	public FilterRegistrationBean<Filter> facultyTokenFilter(
			@Value("${faculty.access-token:}") String configuredToken,
			@Value("${faculty.legacy-token-enabled:true}") boolean legacyEnabled,
			// Lazy: this filter is built during context startup, before JPA is ready. Resolving the
			// repository per request rather than at construction keeps the two independent.
			ObjectProvider<FacultyIdentityRepository> identity) {

		Filter filter = new Filter() {
			@Override
			public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
					throws IOException, ServletException {

				HttpServletRequest request = (HttpServletRequest) req;
				HttpServletResponse response = (HttpServletResponse) res;

				// CORS preflight carries no custom headers; let it through.
				if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
					chain.doFilter(req, res);
					return;
				}

				// Trim both sides: pasting a credential into a hosting env-var field (or the login
				// box) very often adds a trailing newline or space, which would otherwise reject a
				// value that is actually correct. Whitespace is never meaningful here.
				String supplied = request.getHeader(HEADER);
				String presented = supplied == null ? "" : supplied.trim();
				if (presented.isBlank()) {
					deny(response, "Invalid or missing facilitator token");
					return;
				}

				// 1. A per-faculty access key — the real identity.
				FacultyPrincipal principal = resolveKey(identity.getIfAvailable(), presented);

				// 2. Otherwise the legacy shared token, while it is still switched on.
				if (principal == null) {
					String configured = configuredToken == null ? "" : configuredToken.trim();
					if (legacyEnabled && !configured.isBlank()
							&& constantTimeEquals(configured, presented)) {
						principal = FacultyPrincipal.legacy();
					}
				}

				if (principal == null) {
					deny(response, "Invalid or missing facilitator token");
					return;
				}

				request.setAttribute(PRINCIPAL_ATTRIBUTE, principal);
				chain.doFilter(req, res);
			}
		};

		FilterRegistrationBean<Filter> registration = new FilterRegistrationBean<>(filter);
		registration.addUrlPatterns(PROTECTED_PREFIX + "/*");
		registration.setName("facultyTokenFilter");
		// Run AFTER the CORS filter, so a 401 from here still carries CORS headers and
		// the browser shows the 401 instead of reporting "failed to fetch".
		registration.setOrder(Ordered.HIGHEST_PRECEDENCE + 10);
		return registration;
	}

	/** Looks the presented key up by hash. Returns {@code null} when it is not a known key. */
	private FacultyPrincipal resolveKey(FacultyIdentityRepository repo, String presented) {
		if (repo == null) {
			return null;
		}
		Map<String, Object> row;
		try {
			row = repo.findByAccessKeyHash(sha256(presented));
		} catch (RuntimeException e) {
			// A failed identity lookup must not fall through to the legacy branch as though the key
			// were merely unknown — that would quietly widen access on a database blip.
			throw new IllegalStateException("Could not verify that facilitator key");
		}
		if (row == null || row.isEmpty()) {
			return null;
		}
		UUID facultyUserId = (UUID) row.get("facultyUserId");
		FacultyPrincipal principal = new FacultyPrincipal(
				facultyUserId,
				(UUID) row.get("organizationId"),
				String.valueOf(row.get("name")),
				Boolean.TRUE.equals(row.get("platformAdmin")),
				false);
		try {
			repo.touchLastSeen(facultyUserId);
		} catch (RuntimeException ignored) {
			// Last-seen is telemetry. It must never be why a facilitator cannot sign in.
		}
		return principal;
	}

	/** The stored form of an access key. Keys are high-entropy random, so a plain digest is right. */
	public static String sha256(String value) {
		try {
			MessageDigest digest = MessageDigest.getInstance("SHA-256");
			return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
		} catch (NoSuchAlgorithmException e) {
			throw new IllegalStateException("SHA-256 unavailable", e);
		}
	}

	private void deny(HttpServletResponse response, String message) throws IOException {
		response.setStatus(HttpStatus.UNAUTHORIZED.value());
		response.setContentType("application/json");
		response.getWriter().write("{\"error\":\"" + message + "\"}");
	}

	/** Avoids leaking credential contents through response timing. */
	private boolean constantTimeEquals(String a, String b) {
		byte[] x = a.getBytes(StandardCharsets.UTF_8);
		byte[] y = b.getBytes(StandardCharsets.UTF_8);
		int diff = x.length ^ y.length;
		for (int i = 0; i < x.length && i < y.length; i++) {
			diff |= x[i] ^ y[i];
		}
		return diff == 0;
	}
}
