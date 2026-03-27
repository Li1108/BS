package com.nursing.properties;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 安全配置属性
 */
@Data
@Component
@ConfigurationProperties(prefix = "security")
public class SecurityProperties {
    /**
     * AES加密配置
     */
    private Aes aes = new Aes();
    
    /**
     * XSS防护配置
     */
    private Xss xss = new Xss();
    
    @Data
    public static class Aes {
        /**
         * AES密钥（32字节）
         */
        private String secretKey = "NursingServiceAES256SecretKey32B";
    }
    
    @Data
    public static class Xss {
        /**
         * 是否启用XSS防护
         */
        private Boolean enabled = true;
        
        /**
         * 排除路径
         */
        private List<String> excludePaths = List.of("/uploads/**", "/swagger-ui/**");
    }
}
