package com.py.common.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * In-memory IP rate limiter for public authentication endpoints to mitigate
 * brute-force MPIN guessing and OTP flooding.
 */
@Component
public class AuthRateLimitFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(AuthRateLimitFilter.class);

    private static final long LOGIN_WINDOW_MS = 5 * 60 * 1000L; // 5 minutes
    private static final int LOGIN_MAX_REQUESTS = 15;

    private static final long OTP_WINDOW_MS = 10 * 60 * 1000L; // 10 minutes
    private static final int OTP_MAX_REQUESTS = 8;

    private static final int MAX_BUCKETS = 10_000;

    private static final class WindowCounter {
        long windowStartMs;
        final AtomicInteger count = new AtomicInteger(0);

        WindowCounter(long now) {
            this.windowStartMs = now;
        }
    }

    private final Map<String, WindowCounter> buckets = new ConcurrentHashMap<>();

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        if (!"POST".equalsIgnoreCase(request.getMethod())) {
            filterChain.doFilter(request, response);
            return;
        }

        String uri = request.getRequestURI();
        long windowMs;
        int limit;
        if ("/api/v1/pyauth/login".equals(uri)
                || "/api/v1/pyauth/login-otp".equals(uri)
                || "/api/v1/pyauth/reset-mpin".equals(uri)) {
            windowMs = LOGIN_WINDOW_MS;
            limit = LOGIN_MAX_REQUESTS;
        } else if ("/api/v1/pyauth/send-otp".equals(uri) || "/api/v1/pyauth/register".equals(uri)) {
            windowMs = OTP_WINDOW_MS;
            limit = OTP_MAX_REQUESTS;
        } else {
            filterChain.doFilter(request, response);
            return;
        }

        String clientIp = extractClientIp(request);
        String key = uri + "|" + clientIp;
        long now = System.currentTimeMillis();

        if (buckets.size() > MAX_BUCKETS) {
            buckets.entrySet().removeIf(e -> (now - e.getValue().windowStartMs) > OTP_WINDOW_MS);
        }

        WindowCounter counter = buckets.compute(key, (k, existing) -> {
            if (existing == null || (now - existing.windowStartMs) >= windowMs) {
                return new WindowCounter(now);
            }
            return existing;
        });

        int current = counter.count.incrementAndGet();
        if (current > limit) {
            long retryAfterSec = Math.max(1L, (windowMs - (now - counter.windowStartMs)) / 1000L);
            log.warn("[SECURITY RATE LIMIT] Blocked {} requests from IP {} to {}", current, clientIp, uri);
            response.setStatus(429);
            response.setHeader("Retry-After", String.valueOf(retryAfterSec));
            response.setContentType("application/json;charset=UTF-8");
            response.getWriter().write(
                    "{\"success\":false,\"message\":\"Too many attempts. Please wait a few minutes and try again.\",\"data\":null}");
            return;
        }

        filterChain.doFilter(request, response);
    }

    private String extractClientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            int comma = forwarded.indexOf(',');
            return (comma > 0 ? forwarded.substring(0, comma) : forwarded).trim();
        }
        String realIp = request.getHeader("X-Real-IP");
        if (realIp != null && !realIp.isBlank()) {
            return realIp.trim();
        }
        return request.getRemoteAddr() != null ? request.getRemoteAddr() : "unknown";
    }
}
