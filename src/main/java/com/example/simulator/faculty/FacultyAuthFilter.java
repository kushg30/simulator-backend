package com.example.simulator.faculty;

import java.io.IOException;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;

import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

/**
 * Guards every {@code /api/faculty/**} endpoint with a shared facilitator token.
 *
 * <p>The platform has no user accounts, and a classroom does not need them: one token is handed to
 * the facilitator running the session. What it must NOT be is absent — these endpoints can pause a
 * round, bypass a twist and read grading state, so leaving them open would hand students the
 * controls of their own assessment.
 *
 * <p>Send the token as {@code X-Faculty-Token: <token>} (or {@code ?facultyToken=} for convenience
 * when clicking through a browser). Configure it with {@code faculty.access-token}; if that
 * property is left blank the filter refuses every request rather than failing open.
 */
@Configuration
public class FacultyAuthFilter {

	public static final String HEADER = "X-Faculty-Token";
	public static final String QUERY_PARAM = "facultyToken";
	private static final String PROTECTED_PREFIX = "/api/faculty";

	@Bean
	public FilterRegistrationBean<Filter> facultyTokenFilter(
			@Value("${faculty.access-token:}") String configuredToken) {

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

				String supplied = request.getHeader(HEADER);
				if (supplied == null || supplied.isBlank()) {
					supplied = request.getParameter(QUERY_PARAM);
				}

				// Fail closed: an unset token locks the endpoints rather than opening them.
				if (configuredToken == null || configuredToken.isBlank()) {
					deny(response, "Faculty controls are disabled: faculty.access-token is not configured");
					return;
				}

				if (supplied == null || !constantTimeEquals(configuredToken, supplied)) {
					deny(response, "Invalid or missing facilitator token");
					return;
				}

				chain.doFilter(req, res);
			}
		};

		FilterRegistrationBean<Filter> registration = new FilterRegistrationBean<>(filter);
		registration.addUrlPatterns(PROTECTED_PREFIX + "/*");
		registration.setName("facultyTokenFilter");
		return registration;
	}

	private void deny(HttpServletResponse response, String message) throws IOException {
		response.setStatus(HttpStatus.UNAUTHORIZED.value());
		response.setContentType("application/json");
		response.getWriter().write("{\"error\":\"" + message + "\"}");
	}

	/** Avoids leaking token contents through response timing. */
	private boolean constantTimeEquals(String a, String b) {
		byte[] x = a.getBytes();
		byte[] y = b.getBytes();
		int diff = x.length ^ y.length;
		for (int i = 0; i < x.length && i < y.length; i++) {
			diff |= x[i] ^ y[i];
		}
		return diff == 0;
	}
}
