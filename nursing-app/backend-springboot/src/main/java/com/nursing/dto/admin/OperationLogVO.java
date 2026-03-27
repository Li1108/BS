package com.nursing.dto.admin;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 操作日志VO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OperationLogVO {

    private Long id;

    /**
     * 用户ID
     */
    private Long userId;

    /**
     * 用户名
     */
    private String username;

    /**
     * 手机号
     */
    private String phone;

    /**
     * 操作类型
     */
    private String actionType;

    /**
     * 操作类型描述
     */
    private String actionTypeDesc;

    /**
     * 操作描述
     */
    private String description;

    /**
     * IP地址
     */
    private String ipAddress;

    /**
     * 创建时间
     */
    private LocalDateTime createdAt;
}
