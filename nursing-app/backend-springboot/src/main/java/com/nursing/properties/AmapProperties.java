package com.nursing.properties;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * 高德地图配置属性
 */
@Data
@Component
@ConfigurationProperties(prefix = "amap")
public class AmapProperties {
    /**
     * API密钥
     */
    private String apiKey = "27099005ec372959e5e03ad1faa54fa1";
    
    /**
     * 基础URL
     */
    private String baseUrl = "https://restapi.amap.com/v3";
}
