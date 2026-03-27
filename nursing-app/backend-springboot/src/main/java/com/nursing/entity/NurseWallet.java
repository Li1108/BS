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
 * 护士钱包表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("nurse_wallet")
public class NurseWallet implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long nurseUserId;

    /** 余额 */
    private BigDecimal balance;

    /** 累计收入 */
    private BigDecimal totalIncome;

    /** 累计提现 */
    private BigDecimal totalWithdraw;

    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
