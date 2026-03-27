package com.nursing.config;

import com.nursing.security.JwtAccessDeniedHandler;
import com.nursing.security.JwtAuthenticationEntryPoint;
import com.nursing.security.JwtAuthenticationFilter;
import com.nursing.security.SecurityHeadersFilter;
import com.nursing.security.XssFilter;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.web.header.HeaderWriterFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.Arrays;
import java.util.List;

/**
 * Spring Security 配置
 * 包含JWT认证、CORS、权限控制
 * 角色：USER / NURSE / ADMIN_SUPER
 */
@Configuration
@EnableWebSecurity
@EnableMethodSecurity(prePostEnabled = true, securedEnabled = true)
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final JwtAuthenticationEntryPoint jwtAuthenticationEntryPoint;
    private final JwtAccessDeniedHandler jwtAccessDeniedHandler;
    private final XssFilter xssFilter;
    private final SecurityHeadersFilter securityHeadersFilter;

    @Value("${cors.allowed-origins:http://localhost:5173,http://localhost:3000,http://127.0.0.1:3000}")
    private List<String> allowedOrigins;

    /**
     * 白名单路径（无需认证）
        * 路径不含 context-path 前缀（当前 server.servlet.context-path=/api/v1）
     */
    private static final String[] WHITE_LIST = {
            // 认证相关（匹配 OpenAPI: /api/auth/sendCode, /api/auth/login）
            "/auth/sendCode",
            "/auth/login",
            "/auth/login/password",
            "/admin/auth/login",
            // 静态资源
            "/uploads/**",
            "/static/**",
            // API文档
            "/swagger-ui/**",
            "/swagger-ui.html",
            "/v3/api-docs/**",
            "/swagger-resources/**",
            "/webjars/**",
            // Actuator
            "/actuator/health",
            "/actuator/info",
            // 支付回调
            "/payment/notify",
            "/payment/return",
            // 服务项目列表（公开接口）
            "/service/category/list",
            "/service/item/list",
            "/service/item/detail/**",
            "/service/item/options/**",
            // 评价查询（公开）
                "/evaluation/order/**"
    };

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                // 禁用CSRF（使用JWT不需要CSRF保护）
                .csrf(AbstractHttpConfigurer::disable)
                // 启用CORS
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                // 禁用Session（使用JWT无状态认证）
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                // 异常处理
                .exceptionHandling(exception -> exception
                        .authenticationEntryPoint(jwtAuthenticationEntryPoint)
                        .accessDeniedHandler(jwtAccessDeniedHandler)
                )
                // 请求授权配置
                .authorizeHttpRequests(auth -> auth
                        // 白名单路径
                        .requestMatchers(WHITE_LIST).permitAll()
                        // OPTIONS请求放行
                        .requestMatchers(HttpMethod.OPTIONS).permitAll()
                        // 管理员接口 - 使用 ADMIN_SUPER 角色
                        .requestMatchers("/admin/**").hasRole("ADMIN_SUPER")
                        // 护士注册（登录用户可提交）
                        .requestMatchers("/nurse/register").authenticated()
                        // 护士接口
                        .requestMatchers("/nurse/**").hasAnyRole("NURSE", "ADMIN_SUPER")
                        // 其他请求需要认证
                        .anyRequest().authenticated()
                )
                // 添加安全响应头过滤器
                .addFilterBefore(securityHeadersFilter, HeaderWriterFilter.class)
                // 添加XSS过滤器
                .addFilterAfter(xssFilter, SecurityHeadersFilter.class)
                // 添加JWT过滤器
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    /**
     * 密码编码器
     */
    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * CORS配置
     */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        // 使用 allowedOriginPatterns 替代 allowedOrigins 以支持 Spring Security 6.x
        configuration.setAllowedOriginPatterns(allowedOrigins);
        configuration.setAllowedMethods(Arrays.asList("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"));
        configuration.setAllowedHeaders(Arrays.asList("*"));
        configuration.setAllowCredentials(true);
        configuration.setMaxAge(3600L);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }
}
