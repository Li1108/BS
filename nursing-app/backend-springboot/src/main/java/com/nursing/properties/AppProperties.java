package com.nursing.properties;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * 应用配置属性
 */
@Data
@Component
@ConfigurationProperties(prefix = "app")
public class AppProperties {
    /**
     * 短信配置
     */
    private Sms sms = new Sms();

    /**
     * 推送配置
     */
    private Push push = new Push();
    
    @Data
    public static class Sms {
        /**
         * 是否启用固定验证码
         */
        private Boolean fixedCodeEnabled = true;
        
        /**
         * 固定验证码
         */
        private String fixedCode = "123456";
    }

    @Data
    public static class Push {
        /**
         * 是否启用真实阿里云推送
         */
        private Boolean enabled = false;
    }
}
