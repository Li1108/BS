package com.nursing.utils;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.HashMap;
import java.util.Map;

/**
 * JWT 工具类
 */
@Slf4j
@Component
public class JwtUtils {

    @Value("${jwt.secret}")
    private String secret;

    @Value("${jwt.expiration}")
    private Long expiration;

    @Value("${jwt.refresh-expiration}")
    private Long refreshExpiration;

    private SecretKey secretKey;

    @PostConstruct
    public void init() {
        this.secretKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    /**
     * 生成Token
     *
     * @param userId   用户ID
     * @param phone    手机号
     * @param role     角色
     * @return Token
     */
    public String generateToken(Long userId, String phone, String role) {
        Map<String, Object> claims = new HashMap<>();
        claims.put("userId", userId);
        claims.put("phone", phone);
        claims.put("role", role);

        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + expiration);

        return Jwts.builder()
                .claims(claims)
                .subject(String.valueOf(userId))
                .issuedAt(now)
                .expiration(expiryDate)
                .signWith(secretKey)
                .compact();
    }

    /**
     * 生成刷新Token
     *
     * @param userId 用户ID
     * @return 刷新Token
     */
    public String generateRefreshToken(Long userId) {
        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + refreshExpiration);

        return Jwts.builder()
                .subject(String.valueOf(userId))
                .issuedAt(now)
                .expiration(expiryDate)
                .signWith(secretKey)
                .compact();
    }

    /**
     * 从Token中获取Claims
     *
     * @param token Token
     * @return Claims
     */
    public Claims getClaimsFromToken(String token) {
        try {
            return Jwts.parser()
                    .verifyWith(secretKey)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
        } catch (ExpiredJwtException e) {
            log.warn("Token已过期: {}", e.getMessage());
            throw e;
        } catch (Exception e) {
            log.error("Token解析失败: {}", e.getMessage());
            return null;
        }
    }

    /**
     * 从Token中获取用户ID
     *
     * @param token Token
     * @return 用户ID
     */
    public Long getUserIdFromToken(String token) {
        Claims claims = getClaimsFromToken(token);
        if (claims != null) {
            return claims.get("userId", Long.class);
        }
        return null;
    }

    /**
     * 从Token中获取手机号
     *
     * @param token Token
     * @return 手机号
     */
    public String getPhoneFromToken(String token) {
        Claims claims = getClaimsFromToken(token);
        if (claims != null) {
            return claims.get("phone", String.class);
        }
        return null;
    }

    /**
     * 从Token中获取角色
     *
     * @param token Token
     * @return 角色
     */
    public String getRoleFromToken(String token) {
        Claims claims = getClaimsFromToken(token);
        if (claims != null) {
            return claims.get("role", String.class);
        }
        return null;
    }

    /**
     * 验证Token是否有效
     *
     * @param token Token
     * @return 是否有效
     */
    public boolean validateToken(String token) {
        try {
            Jwts.parser()
                    .verifyWith(secretKey)
                    .build()
                    .parseSignedClaims(token);
            return true;
        } catch (Exception e) {
            log.error("Token验证失败: {}", e.getMessage());
            return false;
        }
    }

    /**
     * 获取Token过期时间
     *
     * @param token Token
     * @return 过期时间
     */
    public Date getExpirationFromToken(String token) {
        Claims claims = getClaimsFromToken(token);
        if (claims != null) {
            return claims.getExpiration();
        }
        return null;
    }

    /**
     * 获取Token签发时间
     *
     * @param token Token
     * @return 签发时间
     */
    public Date getIssuedAtFromToken(String token) {
        Claims claims = getClaimsFromToken(token);
        if (claims != null) {
            return claims.getIssuedAt();
        }
        return null;
    }

    /**
     * 获取Token过期时间（毫秒）
     *
     * @return 过期时间
     */
    public Long getExpiration() {
        return expiration;
    }
}
