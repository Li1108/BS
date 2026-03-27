package com.nursing.dto.push;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serial;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 新订单推送DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NewOrderPushDTO implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    /**
     * 订单ID
     */
    private Long orderId;

    /**
     * 订单号
     */
    private String orderNo;

    /**
     * 服务名称
     */
    private String serviceName;

    /**
     * 服务价格
     */
    private BigDecimal servicePrice;

    /**
     * 护士预计收入
     */
    private BigDecimal nurseIncome;

    /**
     * 预约时间
     */
    private LocalDateTime appointmentTime;

    /**
     * 服务地址
     */
    private String address;

    /**
     * 地址纬度
     */
    private BigDecimal latitude;

    /**
     * 地址经度
     */
    private BigDecimal longitude;

    /**
     * 推送半径（公里）
     */
    private Double radiusKm;

    /**
     * 服务区域
     */
    private String serviceArea;
}
