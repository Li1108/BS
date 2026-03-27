package com.nursing.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import lombok.Builder;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import java.io.Serial;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 护士资料表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("nurse_profile")
public class NurseProfile implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    /** 对应 user_account.id */
    private Long userId;

    /** 护士姓名 */
    private String nurseName;

    /** 身份证号 */
    private String idCardNo;

    /** 身份证正面 /uploads/nurse/idcard/xxx.jpg */
    private String idCardFrontUrl;

    /** 身份证反面 /uploads/nurse/idcard/xxx.jpg */
    private String idCardBackUrl;

    /** 护士执业证编号 */
    private String licenseNo;

    /** 护士证 /uploads/nurse/license/xxx.jpg */
    private String licenseUrl;

    /** 护士头像/照片 /uploads/nurse/photo/xxx.jpg */
    private String nursePhotoUrl;

    /** 所属医院/机构 */
    private String hospital;

    /** 从业年限 */
    private Integer workYears;

    /** 技能描述 */
    private String skillDesc;

    /** 审核状态 0待审 1通过 2拒绝 */
    private Integer auditStatus;

    /** 审核备注 */
    private String auditRemark;

    /** 是否开启接单 1是 0否 */
    private Integer acceptEnabled;

    /** 工作模式 0自由接单 1上班模式 */
    private Integer workMode;

    /** 综合评分 */
    private BigDecimal rating;

    /** 关联医院变更申请（待审核的新医院） */
    private String pendingHospital;

    /** 医院变更审核状态 0待审核 1已通过 2已拒绝 */
    private Integer hospitalChangeStatus;

    /** 医院变更审核备注 */
    private String hospitalChangeRemark;

    /** 医院变更申请时间 */
    private LocalDateTime hospitalChangeApplyTime;

    /** 医院变更审核时间 */
    private LocalDateTime hospitalChangeAuditTime;

    /** 今日拒单次数 */
    private Integer rejectCountToday;

    /** 拒单次数统计日期 */
    private LocalDate rejectDate;

    private LocalDateTime createTime;
    private LocalDateTime updateTime;

    /** 审核状态枚举 */
    public static class AuditStatus {
        public static final int PENDING = 0;
        public static final int APPROVED = 1;
        public static final int REJECTED = 2;
    }

    /** 医院变更审核状态枚举 */
    public static class HospitalChangeStatus {
        public static final int PENDING = 0;
        public static final int APPROVED = 1;
        public static final int REJECTED = 2;
    }
}
