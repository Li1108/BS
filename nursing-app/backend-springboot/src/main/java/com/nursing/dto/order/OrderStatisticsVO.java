package com.nursing.dto.order;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * 订单统计VO（护士端）
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OrderStatisticsVO {

    /**
     * 今日订单数
     */
    private Integer todayOrders;

    /**
     * 今日收入
     */
    private BigDecimal todayIncome;

    /**
     * 本月订单数
     */
    private Integer monthOrders;

    /**
     * 本月收入
     */
    private BigDecimal monthIncome;

    /**
     * 待处理订单数（已接单未完成）
     */
    private Integer pendingOrders;

    /**
     * 总完成订单数
     */
    private Integer totalCompletedOrders;

    /**
     * 账户余额
     */
    private BigDecimal balance;
}
