package com.nursing.dto.evaluation;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 创建评价请求
 */
@Data
public class CreateEvaluationRequest {

    /**
     * 订单ID
     */
    @NotNull(message = "订单ID不能为空")
    private Long orderId;

    /**
     * 评分（1-5星）
     */
    @NotNull(message = "评分不能为空")
    @Min(value = 1, message = "评分最低1分")
    @Max(value = 5, message = "评分最高5分")
    private Integer rating;

    /**
     * 评价内容
     */
    @Size(max = 500, message = "评价内容不能超过500字")
    private String comment;
}
