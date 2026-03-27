package com.nursing.controller;

import com.nursing.common.Result;
import com.nursing.dto.auth.PasswordLoginRequest;
import com.nursing.entity.SysUser;
import com.nursing.mapper.SysUserMapper;
import com.nursing.utils.JwtUtils;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 管理员认证控制器（账号密码登录）
 */
@Slf4j
@RestController
@RequestMapping("/admin/auth")
@RequiredArgsConstructor
@Tag(name = "管理员认证模块", description = "管理员账号密码登录")
public class AdminAuthController {

    private final SysUserMapper sysUserMapper;
    private final JwtUtils jwtUtils;
    private final PasswordEncoder passwordEncoder;

    /**
     * 管理员账号密码登录
     * POST /api/admin/auth/login
     */
    @PostMapping("/login")
    @Operation(summary = "管理员登录", description = "使用手机号+密码登录管理后台，仅 ADMIN_SUPER 可登录")
    public Result<Map<String, Object>> login(@Valid @RequestBody PasswordLoginRequest request) {
        SysUser user = sysUserMapper.findByPhone(request.getPhone());
        if (user == null) {
            return Result.badRequest("账号或密码错误");
        }
        if (user.getStatus() != null && user.getStatus() == SysUser.StatusEnum.DISABLED) {
            return Result.forbidden("账号已被禁用");
        }

        String roleCode = sysUserMapper.findRoleCodeByUserId(user.getId());
        if (!"ADMIN_SUPER".equals(roleCode)) {
            return Result.forbidden("仅超级管理员可登录后台");
        }

        if (!StringUtils.hasText(user.getPassword())) {
            return Result.badRequest("管理员未设置密码，请先初始化密码");
        }
        boolean passwordMatched;
        if (user.getPassword().startsWith("$2a$") || user.getPassword().startsWith("$2b$")) {
            passwordMatched = passwordEncoder.matches(request.getPassword(), user.getPassword());
        } else {
            passwordMatched = request.getPassword().equals(user.getPassword());
        }
        if (!passwordMatched) {
            return Result.badRequest("账号或密码错误");
        }

        user.setLastLoginTime(LocalDateTime.now());
        user.setUpdateTime(LocalDateTime.now());
        sysUserMapper.updateById(user);
        String token = jwtUtils.generateToken(user.getId(), user.getPhone(), roleCode);

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("token", token);
        data.put("userId", user.getId());
        data.put("role", roleCode);
        data.put("phone", user.getPhone());
        data.put("nickname", user.getNickname());
        log.info("管理员登录成功: userId={}, phone={}", user.getId(), user.getPhone());
        return Result.success(data);
    }
}
