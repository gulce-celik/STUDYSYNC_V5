/* FILE PURPOSE: Uygulama konfigurasyonu (CORS, security, zaman vb.) ve runtime davranisi ayarlari. */

package com.studysync.config;

import com.studysync.security.JwtAuthenticationFilter;
import org.springframework.http.HttpMethod;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http, JwtAuthenticationFilter jwtAuthenticationFilter) throws Exception {
        // Public endpoints: auth + health + reference catalogs + error/H2. All other API endpoints require JWT.
        http.csrf(csrf -> csrf.disable())
                .cors(Customizer.withDefaults())
                .headers(h -> h.frameOptions(frame -> frame.sameOrigin()))
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .authorizeHttpRequests(
                        auth -> auth.requestMatchers(HttpMethod.OPTIONS, "/**")
                                .permitAll()
                                .requestMatchers(
                                        "/h2-console/**",
                                        "/api/v1/auth/login",
                                        "/api/v1/auth/register-init",
                                        "/api/v1/auth/verify-otp",
                                        "/api/v1/auth/register-complete",
                                        "/api/v1/auth/refresh",
                                        "/api/v1/auth/forgot-password",
                                        "/api/v1/auth/reset-password",
                                        "/api/v1/auth/reset-password-otp",
                                        "/api/v1/health",
                                        "/api/v1/reference/**",
                                        "/error")
                                .permitAll()
                                .anyRequest()
                                .authenticated())
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
