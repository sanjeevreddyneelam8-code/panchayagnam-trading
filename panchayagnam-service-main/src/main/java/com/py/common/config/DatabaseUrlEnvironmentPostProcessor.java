package com.py.common.config;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

/**
 * Normalizes cloud-provider database URLs (Render/Neon/Supabase/Railway postgres:// and postgresql://)
 * into standard Spring Boot JDBC properties and enables Fast2SMS automatically when FAST2SMS_API_KEY is set.
 */
public class DatabaseUrlEnvironmentPostProcessor implements EnvironmentPostProcessor {

    @Override
    public void postProcessEnvironment(ConfigurableEnvironment environment, SpringApplication application) {
        Map<String, Object> overrides = new HashMap<>();

        String rawUrl = firstNonBlank(
                environment.getProperty("SPRING_DATASOURCE_URL"),
                environment.getProperty("DATABASE_URL"),
                environment.getProperty("spring.datasource.url")
        );

        if (rawUrl != null) {
            if (rawUrl.startsWith("postgres://") || rawUrl.startsWith("postgresql://")) {
                parseCloudPostgresUrl(rawUrl, environment, overrides);
            } else if (rawUrl.startsWith("mysql://")) {
                parseCloudMysqlUrl(rawUrl, environment, overrides);
            } else if (rawUrl.startsWith("jdbc:postgresql://")) {
                overrides.put("spring.datasource.url", rawUrl);
                overrides.put("spring.datasource.driver-class-name", "org.postgresql.Driver");
                overrides.put("spring.jpa.hibernate.ddl-auto", "update");
            } else if (rawUrl.startsWith("jdbc:mysql://")) {
                overrides.put("spring.datasource.url", rawUrl);
                overrides.put("spring.datasource.driver-class-name", "com.mysql.cj.jdbc.Driver");
                overrides.put("spring.jpa.hibernate.ddl-auto", "update");
            }
        }

        // If FAST2SMS_API_KEY is configured in environment and FAST2SMS_ENABLED was not explicitly set to false,
        // enable Fast2SMS automatically so paid SMS keys don't silently fall back to trial mode.
        String fast2SmsKey = environment.getProperty("FAST2SMS_API_KEY");
        String fast2SmsFlag = environment.getProperty("FAST2SMS_ENABLED");
        if (fast2SmsKey != null && !fast2SmsKey.isBlank()
                && (fast2SmsFlag == null || fast2SmsFlag.isBlank())) {
            overrides.put("fast2sms.enabled", "true");
        }

        if (!overrides.isEmpty()) {
            environment.getPropertySources().addFirst(new MapPropertySource("pyCloudConfigOverrides", overrides));
        }
    }

    private void parseCloudPostgresUrl(String rawUrl, ConfigurableEnvironment env, Map<String, Object> overrides) {
        try {
            String normalized = rawUrl.startsWith("postgres://")
                    ? "postgresql://" + rawUrl.substring("postgres://".length())
                    : rawUrl;
            URI uri = URI.create(normalized);
            String host = uri.getHost();
            int port = uri.getPort();
            String path = uri.getRawPath();
            String query = uri.getRawQuery();
            String jdbc = "jdbc:postgresql://" + host + (port > 0 ? ":" + port : "") + (path != null ? path : "")
                    + (query != null && !query.isBlank() ? "?" + query : "");
            overrides.put("spring.datasource.url", jdbc);
            overrides.put("spring.datasource.driver-class-name", "org.postgresql.Driver");
            overrides.put("spring.jpa.hibernate.ddl-auto", "update");
            applyUserInfoIfAbsent(uri.getRawUserInfo(), env, overrides);
        } catch (Exception ignored) {
            // Leave untouched if URI cannot be parsed
        }
    }

    private void parseCloudMysqlUrl(String rawUrl, ConfigurableEnvironment env, Map<String, Object> overrides) {
        try {
            URI uri = URI.create(rawUrl);
            String host = uri.getHost();
            int port = uri.getPort();
            String path = uri.getRawPath();
            String query = uri.getRawQuery();
            String jdbc = "jdbc:mysql://" + host + (port > 0 ? ":" + port : "") + (path != null ? path : "")
                    + (query != null && !query.isBlank() ? "?" + query : "");
            overrides.put("spring.datasource.url", jdbc);
            overrides.put("spring.datasource.driver-class-name", "com.mysql.cj.jdbc.Driver");
            overrides.put("spring.jpa.hibernate.ddl-auto", "update");
            applyUserInfoIfAbsent(uri.getRawUserInfo(), env, overrides);
        } catch (Exception ignored) {
        }
    }

    private void applyUserInfoIfAbsent(String rawUserInfo, ConfigurableEnvironment env, Map<String, Object> overrides) {
        if (rawUserInfo == null || rawUserInfo.isBlank()) {
            return;
        }
        String existingUser = env.getProperty("SPRING_DATASOURCE_USERNAME");
        String existingPass = env.getProperty("SPRING_DATASOURCE_PASSWORD");
        String[] parts = rawUserInfo.split(":", 2);
        if ((existingUser == null || existingUser.isBlank()) && parts.length >= 1 && !parts[0].isEmpty()) {
            overrides.put("spring.datasource.username", URLDecoder.decode(parts[0], StandardCharsets.UTF_8));
        }
        if ((existingPass == null || existingPass.isBlank()) && parts.length == 2) {
            overrides.put("spring.datasource.password", URLDecoder.decode(parts[1], StandardCharsets.UTF_8));
        }
    }

    private String firstNonBlank(String... values) {
        for (String v : values) {
            if (v != null && !v.isBlank()) {
                return v.trim();
            }
        }
        return null;
    }
}
