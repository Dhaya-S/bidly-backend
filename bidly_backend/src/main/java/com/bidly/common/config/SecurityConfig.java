package com.bidly.common.config;

import com.bidly.common.security.JwtAuthenticationFilter;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * Spring Security configuration — stateless JWT-based security.
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    public SecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
    }

    /** Endpoints that do NOT require a JWT token. */
    private static final String[] PUBLIC_ENDPOINTS = {
            "/auth/**",
            "/posts/**",
            "/categories/**",
            "/listings/**",
            "/auctions/**",
            "/media/**",
            "/communities/**",
            "/ws/**",
            "/actuator/health",
            "/reviews/seller/**",
            "/wallet/razorpay/webhook"
    };

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        return http
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(eh -> eh
                        .authenticationEntryPoint((request, response, authException) -> {
                            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
                            response.setContentType("application/json");
                            response.getWriter().write("{\"success\":false,\"message\":\"Authentication required\",\"data\":null}");
                        })
                )
                .authorizeHttpRequests(auth -> auth
                        // 1. Strict authenticated listing operations
                        .requestMatchers(org.springframework.http.HttpMethod.POST, "/listings").authenticated()
                        .requestMatchers(org.springframework.http.HttpMethod.PUT, "/listings/**").authenticated()
                        .requestMatchers(org.springframework.http.HttpMethod.DELETE, "/listings/**").authenticated()
                        .requestMatchers("/listings/my", "/listings/wishlist").authenticated()
                        .requestMatchers("/listings/*/like").authenticated()

                        // 2. Strict authenticated community & post mutations
                        .requestMatchers(org.springframework.http.HttpMethod.POST, "/communities").authenticated()
                        .requestMatchers(org.springframework.http.HttpMethod.PUT, "/communities/**").authenticated()
                        .requestMatchers(org.springframework.http.HttpMethod.DELETE, "/communities/**").authenticated()
                        .requestMatchers("/communities/*/join", "/communities/*/leave", "/communities/*/toggle-mute").authenticated()
                        .requestMatchers(org.springframework.http.HttpMethod.POST, "/posts/**").authenticated()
                        .requestMatchers(org.springframework.http.HttpMethod.DELETE, "/posts/**").authenticated()

                        // 3. Public endpoints for read & auth
                        .requestMatchers(PUBLIC_ENDPOINTS).permitAll()
                        .requestMatchers("/admin/**").authenticated()
                        .anyRequest().authenticated()
                )
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)
                .build();
    }
}
