package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.nursing.common.Result;
import com.nursing.entity.SysUser;
import com.nursing.entity.UserProfile;
import com.nursing.mapper.SysUserMapper;
import com.nursing.mapper.UserProfileMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 用户资料控制器
 */
@Slf4j
@RestController
@RequestMapping("/user")
@RequiredArgsConstructor
public class UserController {

    private final SysUserMapper sysUserMapper;
    private final UserProfileMapper userProfileMapper;

    /**
     * 获取用户资料（合并 user_account + user_profile）
     * GET /api/user/profile
     */
    @GetMapping("/profile")
    public Result<Map<String, Object>> getProfile() {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        SysUser user = sysUserMapper.selectById(userId);
        if (user == null) {
            return Result.notFound("用户不存在");
        }

        // 查询扩展资料
        UserProfile profile = userProfileMapper.selectOne(
                new LambdaQueryWrapper<UserProfile>().eq(UserProfile::getUserId, userId)
        );

        Map<String, Object> data = new LinkedHashMap<>();
        // user_account 字段
        data.put("id", user.getId());
        data.put("phone", user.getPhone());
        data.put("nickname", user.getNickname());
        data.put("avatarUrl", user.getAvatarUrl());
        data.put("gender", user.getGender());
        data.put("status", user.getStatus());
        data.put("createTime", user.getCreateTime());
        // user_profile 字段
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
     * 更新用户资料
     * PUT /api/user/profile
     * body: { nickname, avatarUrl, gender, realName, emergencyContact, emergencyPhone }
     */
    @PutMapping("/profile")
    public Result<Map<String, Object>> updateProfile(@RequestBody Map<String, Object> body) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        SysUser user = sysUserMapper.selectById(userId);
        if (user == null) {
            return Result.notFound("用户不存在");
        }

        // 更新 user_account 表中的字段
        boolean userChanged = false;
        if (body.containsKey("nickname") && body.get("nickname") != null) {
            user.setNickname(body.get("nickname").toString());
            userChanged = true;
        }
        if (body.containsKey("avatarUrl") && body.get("avatarUrl") != null) {
            user.setAvatarUrl(body.get("avatarUrl").toString());
            userChanged = true;
        }
        if (body.containsKey("gender") && body.get("gender") != null) {
            user.setGender(Integer.parseInt(body.get("gender").toString()));
            userChanged = true;
        }
        if (userChanged) {
            user.setUpdateTime(LocalDateTime.now());
            sysUserMapper.updateById(user);
        }

        // 更新 user_profile 表中的字段
        UserProfile profile = userProfileMapper.selectOne(
                new LambdaQueryWrapper<UserProfile>().eq(UserProfile::getUserId, userId)
        );
        boolean profileChanged = false;
        if (profile == null) {
            profile = UserProfile.builder()
                    .userId(userId)
                    .createTime(LocalDateTime.now())
                    .build();
            boolean needInsert = false;
            if (body.containsKey("realName") && body.get("realName") != null) {
                profile.setRealName(body.get("realName").toString());
                needInsert = true;
            }
            if (body.containsKey("idCardNo") && body.get("idCardNo") != null) {
                profile.setIdCardNo(body.get("idCardNo").toString());
                needInsert = true;
            }
            if (body.containsKey("emergencyContact") && body.get("emergencyContact") != null) {
                profile.setEmergencyContact(body.get("emergencyContact").toString());
                needInsert = true;
            }
            if (body.containsKey("emergencyPhone") && body.get("emergencyPhone") != null) {
                profile.setEmergencyPhone(body.get("emergencyPhone").toString());
                needInsert = true;
            }
            // 检查是否完成实名认证
            if (body.containsKey("realName") && body.get("realName") != null 
                && body.containsKey("idCardNo") && body.get("idCardNo") != null) {
                String realName = body.get("realName").toString();
                String idCardNo = body.get("idCardNo").toString();
                if (!realName.isEmpty() && !idCardNo.isEmpty()) {
                    profile.setRealNameVerified(1);
                    profile.setRealNameVerifyTime(LocalDateTime.now());
                }
            }
            if (needInsert) {
                profile.setUpdateTime(LocalDateTime.now());
                userProfileMapper.insert(profile);
            }
        } else {
            if (body.containsKey("realName") && body.get("realName") != null) {
                profile.setRealName(body.get("realName").toString());
                profileChanged = true;
            }
            if (body.containsKey("idCardNo") && body.get("idCardNo") != null) {
                profile.setIdCardNo(body.get("idCardNo").toString());
                profileChanged = true;
            }
            if (body.containsKey("emergencyContact") && body.get("emergencyContact") != null) {
                profile.setEmergencyContact(body.get("emergencyContact").toString());
                profileChanged = true;
            }
            if (body.containsKey("emergencyPhone") && body.get("emergencyPhone") != null) {
                profile.setEmergencyPhone(body.get("emergencyPhone").toString());
                profileChanged = true;
            }
            // 检查是否完成实名认证
            if (profileChanged && profile.getRealNameVerified() == 0) {
                String realName = profile.getRealName();
                String idCardNo = profile.getIdCardNo();
                if (realName != null && !realName.isEmpty() 
                    && idCardNo != null && !idCardNo.isEmpty()) {
                    profile.setRealNameVerified(1);
                    profile.setRealNameVerifyTime(LocalDateTime.now());
                }
            }
            if (profileChanged) {
                profile.setUpdateTime(LocalDateTime.now());
                userProfileMapper.updateById(profile);
            }
        }

        log.info("用户{}更新资料", userId);
        // 返回最新的合并数据
        return getProfile();
    }

    /**
     * 实名认证接口
     * POST /api/user/real-name-verify
     * body: { realName, idCardNo }
     */
    @PostMapping("/real-name-verify")
    public Result<Map<String, Object>> verifyRealName(@RequestBody Map<String, Object> body) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        if (!body.containsKey("realName") || body.get("realName") == null 
            || !body.containsKey("idCardNo") || body.get("idCardNo") == null) {
            return Result.badRequest("请提供真实姓名和身份证号");
        }

        String realName = body.get("realName").toString().trim();
        String idCardNo = body.get("idCardNo").toString().trim();

        if (realName.isEmpty()) {
            return Result.badRequest("真实姓名不能为空");
        }
        if (idCardNo.isEmpty()) {
            return Result.badRequest("身份证号不能为空");
        }

        // 简单的身份证号格式验证
        if (!isValidIdCardNo(idCardNo)) {
            return Result.badRequest("身份证号格式不正确");
        }

        // 查询用户资料
        UserProfile profile = userProfileMapper.selectOne(
                new LambdaQueryWrapper<UserProfile>().eq(UserProfile::getUserId, userId)
        );

        if (profile == null) {
            profile = UserProfile.builder()
                    .userId(userId)
                    .realName(realName)
                    .idCardNo(idCardNo)
                    .realNameVerified(1)
                    .realNameVerifyTime(LocalDateTime.now())
                    .createTime(LocalDateTime.now())
                    .updateTime(LocalDateTime.now())
                    .build();
            userProfileMapper.insert(profile);
        } else {
            profile.setRealName(realName);
            profile.setIdCardNo(idCardNo);
            profile.setRealNameVerified(1);
            profile.setRealNameVerifyTime(LocalDateTime.now());
            profile.setUpdateTime(LocalDateTime.now());
            userProfileMapper.updateById(profile);
        }

        log.info("用户{}完成实名认证: realName={}", userId, realName);
        return Result.success("实名认证成功", getProfile().getData());
    }

    /**
     * 检查实名认证状态
     * GET /api/user/real-name-status
     */
    @GetMapping("/real-name-status")
    public Result<Map<String, Object>> getRealNameStatus() {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        UserProfile profile = userProfileMapper.selectOne(
                new LambdaQueryWrapper<UserProfile>().eq(UserProfile::getUserId, userId)
        );

        Map<String, Object> data = new LinkedHashMap<>();
        if (profile != null && profile.getRealNameVerified() != null && profile.getRealNameVerified() == 1) {
            data.put("verified", true);
            data.put("realName", profile.getRealName());
            data.put("idCardNo", maskIdCardNo(profile.getIdCardNo()));
            data.put("verifyTime", profile.getRealNameVerifyTime());
        } else {
            data.put("verified", false);
        }

        return Result.success(data);
    }

    /**
     * 验证身份证号格式
     */
    private boolean isValidIdCardNo(String idCardNo) {
        // 简单的身份证号格式验证
        // 15位或18位数字，最后一位可以是X
        String pattern = "^[1-9]\\d{5}(18|19|20)\\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01])\\d{3}[0-9Xx]$|^[1-9]\\d{7}(0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01])\\d{3}$";
        return idCardNo.matches(pattern);
    }

    /**
     * 脱敏显示身份证号
     */
    private String maskIdCardNo(String idCardNo) {
        if (idCardNo == null || idCardNo.length() < 8) {
            return idCardNo;
        }
        // 保留前4位和后4位，中间用*代替
        int length = idCardNo.length();
        String prefix = idCardNo.substring(0, 4);
        String suffix = idCardNo.substring(length - 4);
        String middle = "*".repeat(length - 8);
        return prefix + middle + suffix;
    }
}
