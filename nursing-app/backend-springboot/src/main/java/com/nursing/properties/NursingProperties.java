package com.nursing.properties;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * 护理业务配置属性
 */
@Data
@Component
@ConfigurationProperties(prefix = "nursing")
public class NursingProperties {
    /**
     * 平台费率
     */
    private Double platformFeeRate = 0.20;
    
    /**
     * 订单取消时间窗口（分钟）
     */
    private Integer orderCancelWindow = 30;
    
    /**
     * 护士位置上报间隔（分钟）
     */
    private Integer nurseLocationInterval = 5;
    
    /**
     * 订单匹配半径（公里）
     */
    private Integer orderMatchRadius = 10;
    
    /**
     * 推送配置
     */
    private Push push = new Push();
    
    @Data
    public static class Push {
        /**
         * 默认推送半径（公里）
         */
        private Integer defaultRadiusKm = 10;
        
        /**
         * 是否启用异步推送（RabbitMQ）
         */
        private Boolean asyncEnabled = true;
    }
}
