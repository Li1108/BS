package com.nursing.dto.order;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * 取消订单请求
 */
@Data
public class CancelOrderRequest {

    /**
     * 取消原因
     */
    @NotBlank(message = "取消原因不能为空")
    private String cancelReason;
}
