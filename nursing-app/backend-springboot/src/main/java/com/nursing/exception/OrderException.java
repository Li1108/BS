package com.nursing.exception;

import lombok.Getter;

/**
 * 订单异常
 */
@Getter
public class OrderException extends BusinessException {

    private final Long orderId;
    private final OrderErrorType errorType;

    public OrderException(String message, Long orderId, OrderErrorType errorType) {
        super(message);
        this.orderId = orderId;
        this.errorType = errorType;
    }

    public OrderException(String message, Long orderId, OrderErrorType errorType, Throwable cause) {
        super(message, cause);
        this.orderId = orderId;
        this.errorType = errorType;
    }

    /**
     * 订单错误类型
     */
    public enum OrderErrorType {
        /** 订单不存在 */
        NOT_FOUND,
        /** 订单已取消 */
        CANCELLED,
        /** 订单状态不正确 */
        INVALID_STATUS,
        /** 无权操作 */
        NO_PERMISSION,
        /** 超过取消时间窗口 */
        CANCEL_TIMEOUT,
        /** 已被其他护士接单 */
        ALREADY_ACCEPTED,
        /** 护士未通过审核 */
        NURSE_NOT_APPROVED,
        /** 护士休息中 */
        NURSE_OFF_DUTY,
        /** 服务已完成 */
        ALREADY_COMPLETED,
        /** 订单创建失败 */
        CREATE_FAILED
    }
}
