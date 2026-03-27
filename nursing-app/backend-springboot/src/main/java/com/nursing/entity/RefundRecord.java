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
 * 退款记录表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("refund_record")
public class RefundRecord implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long orderId;
    private String orderNo;
    private BigDecimal refundAmount;

    /** 0待处理 1退款成功 2退款失败 */
    private Integer refundStatus;

    private String refundReason;

    /** 第三方退款号 */
    private String thirdRefundNo;

    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
