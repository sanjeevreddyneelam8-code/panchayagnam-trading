package com.py.common.security;

import com.py.common.util.PyJwtUtil;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Collections;
import java.util.List;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(JwtAuthenticationFilter.class);

    @Autowired
    private PyJwtUtil pyJwtUtil;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String authHeader = request.getHeader("Authorization");

        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7).trim();
            try {
                if (!token.isEmpty() && pyJwtUtil.isTokenValid(token)) {
                    String phone = pyJwtUtil.extractPhoneNumber(token);
                    Long userId = pyJwtUtil.extractUserId(token);
                    String role = pyJwtUtil.extractRole(token);

                    String roleName = (role != null && !role.isBlank()) ? role.trim().toUpperCase() : "USER";
                    if (!roleName.startsWith("ROLE_")) {
                        roleName = "ROLE_" + roleName;
                    }

                    List<SimpleGrantedAuthority> authorities =
                            Collections.singletonList(new SimpleGrantedAuthority(roleName));

                    UsernamePasswordAuthenticationToken authentication =
                            new UsernamePasswordAuthenticationToken(phone != null ? phone : String.valueOf(userId), null, authorities);
                    authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

                    SecurityContextHolder.getContext().setAuthentication(authentication);
                    log.debug("Authenticated request | uri={} | user={} | role={}", request.getRequestURI(), phone, roleName);
                }
            } catch (Exception e) {
                log.warn("Invalid JWT token on request to {}: {}", request.getRequestURI(), e.getMessage());
            }
        }

        filterChain.doFilter(request, response);
    }
}
