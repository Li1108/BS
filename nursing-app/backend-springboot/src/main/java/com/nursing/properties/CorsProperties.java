package com.nursing.properties;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * CORS跨域配置属性
 */
@Data
@Component
@ConfigurationProperties(prefix = "cors")
public class CorsProperties {
    /**
     * 允许的源
     */
    private List<String> allowedOrigins = List.of(
            "http://localhost:5173",
            "http://localhost:3000",
            "http://127.0.0.1:5173"
    );
    
    /**
     * 允许的HTTP方法
     */
    private List<String> allowedMethods = List.of("GET", "POST", "PUT", "DELETE", "OPTIONS");
    
    /**
     * 允许的请求头
     */
    private List<String> allowedHeaders = List.of("*");
    
    /**
     * 是否允许携带凭证
     */
    private Boolean allowCredentials = true;
    
    /**
     * 预检请求的有效期（秒）
     */
    private Long maxAge = 3600L;
}
