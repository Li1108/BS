package com.nursing.dto.order;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 创建订单请求
 * 匹配 OpenAPI CreateOrderRequest schema
 */
@Data
public class CreateOrderRequest {

    /** 服务ID */
    @NotNull(message = "服务ID不能为空")
    private Long serviceId;

    /** 可选项ID列表 */
    private List<Long> optionIds;

    /** 预约时间 */
    @NotNull(message = "预约时间不能为空")
    private LocalDateTime appointmentTime;

    /** 地址ID */
    @NotNull(message = "地址ID不能为空")
    private Long addressId;

    /** 备注 */
    private String remark;
}
