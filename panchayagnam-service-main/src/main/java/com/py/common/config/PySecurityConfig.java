package com.py.common.config;

import com.py.common.security.AuthRateLimitFilter;
import com.py.common.security.JwtAccessDeniedHandler;
import com.py.common.security.JwtAuthenticationEntryPoint;
import com.py.common.security.JwtAuthenticationFilter;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class PySecurityConfig {

    private static final Logger log = LoggerFactory.getLogger(PySecurityConfig.class);

    @Autowired
    private JwtAuthenticationEntryPoint authenticationEntryPoint;

    @Autowired
    private JwtAccessDeniedHandler accessDeniedHandler;

    @Autowired
    private JwtAuthenticationFilter jwtAuthenticationFilter;

    @Autowired
    private AuthRateLimitFilter authRateLimitFilter;

    @Value("#{'${app.cors.allowed-origins:https://sanjeevreddyneelam8-code.github.io,http://localhost:*,http://127.0.0.1:*}'.split(',')}")
    private List<String> allowedOriginPatterns;

    @Value("${app.security.public-docs-enabled:false}")
    private boolean publicDocsEnabled;

    @Bean
    public BCryptPasswordEncoder passwordEncoder() {
        log.info("BCryptPasswordEncoder bean initialized");
        return new BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        log.info("Configuring strict security filter chain (publicDocsEnabled={}, corsOrigins={})",
                publicDocsEnabled, allowedOriginPatterns);

        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(csrf -> csrf.disable())
                .formLogin(form -> form.disable())
                .httpBasic(basic -> basic.disable())
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint(authenticationEntryPoint)
                        .accessDeniedHandler(accessDeniedHandler)
                )
                .authorizeHttpRequests(auth -> {
                    // Public authentication endpoints (login, register, OTP, reset, health)
                    auth.requestMatchers(
                            "/health",
                            "/api/v1/pyauth/health",
                            "/api/v1/pyauth/login",
                            "/api/v1/pyauth/register",
                            "/api/v1/pyauth/send-otp",
                            "/api/v1/pyauth/reset-mpin",
                            "/actuator/health"
                    ).permitAll();

                    // Broker OAuth browser handoff & redirect callbacks
                    auth.requestMatchers(
                            "/profitmart/oauth/callback",
                            "/profitmart/oauth/getProfitLoginUrl",
                            "/api/v1/oauth/connect/**",
                            "/api/v1/oauth/callback/**"
                    ).permitAll();

                    // Static landing assets & CORS preflight
                    auth.requestMatchers(HttpMethod.GET, "/", "/favicon.ico").permitAll();
                    auth.requestMatchers(HttpMethod.OPTIONS, "/**").permitAll();

                    // Docs & H2 Console: strictly disabled/admin-only in production unless explicitly enabled
                    if (publicDocsEnabled) {
                        auth.requestMatchers(
                                "/panchayagnam/**",
                                "/v3/api-docs/**",
                                "/swagger-ui/**",
                                "/swagger-ui.html",
                                "/h2-console/**"
                        ).permitAll();
                    } else {
                        auth.requestMatchers("/h2-console/**").denyAll();
                        auth.requestMatchers(
                                "/panchayagnam/**",
                                "/v3/api-docs/**",
                                "/swagger-ui/**",
                                "/swagger-ui.html"
                        ).hasAnyRole("SUPER_ADMIN", "ADMIN");
                    }

                    // Administrative & SMS gateway setup endpoints require ADMIN / SUPER_ADMIN role
                    auth.requestMatchers(
                            "/api/v1/pyauth/admin/**",
                            "/api/v1/pyauth/demo-status",
                            "/api/v1/pyauth/fast2sms-check",
                            "/api/v1/pyauth/twilio-check",
                            "/api/v1/pyauth/2factor-check",
                            "/api/v1/pyauth/users/by-role",
                            "/pyconfig/**",
                            "/api/audit/**",
                            "/api/v1/audit/**"
                    ).hasAnyRole("SUPER_ADMIN", "ADMIN");

                    // All broker, group-order, dashboard, subscription & trading endpoints require valid JWT
                    auth.requestMatchers(
                            "/api/v1/trade-group/**",
                            "/api/v1/group-order/**",
                            "/api/v1/group-trade-log/**",
                            "/pyBrokerApi/**",
                            "/easyTradeApi/**",
                            "/api/v1/dashboard/**",
                            "/api/v1/hot-stocks/**",
                            "/api/smart/**",
                            "/api/v1/subscription/**",
                            "/profitmart/oauth/generate-totp",
                            "/profitmart/oauth/getAckTkn"
                    ).authenticated();

                    // Deny or require authentication for everything else
                    auth.anyRequest().authenticated();
                })
                .headers(headers -> headers
                        .frameOptions(frame -> frame.sameOrigin())
                        .contentTypeOptions(Customizer.withDefaults())
                        .referrerPolicy(ref -> ref.policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN))
                );

        http.addFilterBefore(authRateLimitFilter, UsernamePasswordAuthenticationFilter.class);
        http.addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        List<String> sanitizedOrigins = allowedOriginPatterns.stream()
                .map(String::trim)
                .filter(s -> !s.isEmpty() && !"*".equals(s))
                .toList();
        config.setAllowedOriginPatterns(sanitizedOrigins);
        config.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"));
        config.setAllowedHeaders(Arrays.asList("Authorization", "Content-Type", "Accept", "Origin", "X-Requested-With", "Idempotency-Key", "X-Idempotency-Key", "X-Admin-Setup-Token"));
        config.setExposedHeaders(Arrays.asList("Authorization"));
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
