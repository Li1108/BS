package com.nursing.dto.order;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 支付请求响应
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PaymentResponse {

    /**
     * 订单号
     */
    private String orderNo;

    /**
     * 支付宝交易号
     */
    private String tradeNo;

    /**
     * 支付表单（App调起支付用）
     */
    private String payForm;

    /**
     * 支付链接（H5支付用）
     */
    private String payUrl;

    /**
     * 支付方式：APP, H5, PC
     */
    private String payType;
}
