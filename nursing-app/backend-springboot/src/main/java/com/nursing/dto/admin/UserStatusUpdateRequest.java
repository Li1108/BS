package com.nursing.dto.admin;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * 用户状态更新请求
 */
@Data
public class UserStatusUpdateRequest {

    /**
     * 用户ID
     */
    @NotNull(message = "用户ID不能为空")
    private Long userId;

    /**
     * 状态：1正常，0禁用
     */
    @NotNull(message = "状态不能为空")
    private Integer status;

    /**
     * 操作原因
     */
    private String reason;
}
