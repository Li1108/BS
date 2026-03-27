package com.nursing.dto.order;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 订单详情VO
 * 匹配 order_main 表结构
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OrderVO {

    private Long id;
    private String orderNo;
    private Long userId;
    private Long nurseUserId;
    private Long serviceId;

    /** 服务名称快照 */
    private String serviceName;

    /** 订单总金额 */
    private BigDecimal totalAmount;

    /** 订单状态 0-10 */
    private Integer orderStatus;

    /** 支付状态 */
    private Integer payStatus;

    private LocalDateTime appointmentTime;

    /** 地址快照 */
    private String addressSnapshot;

    private String remark;

    /** 护士到达时间 */
    private LocalDateTime arrivalTime;

    /** 开始服务时间 */
    private LocalDateTime startTime;

    /** 完成服务时间 */
    private LocalDateTime finishTime;

    private LocalDateTime createTime;

    /**
     * 获取状态文本
     */
    public String getStatusText() {
        if (orderStatus == null) return "";
        return switch (orderStatus) {
            case 0 -> "待支付";
            case 1 -> "待接单";
            case 2 -> "已派单";
            case 3 -> "已接单";
            case 4 -> "护士已到达";
            case 5 -> "服务中";
            case 6 -> "已完成";
            case 7 -> "已评价";
            case 8 -> "已取消";
            case 9 -> "退款中";
            case 10 -> "已退款";
            default -> "未知";
        };
    }
}
