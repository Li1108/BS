package com.nursing.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * 安全响应头过滤器
 * 添加安全相关的HTTP响应头
 */
@Slf4j
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class SecurityHeadersFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain filterChain) throws ServletException, IOException {
        
        // X-Content-Type-Options: 防止MIME类型嗅探
        response.setHeader("X-Content-Type-Options", "nosniff");
        
        // X-Frame-Options: 防止点击劫持
        response.setHeader("X-Frame-Options", "DENY");
        
        // X-XSS-Protection: 启用浏览器XSS过滤
        response.setHeader("X-XSS-Protection", "1; mode=block");
        
        // Strict-Transport-Security: 强制HTTPS（生产环境启用）
        // response.setHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
        
        // Content-Security-Policy: 内容安全策略
        response.setHeader("Content-Security-Policy", 
                "default-src 'self'; " +
                "script-src 'self' 'unsafe-inline' 'unsafe-eval'; " +
                "style-src 'self' 'unsafe-inline'; " +
                "img-src 'self' data: https:; " +
                "font-src 'self' data:; " +
                "connect-src 'self' https:;");
        
        // Referrer-Policy: 控制Referrer信息
        response.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
        
        // Permissions-Policy: 权限策略
        response.setHeader("Permissions-Policy", 
                "camera=(), microphone=(), geolocation=(self), payment=()");
        
        // Cache-Control: 防止敏感信息缓存
        if (isSensitivePath(request.getRequestURI())) {
            response.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
            response.setHeader("Pragma", "no-cache");
            response.setHeader("Expires", "0");
        }
        
        filterChain.doFilter(request, response);
    }

    /**
     * 判断是否为敏感路径
     */
    private boolean isSensitivePath(String path) {
        return path.contains("/auth/") || 
               path.contains("/admin/") || 
               path.contains("/nurse/wallet") ||
               path.contains("/user/");
    }
}
