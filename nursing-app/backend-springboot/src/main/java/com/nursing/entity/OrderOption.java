package com.nursing.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import lombok.Builder;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import java.io.Serial;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 订单可选项快照表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("order_option")
public class OrderOption implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long orderId;
    private Long serviceOptionId;
    private String optionNameSnapshot;
    private BigDecimal optionPriceSnapshot;
    private LocalDateTime createTime;
}
