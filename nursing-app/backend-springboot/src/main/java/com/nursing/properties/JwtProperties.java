package com.nursing.properties;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * JWT配置属性
 */
@Data
@Component
@ConfigurationProperties(prefix = "jwt")
public class JwtProperties {
    /**
     * JWT密钥
     */
    private String secret = "NursingServiceAppSecretKey2024VeryLongSecretKeyForHS512Algorithm";
    
    /**
     * JWT过期时间（毫秒）默认24小时
     */
    private Long expiration = 86400000L;
    
    /**
     * 刷新令牌过期时间（毫秒）默认7天
     */
    private Long refreshExpiration = 604800000L;
    
    /**
     * JWT请求头
     */
    private String header = "Authorization";
    
    /**
     * JWT前缀
     */
    private String prefix = "Bearer ";
}
