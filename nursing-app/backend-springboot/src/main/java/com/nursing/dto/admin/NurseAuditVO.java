package com.nursing.dto.admin;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 护士审核VO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NurseAuditVO {

    /**
     * 护士用户ID
     */
    private Long userId;

    /**
     * 手机号
     */
    private String phone;

    /**
     * 真实姓名
     */
    private String realName;

    /**
     * 身份证号
     */
    private String idCardNo;

    /**
     * 身份证正面照片
     */
    private String idCardPhotoFront;

    /**
     * 身份证背面照片
     */
    private String idCardPhotoBack;

    /**
     * 执业证照片
     */
    private String certificatePhoto;

    /**
     * 审核状态：0待审，1通过，2拒绝
     */
    private Integer auditStatus;

    /**
     * 审核状态描述
     */
    private String auditStatusDesc;

    /**
     * 审核拒绝原因
     */
    private String auditReason;

    /**
     * 接单模式：1开启，0休息中
     */
    private Integer workMode;

    /**
     * 账户余额
     */
    private BigDecimal balance;

    /**
     * 综合评分
     */
    private BigDecimal rating;

    /**
     * 服务区域
     */
    private String serviceArea;

    /**
     * 注册时间
     */
    private LocalDateTime createdAt;
}
