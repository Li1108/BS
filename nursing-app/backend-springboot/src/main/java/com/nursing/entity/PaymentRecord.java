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
 * 支付记录表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("payment_record")
public class PaymentRecord implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long orderId;
    private String orderNo;

    /** 1支付宝 2微信 */
    private Integer payMethod;

    private BigDecimal payAmount;

    /** 0未支付 1成功 2失败 */
    private Integer payStatus;

    /** 第三方交易号 */
    private String tradeNo;

    /** 回调原文 */
    private String callbackContent;

    private LocalDateTime payTime;
    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
