package com.nursing.dto.order;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class AdminUpdateOrderStatusRequest {
    @NotNull(message = "订单状态不能为空")
    private Integer status;

    private String remark;
}

