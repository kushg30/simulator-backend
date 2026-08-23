package com.example.simulator.config;

import java.io.IOException;

import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;

import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletResponse;

/**
 * Adds baseline security response headers to every API response. The API returns JSON (not HTML
 * the browser renders), so the frontend's Content-Security-Policy is the primary defence; these
 * headers harden the responses regardless of how they are consumed.
 */
@Configuration
public class SecurityHeadersFilter {

    @Bean
    public FilterRegistrationBean<Filter> securityHeadersFilterRegistration() {
        Filter filter = new Filter() {
            @Override
            public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
                    throws IOException, ServletException {
                HttpServletResponse response = (HttpServletResponse) res;
                response.setHeader("X-Content-Type-Options", "nosniff");
                response.setHeader("X-Frame-Options", "DENY");
                response.setHeader("Referrer-Policy", "no-referrer");
                response.setHeader("Strict-Transport-Security",
                        "max-age=63072000; includeSubDomains; preload");
                chain.doFilter(req, res);
            }
        };

        FilterRegistrationBean<Filter> registration = new FilterRegistrationBean<>(filter);
        registration.addUrlPatterns("/*");
        registration.setName("securityHeadersFilter");
        // Just after CORS so the headers are present on normal and error responses alike.
        registration.setOrder(Ordered.HIGHEST_PRECEDENCE + 5);
        return registration;
    }
}
