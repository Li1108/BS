package com.nursing.dto.admin;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * 护士审核请求
 */
@Data
public class NurseAuditRequest {

    /**
     * 护士用户ID
     */
    @NotNull(message = "护士ID不能为空")
    private Long nurseId;

    /**
     * 审核结果：true通过，false拒绝
     */
    @NotNull(message = "审核结果不能为空")
    private Boolean approved;

    /**
     * 拒绝原因（拒绝时必填）
     */
    private String rejectReason;
}
