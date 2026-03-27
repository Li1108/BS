package com.nursing.dto.admin;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * 系统配置更新请求
 */
@Data
public class SysConfigUpdateRequest {

    /**
     * 配置ID
     */
    @NotNull(message = "配置ID不能为空")
    private Long id;

    /**
     * 配置值
     */
    @NotBlank(message = "配置值不能为空")
    private String configValue;

    /**
     * 描述
     */
    private String description;
}
