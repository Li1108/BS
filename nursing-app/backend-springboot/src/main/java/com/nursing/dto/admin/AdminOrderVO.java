package com.nursing.dto.admin;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 管理端订单展示VO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdminOrderVO {

    private Long id;
    private String orderNo;

    private String serviceName;
    private BigDecimal servicePrice;
    private BigDecimal totalAmount;
    private BigDecimal platformFee;
    private BigDecimal nurseIncome;

    private String contactName;
    private String contactPhone;
    private String address;
    private BigDecimal latitude;
    private BigDecimal longitude;

    /** 订单状态（0-10） */
    private Integer status;
    /** 支付状态（0-2） */
    private Integer payStatus;
    /** 退款状态（0无退款 1退款中 2已退款） */
    private Integer refundStatus;

    private String nurseName;
    private String nursePhone;

    private String remark;

    private LocalDateTime appointmentTime;
    private LocalDateTime arrivalTime;
    private String arrivalPhoto;
    private LocalDateTime startTime;
    private String startPhoto;
    private LocalDateTime finishTime;
    private String finishPhoto;
    private LocalDateTime createdAt;
}
