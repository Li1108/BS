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
 * 护士钱包流水表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("nurse_wallet_log")
public class WalletLog implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long nurseUserId;

    /** 关联订单号 */
    private String orderNo;

    /** 类型 1收入 2提现扣减 3退款扣减 */
    private Integer changeType;

    private BigDecimal changeAmount;
    private BigDecimal balanceAfter;
    private String remark;
    private LocalDateTime createTime;
}
