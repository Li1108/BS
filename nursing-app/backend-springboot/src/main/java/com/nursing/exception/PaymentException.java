package com.nursing.exception;

import lombok.Getter;

/**
 * 支付异常
 */
@Getter
public class PaymentException extends BusinessException {

    private final String orderNo;
    private final PaymentErrorType errorType;

    public PaymentException(String message, String orderNo, PaymentErrorType errorType) {
        super(message);
        this.orderNo = orderNo;
        this.errorType = errorType;
    }

    public PaymentException(String message, String orderNo, PaymentErrorType errorType, Throwable cause) {
        super(message, cause);
        this.orderNo = orderNo;
        this.errorType = errorType;
    }

    /**
     * 支付错误类型
     */
    public enum PaymentErrorType {
        /** 支付创建失败 */
        CREATE_FAILED,
        /** 支付超时 */
        TIMEOUT,
        /** 支付验签失败 */
        VERIFY_FAILED,
        /** 退款失败 */
        REFUND_FAILED,
        /** 退款处理中 */
        REFUND_PROCESSING,
        /** 重复支付 */
        DUPLICATE_PAYMENT,
        /** 订单状态错误 */
        INVALID_ORDER_STATUS,
        /** 金额不匹配 */
        AMOUNT_MISMATCH
    }
}
