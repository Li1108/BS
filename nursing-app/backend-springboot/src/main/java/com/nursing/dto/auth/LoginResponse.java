package com.nursing.dto.auth;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 登录响应
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LoginResponse {

    /**
     * 用户ID
     */
    private Long userId;

    /**
     * 用户名/昵称
     */
    private String username;

    /**
     * 手机号
     */
    private String phone;

    /**
     * 头像URL
     */
    private String avatar;

    /**
     * 角色
     */
    private String role;

    /**
     * JWT Token
     */
    private String token;

    /**
     * Token过期时间（毫秒时间戳）
     */
    private Long expiresAt;

    /**
     * 护士审核状态（仅护士角色返回）
     * 0待审，1通过，2拒绝
     */
    private Integer auditStatus;
}
