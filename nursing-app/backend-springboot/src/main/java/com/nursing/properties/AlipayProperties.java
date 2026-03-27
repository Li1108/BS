package com.nursing.properties;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * 支付宝配置属性
 */
@Data
@Component
@ConfigurationProperties(prefix = "alipay")
public class AlipayProperties {
    /**
     * 网关地址
     */
    private String gatewayUrl = "https://openapi-sandbox.dl.alipaydev.com/gateway.do";
    
    /**
     * 应用ID
     */
    private String appId = "9021000158679392";
    
    /**
     * 应用私钥
     */
    private String privateKey;
    
    /**
     * 支付宝公钥
     */
    private String alipayPublicKey;
    
    /**
     * 异步通知地址
     */
    private String notifyUrl = "http://localhost:8081/api/v1/payment/notify";
    
    /**
     * 同步返回地址
     */
    private String returnUrl = "http://localhost:8081/api/v1/payment/return";
    
    /**
     * 字符集
     */
    private String charset = "utf-8";
    
    /**
     * 签名类型
     */
    private String signType = "RSA2";
    
    /**
     * 数据格式
     */
    private String format = "json";
}
