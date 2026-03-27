package com.nursing.dto.admin;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 提现审核VO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WithdrawalVO {

    private Long id;

    /**
     * 护士ID
     */
    private Long nurseId;

    /**
     * 护士真实姓名
     */
    private String nurseRealName;

    /**
     * 护士手机号
     */
    private String nursePhone;

    /**
     * 提现金额
     */
    private BigDecimal amount;

    /**
     * 提现支付宝账号
     */
    private String alipayAccount;

    /**
     * 账号真实姓名
     */
    private String realName;

    /**
     * 状态：0待审核, 1已打款, 2驳回
     */
    private Integer status;

    /**
     * 状态描述
     */
    private String statusDesc;

    /**
     * 驳回原因
     */
    private String rejectReason;

    /**
     * 申请时间
     */
    private LocalDateTime createdAt;

    /**
     * 审核时间
     */
    private LocalDateTime auditTime;
}
