package com.nursing.dto.order;

import lombok.Data;

import java.math.BigDecimal;

/**
 * 护士接单请求
 */
@Data
public class AcceptOrderRequest {

    /**
     * 护士当前纬度（用于更新位置）
     */
    private BigDecimal latitude;

    /**
     * 护士当前经度（用于更新位置）
     */
    private BigDecimal longitude;
}
