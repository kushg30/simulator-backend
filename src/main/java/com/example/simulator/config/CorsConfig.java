package com.example.simulator.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

import java.util.Arrays;
import java.util.List;

@Configuration
public class CorsConfig {

    /**
     * Browser origins allowed to call the API. Defaults to the production site plus local dev;
     * override in prod with the {@code APP_CORS_ALLOWED_ORIGINS} env var (comma-separated).
     * Patterns are supported (e.g. {@code https://*.vercel.app}) for preview deployments.
     */
    @Value("${app.cors.allowed-origins:https://caserun.in,https://www.caserun.in,https://*.vercel.app,http://localhost:3000}")
    private String allowedOrigins;

    /**
     * The CORS filter is registered at the HIGHEST precedence so it is the outermost filter and
     * adds the CORS headers to EVERY response — including a 401 from the faculty token filter.
     *
     * <p>Without an explicit order, the token filter could run first and short-circuit with a 401
     * that carries no Access-Control-Allow-Origin header; the browser then blocks that response and
     * surfaces it as "failed to fetch" rather than the actual 401. Making CORS outermost guarantees
     * the header is present on error responses too.
     */
    @Bean
    public FilterRegistrationBean<CorsFilter> corsFilter() {
        List<String> origins = Arrays.stream(allowedOrigins.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .toList();

        CorsConfiguration config = new CorsConfiguration();
        config.setAllowCredentials(false);
        // Restricted to the configured origins (no wildcard "*"): only our own frontends
        // may call the API from a browser.
        config.setAllowedOriginPatterns(origins);
        config.setAllowedHeaders(List.of("*"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.setExposedHeaders(List.of("*"));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);

        FilterRegistrationBean<CorsFilter> bean = new FilterRegistrationBean<>(new CorsFilter(source));
        bean.setOrder(Ordered.HIGHEST_PRECEDENCE);
        return bean;
    }
}
