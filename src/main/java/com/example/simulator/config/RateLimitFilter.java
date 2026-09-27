package com.example.simulator.config;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;

import com.example.simulator.faculty.FacultyAuthFilter;

import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * Per-IP rate limiting for the endpoints that actually warrant it.
 *
 * <p><b>What is deliberately NOT limited.</b> A whole cohort sits behind one campus NAT, so every
 * student in the room shares a single source IP. The high-volume traffic is the 2-3s polling of
 * {@code round-state} and {@code artifacts} by six participants per team across a dozen teams —
 * throttling that would take down a live session, not protect it. Read traffic is therefore exempt
 * entirely, and the limits below are set well above what a full classroom generates.
 *
 * <p><b>What is limited</b>, because each has a real abuse case:
 * <ul>
 *   <li><b>Writes</b> ({@code POST}/{@code PUT}/{@code DELETE}) — unauthenticated endpoints create
 *       teams, participants and 50 MB file uploads. Without a ceiling one script can fill the
 *       database and the upload disk.</li>
 *   <li><b>Join-code resolution</b> — the join code is 4 digits, so the whole space is 9000 guesses.
 *       This does not make guessing impossible (a classroom shares an IP, so the limit has to stay
 *       generous), it makes it slow and noisy rather than instant.</li>
 *   <li><b>Failed facilitator logins</b> — counted only on a 401 from {@code /api/faculty/**}, never
 *       on success. That is what makes brute-forcing the shared token impractical while leaving a
 *       working facilitator — whose console polls every 8s — completely untouched.</li>
 * </ul>
 *
 * <p>Fixed-window counters in memory. This is a single-instance deployment, so there is no shared
 * store to coordinate; if the app is ever scaled horizontally each instance would hold its own
 * counters and the effective limit becomes (limit x instances), which fails open rather than shut.
 *
 * <p>Every limit is env-configurable and the whole filter can be switched off with
 * {@code RATE_LIMIT_ENABLED=false} — an escape hatch for a live session, so a misjudged limit can
 * never be the thing that stops a class.
 */
@Configuration
public class RateLimitFilter {

	private static final Logger log = LoggerFactory.getLogger(RateLimitFilter.class);

	/** One fixed window of request counts, replaced wholesale when the window rolls over. */
	private static final class Window {
		private final AtomicInteger count = new AtomicInteger();
		private volatile long startedAtMs = System.currentTimeMillis();

		/** Increments within the current window, rolling it over first if it has expired. */
		int hit(long windowMs) {
			long now = System.currentTimeMillis();
			if (now - startedAtMs >= windowMs) {
				synchronized (this) {
					if (now - startedAtMs >= windowMs) {
						startedAtMs = now;
						count.set(0);
					}
				}
			}
			return count.incrementAndGet();
		}

		boolean isIdle(long windowMs) {
			return System.currentTimeMillis() - startedAtMs > windowMs * 4;
		}
	}

	private final Map<String, Window> writes = new ConcurrentHashMap<>();
	private final Map<String, Window> joinCodes = new ConcurrentHashMap<>();
	private final Map<String, Window> authFailures = new ConcurrentHashMap<>();

	// Named ...Registration, not rateLimitFilter: the @Configuration class is itself registered as a
	// bean called "rateLimitFilter", and a @Bean method of the same name collides with it and stops
	// the context from starting. The other filter configs in this package avoid it the same way.
	@Bean
	public FilterRegistrationBean<Filter> rateLimitFilterRegistration(
			@Value("${rate-limit.enabled:true}") boolean enabled,
			@Value("${rate-limit.window-seconds:60}") int windowSeconds,
			@Value("${rate-limit.writes-per-window:300}") int writeLimit,
			@Value("${rate-limit.join-codes-per-window:120}") int joinCodeLimit,
			@Value("${rate-limit.auth-failures-per-window:10}") int authFailureLimit,
			// The same token the auth filter checks. Read here only to decide whether an IP that has
			// burned its failure budget is the attacker or the facilitator sitting next to them.
			@Value("${faculty.access-token:}") String facultyToken) {

		long windowMs = Math.max(1, windowSeconds) * 1000L;

		Filter filter = new Filter() {
			@Override
			public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
					throws IOException, ServletException {

				HttpServletRequest request = (HttpServletRequest) req;
				HttpServletResponse response = (HttpServletResponse) res;

				if (!enabled) {
					chain.doFilter(req, res);
					return;
				}

				String method = request.getMethod();
				// Preflight carries no credentials and no payload; never counted.
				if ("OPTIONS".equalsIgnoreCase(method)) {
					chain.doFilter(req, res);
					return;
				}

				String path = request.getRequestURI() == null ? "" : request.getRequestURI();
				String ip = clientIp(request);

				// An IP that has already failed the facilitator token too often is refused before the
				// token filter runs, so guessing costs a 429 rather than another attempt.
				//
				// The exception matters more than the rule here: a request carrying the CORRECT token
				// is always let through. A cohort sits behind one campus NAT, so the facilitator and
				// every student share a single source IP — without this, any student could lock the
				// facilitator out of their own console mid-session just by spamming wrong tokens.
				// Guessing is still bounded, because a guess that is wrong is exactly the case this
				// exception does not cover.
				Window failures = authFailures.get(ip);
				if (path.startsWith("/api/faculty") && failures != null
						&& failures.count.get() >= authFailureLimit
						&& System.currentTimeMillis() - failures.startedAtMs < windowMs
						&& !hasValidFacultyToken(request, facultyToken)) {
					reject(response, windowSeconds,
							"Too many failed attempts. Please wait a minute and try again.");
					return;
				}

				if (isWrite(method) && overLimit(writes, ip, windowMs, writeLimit)) {
					log.warn("Rate limit hit (writes) ip={} path={}", ip, path);
					reject(response, windowSeconds, "Too many requests. Please slow down and try again.");
					return;
				}

				if (path.startsWith("/api/teams/resolve/")
						&& overLimit(joinCodes, ip, windowMs, joinCodeLimit)) {
					log.warn("Rate limit hit (join codes) ip={}", ip);
					reject(response, windowSeconds, "Too many attempts. Please wait a moment and try again.");
					return;
				}

				chain.doFilter(req, res);

				// Count the failure only AFTER the token filter has ruled, so a facilitator who is
				// signed in correctly is never counted no matter how much the console polls.
				if (path.startsWith("/api/faculty")
						&& response.getStatus() == HttpServletResponse.SC_UNAUTHORIZED) {
					int n = authFailures.computeIfAbsent(ip, k -> new Window()).hit(windowMs);
					if (n >= authFailureLimit) {
						log.warn("Facilitator token: {} failed attempts from ip={}", n, ip);
					}
				}

				sweepIfLarge(windowMs);
			}
		};

		FilterRegistrationBean<Filter> registration = new FilterRegistrationBean<>(filter);
		registration.addUrlPatterns("/api/*");
		registration.setName("rateLimitFilter");
		// After CORS (HIGHEST) and the security headers (+5) so a 429 still carries both, and before
		// the faculty token filter (+10) so a blocked IP never reaches the token comparison.
		registration.setOrder(Ordered.HIGHEST_PRECEDENCE + 7);
		return registration;
	}

	/**
	 * Whether the request carries the correct facilitator token. Mirrors the auth filter: same header,
	 * same trimming, same constant-time comparison so this check cannot be used as a timing oracle
	 * either. A blank configured token matches nothing (the auth filter fails closed on that too).
	 */
	private boolean hasValidFacultyToken(HttpServletRequest request, String configuredToken) {
		String configured = configuredToken == null ? "" : configuredToken.trim();
		if (configured.isBlank()) {
			return false;
		}
		String supplied = request.getHeader(FacultyAuthFilter.HEADER);
		if (supplied == null) {
			return false;
		}
		String trimmed = supplied.trim();
		if (trimmed.isBlank()) {
			return false;
		}
		byte[] a = configured.getBytes(java.nio.charset.StandardCharsets.UTF_8);
		byte[] b = trimmed.getBytes(java.nio.charset.StandardCharsets.UTF_8);
		int diff = a.length ^ b.length;
		for (int i = 0; i < a.length && i < b.length; i++) {
			diff |= a[i] ^ b[i];
		}
		return diff == 0;
	}

	private boolean isWrite(String method) {
		return "POST".equalsIgnoreCase(method)
				|| "PUT".equalsIgnoreCase(method)
				|| "DELETE".equalsIgnoreCase(method)
				|| "PATCH".equalsIgnoreCase(method);
	}

	private boolean overLimit(Map<String, Window> buckets, String ip, long windowMs, int limit) {
		return buckets.computeIfAbsent(ip, k -> new Window()).hit(windowMs) > limit;
	}

	private void reject(HttpServletResponse response, int retryAfterSeconds, String message)
			throws IOException {
		response.setStatus(429);
		response.setHeader("Retry-After", String.valueOf(retryAfterSeconds));
		response.setContentType("application/json");
		response.getWriter().write("{\"error\":\"" + message + "\"}");
	}

	/**
	 * The client's address as seen before the platform's proxy. Render terminates TLS and forwards,
	 * so {@code getRemoteAddr()} alone would return the proxy and collapse every visitor into one
	 * bucket. The left-most X-Forwarded-For entry is the original client.
	 */
	private String clientIp(HttpServletRequest request) {
		String forwarded = request.getHeader("X-Forwarded-For");
		if (forwarded != null && !forwarded.isBlank()) {
			int comma = forwarded.indexOf(',');
			String first = (comma > 0 ? forwarded.substring(0, comma) : forwarded).trim();
			if (!first.isEmpty()) {
				// Cap the length: this value is attacker-controlled and becomes a map key.
				return first.length() > 45 ? first.substring(0, 45) : first;
			}
		}
		String remote = request.getRemoteAddr();
		return remote == null ? "unknown" : remote;
	}

	/** Drops idle buckets so a long-running instance cannot grow a map entry per visiting IP. */
	private void sweepIfLarge(long windowMs) {
		sweep(writes, windowMs);
		sweep(joinCodes, windowMs);
		sweep(authFailures, windowMs);
	}

	private void sweep(Map<String, Window> buckets, long windowMs) {
		if (buckets.size() > 5000) {
			buckets.entrySet().removeIf(e -> e.getValue().isIdle(windowMs));
		}
	}
}
