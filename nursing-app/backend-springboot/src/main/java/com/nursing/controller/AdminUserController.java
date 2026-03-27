package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.OperationLog;
import com.nursing.entity.SysUser;
import com.nursing.entity.UserProfile;
import com.nursing.mapper.OperationLogMapper;
import com.nursing.mapper.SysUserMapper;
import com.nursing.mapper.UserProfileMapper;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 管理员 - 用户管理
 */
@Slf4j
@RestController
@RequestMapping("/admin/user")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminUserController {

    private final SysUserMapper sysUserMapper;
    private final OperationLogMapper operationLogMapper;
    private final UserProfileMapper userProfileMapper;

    /**
     * 用户列表（分页 + 关键词 + 状态筛选）
     */
    @GetMapping("/list")
    public Result<?> list(@RequestParam(required = false) String keyword,
                          @RequestParam(required = false) Integer status,
                          @RequestParam(defaultValue = "1") Integer pageNo,
                          @RequestParam(defaultValue = "10") Integer pageSize) {
        Page<SysUser> page = new Page<>(pageNo, pageSize);
        LambdaQueryWrapper<SysUser> wrapper = new LambdaQueryWrapper<>();

        if (StringUtils.hasText(keyword)) {
            wrapper.and(w -> w.like(SysUser::getPhone, keyword)
                    .or().like(SysUser::getNickname, keyword));
        }
        if (status != null) {
            wrapper.eq(SysUser::getStatus, status);
        }
        wrapper.orderByDesc(SysUser::getCreateTime);

        return Result.success(sysUserMapper.selectPage(page, wrapper));
    }

    /**
     * 获取用户详情
     */
    @GetMapping("/{userId}")
    public Result<?> getUserDetail(@PathVariable Long userId) {
        SysUser user = sysUserMapper.selectById(userId);
        if (user == null) {
            return Result.notFound("用户不存在");
        }

        UserProfile profile = userProfileMapper.selectOne(
                new LambdaQueryWrapper<UserProfile>().eq(UserProfile::getUserId, userId)
        );

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("id", user.getId());
        data.put("phone", user.getPhone());
        data.put("nickname", user.getNickname());
        data.put("avatarUrl", user.getAvatarUrl());
        data.put("gender", user.getGender());
        data.put("status", user.getStatus());
        data.put("createTime", user.getCreateTime());
        data.put("lastLoginTime", user.getLastLoginTime());

        if (profile != null) {
            data.put("realName", profile.getRealName());
            data.put("idCardNo", profile.getIdCardNo());
            data.put("birthday", profile.getBirthday());
            data.put("emergencyContact", profile.getEmergencyContact());
            data.put("emergencyPhone", profile.getEmergencyPhone());
            data.put("realNameVerified", profile.getRealNameVerified());
            data.put("realNameVerifyTime", profile.getRealNameVerifyTime());
        } else {
            data.put("realName", null);
            data.put("idCardNo", null);
            data.put("birthday", null);
            data.put("emergencyContact", null);
            data.put("emergencyPhone", null);
            data.put("realNameVerified", 0);
            data.put("realNameVerifyTime", null);
        }

        return Result.success(data);
    }

    /**
     * 禁用用户
     */
    @PostMapping("/disable/{userId}")
    public Result<?> disable(@PathVariable Long userId, HttpServletRequest request) {
        SysUser user = sysUserMapper.selectById(userId);
        if (user == null) {
            return Result.notFound("用户不存在");
        }
        user.setStatus(SysUser.StatusEnum.DISABLED);
        user.setUpdateTime(LocalDateTime.now());
        sysUserMapper.updateById(user);

        // 写操作日志
        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("DISABLE_USER")
                .actionDesc("禁用用户，userId=" + userId)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("userId=" + userId)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]禁用用户[{}]", adminUserId, userId);
        return Result.success("用户已禁用");
    }

    /**
     * 启用用户
     */
    @PostMapping("/enable/{userId}")
    public Result<?> enable(@PathVariable Long userId, HttpServletRequest request) {
        SysUser user = sysUserMapper.selectById(userId);
        if (user == null) {
            return Result.notFound("用户不存在");
        }
        user.setStatus(SysUser.StatusEnum.NORMAL);
        user.setUpdateTime(LocalDateTime.now());
        sysUserMapper.updateById(user);

        // 写操作日志
        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("ENABLE_USER")
                .actionDesc("启用用户，userId=" + userId)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("userId=" + userId)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]启用用户[{}]", adminUserId, userId);
        return Result.success("用户已启用");
    }
}
