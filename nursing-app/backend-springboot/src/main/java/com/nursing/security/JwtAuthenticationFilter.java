package com.nursing.security;

import com.nursing.entity.SysUser;
import com.nursing.mapper.SysUserMapper;
import com.nursing.mapper.TokenBlacklistMapper;
import com.nursing.utils.JwtUtils;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Date;
import java.util.Collections;

/**
 * JWT 认证过滤器
 * token解析后拿到 userId + roleCode
 * 检查 token_blacklist 表（无Redis替代方案）
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtUtils jwtUtils;
    private final SysUserMapper sysUserMapper;
    private final TokenBlacklistMapper tokenBlacklistMapper;

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain filterChain) throws ServletException, IOException {
        try {
            String token = getTokenFromRequest(request);

            if (StringUtils.hasText(token) && jwtUtils.validateToken(token)) {
                // 检查token是否在黑名单中（无Redis，查DB）
                if (tokenBlacklistMapper.countByToken(token) > 0) {
                    log.warn("Token已在黑名单中");
                    filterChain.doFilter(request, response);
                    return;
                }

                Long userId = jwtUtils.getUserIdFromToken(token);
                String role = jwtUtils.getRoleFromToken(token);

                if (userId != null && role != null) {
                    // 验证用户是否存在且状态正常
                    SysUser user = sysUserMapper.selectById(userId);
                    if (user != null && user.getStatus() == SysUser.StatusEnum.NORMAL) {
                        Date issuedAtDate = jwtUtils.getIssuedAtFromToken(token);
                        LocalDateTime lastLoginTime = user.getLastLoginTime();
                        if (issuedAtDate != null && lastLoginTime != null) {
                            LocalDateTime issuedAt = LocalDateTime.ofInstant(
                                    issuedAtDate.toInstant(),
                                    ZoneId.systemDefault()
                            );
                            if (issuedAt.isBefore(lastLoginTime.minusSeconds(2))) {
                                log.warn("Token已被会话刷新策略失效: userId={}", userId);
                                filterChain.doFilter(request, response);
                                return;
                            }
                        }

                        // 创建认证对象，角色使用 ROLE_ 前缀
                        UsernamePasswordAuthenticationToken authentication =
                                new UsernamePasswordAuthenticationToken(
                                        userId,
                                        null,
                                        Collections.singletonList(new SimpleGrantedAuthority("ROLE_" + role))
                                );
                        authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

                        // 设置到SecurityContext
                        SecurityContextHolder.getContext().setAuthentication(authentication);
                    }
                }
            }
        } catch (Exception e) {
            log.error("JWT认证失败: {}", e.getMessage());
        }

        filterChain.doFilter(request, response);
    }

    /**
     * 从请求头中获取Token
     */
    private String getTokenFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}
