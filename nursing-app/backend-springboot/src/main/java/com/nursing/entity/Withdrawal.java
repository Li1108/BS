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
 * 提现申请表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("withdrawal_record")
public class Withdrawal implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long nurseUserId;
    private BigDecimal withdrawAmount;
    private String bankName;
    private String bankAccount;
    private String accountHolder;

    /** 0待审核 1通过 2拒绝 3已打款 */
    private Integer status;

    private String auditRemark;
    private Long auditAdminId;
    private LocalDateTime auditTime;
    private LocalDateTime payTime;
    private LocalDateTime createTime;
    private LocalDateTime updateTime;

    public static class StatusEnum {
        public static final int PENDING = 0;
        public static final int APPROVED = 1;
        public static final int REJECTED = 2;
        public static final int PAID = 3;
    }
}
