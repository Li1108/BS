package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.nursing.common.Result;
import com.nursing.dto.auth.LoginRequest;
import com.nursing.dto.auth.SendCodeRequest;
import com.nursing.entity.SmsCode;
import com.nursing.entity.SysUser;
import com.nursing.entity.TokenBlacklist;
import com.nursing.entity.UserProfile;
import com.nursing.mapper.SmsCodeMapper;
import com.nursing.mapper.SysUserMapper;
import com.nursing.mapper.TokenBlacklistMapper;
import com.nursing.mapper.UserProfileMapper;
import com.nursing.service.AuthService;
import com.nursing.utils.JwtUtils;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 认证控制器
 * 处理验证码发送、登录（自动注册）、退出、获取当前用户
 */
@Slf4j
@RestController
@RequestMapping("/auth")
@RequiredArgsConstructor
@Tag(name = "认证模块", description = "登录、验证码、退出相关接口")
public class AuthController {

    private final AuthService authService;
    private final JwtUtils jwtUtils;
    private final SysUserMapper sysUserMapper;
    private final SmsCodeMapper smsCodeMapper;
    private final TokenBlacklistMapper tokenBlacklistMapper;
    private final UserProfileMapper userProfileMapper;

    /**
     * 发送验证码
     * POST /api/auth/sendCode
     */
    @PostMapping("/sendCode")
    @Operation(summary = "发送验证码", description = "发送手机验证码，用于登录或注册")
    public Result<Void> sendCode(@Valid @RequestBody SendCodeRequest request) {
        boolean success = authService.sendVerificationCode(request.getPhone());
        if (success) {
            return Result.success("验证码发送成功", null);
        }
        return Result.error("验证码发送失败，请稍后重试");
    }

    /**
     * 验证码登录（自动注册新用户）
     * POST /api/auth/login
     * 请求: { phone, code, role }
     * 响应: { code:0, message:"success", data:{ token, userId, role } }
     */
    @PostMapping("/login")
    @Operation(summary = "验证码登录", description = "使用手机号+验证码+角色登录，新用户自动注册")
    public Result<Map<String, Object>> login(@Valid @RequestBody LoginRequest request) {
        // 1. 验证短信验证码
        QueryWrapper<SmsCode> qw = new QueryWrapper<>();
        qw.eq("phone", request.getPhone())
          .eq("code", request.getCode())
          .eq("used_flag", 0)
          .gt("expire_time", LocalDateTime.now())
          .orderByDesc("create_time")
          .last("LIMIT 1");
        SmsCode smsCode = smsCodeMapper.selectOne(qw);
        if (smsCode == null) {
            return Result.badRequest("验证码无效或已过期");
        }
        // 标记验证码已使用
        smsCode.setUsedFlag(1);
        smsCodeMapper.updateById(smsCode);

        // 2. 查找用户，不存在则自动注册
        SysUser user = sysUserMapper.findByPhone(request.getPhone());
        if (user == null) {
            String phoneSuffix = request.getPhone().length() >= 4
                    ? request.getPhone().substring(request.getPhone().length() - 4)
                    : request.getPhone();
            user = SysUser.builder()
                    .phone(request.getPhone())
                    .nickname("用户" + phoneSuffix)
                    .status(SysUser.StatusEnum.NORMAL)
                    .createTime(LocalDateTime.now())
                    .updateTime(LocalDateTime.now())
                    .build();
            sysUserMapper.insert(user);
            log.info("新用户自动注册: phone={}, userId={}", request.getPhone(), user.getId());
        }

        // 3. 确定登录角色（按登录入口区分）
        String requestedRole = request.getRole() == null ? "USER" : request.getRole().trim().toUpperCase();
        String role;
        if ("NURSE".equals(requestedRole)) {
            int nurseRoleCount = sysUserMapper.countUserRole(user.getId(), "NURSE");
            if (nurseRoleCount <= 0) {
                return Result.forbidden("护士资质审核通过后方可登录护士端");
            }
            role = "NURSE";
        } else {
            String actualRole = sysUserMapper.findRoleCodeByUserId(user.getId());
            // 管理员入口由 /admin/auth/login 处理；普通入口默认 USER
            role = "ADMIN_SUPER".equalsIgnoreCase(actualRole) ? "ADMIN_SUPER" : "USER";
        }

        // 4. 检查账号状态
        if (user.getStatus() != null && user.getStatus() == SysUser.StatusEnum.DISABLED) {
            return Result.forbidden("账号已被禁用");
        }

        // 5. 更新最后登录时间（用于多端会话失效判定）
        user.setLastLoginTime(LocalDateTime.now());
        sysUserMapper.updateById(user);

        // 6. 生成JWT token
        String token = jwtUtils.generateToken(user.getId(), user.getPhone(), role);

        // 7. 检查实名认证状态
        boolean realNameVerified = false;
        UserProfile profile = userProfileMapper.selectOne(
                new LambdaQueryWrapper<UserProfile>().eq(UserProfile::getUserId, user.getId())
        );
        if (profile != null && profile.getRealNameVerified() != null && profile.getRealNameVerified() == 1) {
            realNameVerified = true;
        }

        // 8. 构造返回数据
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("token", token);
        data.put("userId", user.getId());
        data.put("role", role);
        data.put("realNameVerified", realNameVerified);
        return Result.success(data);
    }

    /**
     * 让其他设备下线（当前设备保持登录，返回新token）
     * POST /api/auth/logout/others
     */
    @PostMapping("/logout/others")
    @Operation(summary = "退出其他设备", description = "让当前账号在其他设备的登录态失效，并为当前设备签发新Token")
    public Result<Map<String, Object>> logoutOtherDevices(HttpServletRequest request) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        SysUser user = sysUserMapper.selectById(userId);
        if (user == null) {
            return Result.notFound("用户不存在");
        }

        String role = getCurrentRoleCode();
        if (role == null || role.isBlank()) {
            role = sysUserMapper.findRoleCodeByUserId(userId);
        }
        if (role == null || role.isBlank()) {
            role = "USER";
        }

        LocalDateTime now = LocalDateTime.now();
        user.setLastLoginTime(now);
        user.setUpdateTime(now);
        sysUserMapper.updateById(user);

        String authHeader = request.getHeader("Authorization");
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String oldToken = authHeader.substring(7);
            try {
                Date expiration = jwtUtils.getExpirationFromToken(oldToken);
                LocalDateTime expireTime = (expiration != null)
                        ? LocalDateTime.ofInstant(expiration.toInstant(), ZoneId.systemDefault())
                        : now.plusDays(1);

                TokenBlacklist blacklist = TokenBlacklist.builder()
                        .userId(userId)
                        .token(oldToken)
                        .expireTime(expireTime)
                        .createTime(now)
                        .build();
                tokenBlacklistMapper.insert(blacklist);
            } catch (Exception e) {
                log.warn("退出其他设备时处理旧token异常: {}", e.getMessage());
            }
        }

        String newToken = jwtUtils.generateToken(userId, user.getPhone(), role);

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("token", newToken);
        data.put("userId", userId);
        data.put("role", role);
        return Result.success("已退出其他设备", data);
    }

    /**
     * 退出登录（将token加入黑名单）
     * POST /api/auth/logout
     */
    @PostMapping("/logout")
    @Operation(summary = "退出登录", description = "退出登录，将当前Token加入黑名单")
    public Result<Void> logout(HttpServletRequest request) {
        String authHeader = request.getHeader("Authorization");
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            try {
                Long userId = jwtUtils.getUserIdFromToken(token);
                Date expiration = jwtUtils.getExpirationFromToken(token);

                LocalDateTime expireTime = (expiration != null)
                        ? LocalDateTime.ofInstant(expiration.toInstant(), ZoneId.systemDefault())
                        : LocalDateTime.now().plusDays(1);

                TokenBlacklist blacklist = TokenBlacklist.builder()
                        .userId(userId)
                        .token(token)
                        .expireTime(expireTime)
                        .createTime(LocalDateTime.now())
                        .build();
                tokenBlacklistMapper.insert(blacklist);
                log.info("用户退出登录，token已加入黑名单: userId={}", userId);
            } catch (Exception e) {
                log.warn("退出登录处理token异常: {}", e.getMessage());
            }
        }
        return Result.success();
    }

    /**
     * 获取当前登录用户信息
     * GET /api/auth/me
     */
    @GetMapping("/me")
    @Operation(summary = "获取当前用户信息", description = "根据Token获取当前登录用户信息")
    public Result<Map<String, Object>> getCurrentUser() {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        SysUser user = sysUserMapper.selectById(userId);
        if (user == null) {
            return Result.notFound("用户不存在");
        }
        if (user.getStatus() != null && user.getStatus() == SysUser.StatusEnum.DISABLED) {
            return Result.forbidden("账号已禁用");
        }

        String roleCode = getCurrentRoleCode();
        if (roleCode == null || roleCode.isBlank()) {
            roleCode = sysUserMapper.findRoleCodeByUserId(userId);
        }
        if (roleCode == null || roleCode.isBlank()) {
            roleCode = "USER";
        }

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("userId", user.getId());
        data.put("phone", user.getPhone());
        data.put("nickname", user.getNickname());
        data.put("avatarUrl", user.getAvatarUrl());
        data.put("gender", user.getGender());
        data.put("status", user.getStatus());
        data.put("role", roleCode);
        data.put("createTime", user.getCreateTime());
        return Result.success(data);
    }

    /**
     * 从 SecurityContextHolder 获取当前用户ID
     */
    private Long getCurrentUserId() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof Long) {
            return (Long) auth.getPrincipal();
        }
        return null;
    }

    /**
     * 获取当前 token 对应角色（优先使用 SecurityContext 中的权限）
     */
    private String getCurrentRoleCode() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getAuthorities() == null) {
            return null;
        }
        for (GrantedAuthority authority : auth.getAuthorities()) {
            if (authority == null) continue;
            String role = authority.getAuthority();
            if (role == null || role.isBlank()) continue;
            if (role.startsWith("ROLE_")) {
                return role.substring(5);
            }
            return role;
        }
        return null;
    }
}
