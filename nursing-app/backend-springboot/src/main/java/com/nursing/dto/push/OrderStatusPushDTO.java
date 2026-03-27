package com.nursing.dto.push;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serial;
import java.io.Serializable;

/**
 * 订单状态更新推送DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OrderStatusPushDTO implements Serializable {

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
     * 目标用户ID（订单所属用户或护士）
     */
    private Long targetUserId;

    /**
     * 新状态
     */
    private Integer newStatus;

    /**
     * 状态描述
     */
    private String statusDesc;

    /**
     * 操作者角色（USER/NURSE/ADMIN）
     */
    private String operatorRole;

    /**
     * 推送标题
     */
    private String title;

    /**
     * 推送内容
     */
    private String content;
}
