package com.nursing.properties;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * 阿里云服务配置属性
 */
@Data
@Component
@ConfigurationProperties(prefix = "aliyun")
public class AliyunProperties {
    /**
     * 短信服务配置
     */
    private Sms sms = new Sms();
    
    /**
     * 移动推送配置
     */
    private Push push = new Push();
    
    @Data
    public static class Sms {
        /**
         * AccessKey ID
         */
        private String accessKeyId;
        
        /**
         * AccessKey Secret
         */
        private String accessKeySecret;
        
        /**
         * 签名名称
         */
        private String signName;
        
        /**
         * 模板代码
         */
        private String templateCode;
        
        /**
         * 接口地址
         */
        private String endpoint = "dysmsapi.aliyuncs.com";
    }
    
    @Data
    public static class Push {
        /**
         * AccessKey ID
         */
        private String accessKeyId;
        
        /**
         * AccessKey Secret
         */
        private String accessKeySecret;
        
        /**
         * App Key
         */
        private String appKey;
        
        /**
         * 区域ID
         */
        private String regionId = "cn-hangzhou";
    }
}
