package com.nursing.dto.auth;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

/**
 * 用户注册请求（手机号+验证码）
 */
@Data
public class RegisterRequest {

    @NotBlank(message = "手机号不能为空")
    @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
    private String phone;

    @NotBlank(message = "验证码不能为空")
    @Pattern(regexp = "^\\d{6}$", message = "验证码格式不正确")
    private String code;

    /**
     * 昵称/姓名
     */
    private String username;

    /**
     * 角色：USER / NURSE / ADMIN（默认 USER）
     */
    private String role;
}

