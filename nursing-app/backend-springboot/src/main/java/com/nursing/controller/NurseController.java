package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.nursing.common.Result;
import com.nursing.entity.NurseProfile;
import com.nursing.mapper.NurseProfileMapper;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 护士端控制器
 */
@Slf4j
@RestController
@RequestMapping("/nurse")
@RequiredArgsConstructor
public class NurseController {

    private final NurseProfileMapper nurseProfileMapper;

    /**
     * 护士提交资料（注册/认证申请）
     * POST /nurse/register
     */
    @PostMapping("/register")
    public Result<?> register(@RequestBody NurseRegisterRequest request) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        // 检查是否已提交过
        NurseProfile existing = nurseProfileMapper.selectOne(
                new LambdaQueryWrapper<NurseProfile>()
                        .eq(NurseProfile::getUserId, userId)
        );

        if (existing != null) {
            // 已存在记录 — 如果审核被拒绝，允许重新提交
            if (existing.getAuditStatus() != null
                    && existing.getAuditStatus() == NurseProfile.AuditStatus.REJECTED) {
                existing.setNurseName(request.getNurseName());
                existing.setIdCardNo(request.getIdCardNo());
                existing.setIdCardFrontUrl(request.getIdCardFrontUrl());
                existing.setIdCardBackUrl(request.getIdCardBackUrl());
                existing.setLicenseNo(request.getLicenseNo());
                existing.setLicenseUrl(request.getLicenseUrl());
                existing.setNursePhotoUrl(request.getNursePhotoUrl());
                existing.setHospital(request.getHospital());
                existing.setWorkYears(request.getWorkYears());
                existing.setSkillDesc(request.getSkillDesc());
                existing.setAuditStatus(NurseProfile.AuditStatus.PENDING);
                existing.setAuditRemark(null);
                existing.setUpdateTime(LocalDateTime.now());
                nurseProfileMapper.updateById(existing);
                log.info("护士重新提交资料: userId={}", userId);
                return Result.success("资料已重新提交，等待审核", existing);
            }
            return Result.badRequest("您已提交过认证资料，当前审核状态: " + existing.getAuditStatus());
        }

        // 新增
        NurseProfile profile = NurseProfile.builder()
                .userId(userId)
                .nurseName(request.getNurseName())
                .idCardNo(request.getIdCardNo())
                .idCardFrontUrl(request.getIdCardFrontUrl())
                .idCardBackUrl(request.getIdCardBackUrl())
                .licenseNo(request.getLicenseNo())
                .licenseUrl(request.getLicenseUrl())
                .nursePhotoUrl(request.getNursePhotoUrl())
                .hospital(request.getHospital())
                .workYears(request.getWorkYears())
                .skillDesc(request.getSkillDesc())
                .auditStatus(NurseProfile.AuditStatus.PENDING)
                .acceptEnabled(0)
                .rejectCountToday(0)
                .rejectDate(LocalDate.now())
                .createTime(LocalDateTime.now())
                .updateTime(LocalDateTime.now())
                .build();
        nurseProfileMapper.insert(profile);

        log.info("护士提交认证资料: userId={}, name={}", userId, request.getNurseName());
        return Result.success("认证资料已提交，等待审核", profile);
    }

    /**
     * 获取护士个人资料
     * GET /nurse/profile
     */
    @GetMapping("/profile")
    public Result<NurseProfile> getProfile() {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        NurseProfile profile = nurseProfileMapper.selectOne(
                new LambdaQueryWrapper<NurseProfile>()
                        .eq(NurseProfile::getUserId, userId)
        );

        if (profile == null) {
            return Result.notFound("尚未提交护士认证资料");
        }

        return Result.success(profile);
    }

    /**
     * 更新护士资料
     * PUT /nurse/profile
     */
    @PutMapping("/profile")
    public Result<?> updateProfile(@RequestBody NurseProfileUpdateRequest request) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        NurseProfile profile = nurseProfileMapper.selectOne(
                new LambdaQueryWrapper<NurseProfile>()
                        .eq(NurseProfile::getUserId, userId)
        );

        if (profile == null) {
            return Result.notFound("尚未提交护士认证资料");
        }

        if (StringUtils.hasText(request.getNurseName())) {
            profile.setNurseName(request.getNurseName().trim());
        }
        if (request.getWorkYears() != null) {
            profile.setWorkYears(request.getWorkYears());
        }
        if (StringUtils.hasText(request.getSkillDesc())) {
            profile.setSkillDesc(request.getSkillDesc().trim());
        }

        if (StringUtils.hasText(request.getHospital())) {
            String newHospital = request.getHospital().trim();
            String oldHospital = profile.getHospital() == null ? "" : profile.getHospital().trim();
            if (StringUtils.hasText(oldHospital) && !oldHospital.equals(newHospital)) {
                return Result.badRequest("关联医院变更需提交申请并等待管理员审核");
            }
            profile.setHospital(newHospital);
        }

        profile.setUpdateTime(LocalDateTime.now());
        nurseProfileMapper.updateById(profile);

        return Result.success("资料更新成功", profile);
    }

    /**
     * 申请关联医院变更（首次未设置时直接生效）
     * POST /nurse/hospital/change/apply
     */
    @PostMapping("/hospital/change/apply")
    public Result<?> applyHospitalChange(@RequestBody HospitalChangeApplyRequest request) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        if (!StringUtils.hasText(request.getNewHospital())) {
            return Result.badRequest("新关联医院不能为空");
        }

        NurseProfile profile = nurseProfileMapper.selectOne(
                new LambdaQueryWrapper<NurseProfile>()
                        .eq(NurseProfile::getUserId, userId)
        );
        if (profile == null) {
            return Result.notFound("尚未提交护士认证资料");
        }

        String newHospital = request.getNewHospital().trim();
        String oldHospital = profile.getHospital() == null ? "" : profile.getHospital().trim();

        // 首次未设置医院，直接写入
        if (!StringUtils.hasText(oldHospital)) {
            profile.setHospital(newHospital);
            profile.setHospitalChangeStatus(null);
            profile.setHospitalChangeRemark(null);
            profile.setPendingHospital(null);
            profile.setHospitalChangeApplyTime(null);
            profile.setHospitalChangeAuditTime(null);
            profile.setUpdateTime(LocalDateTime.now());
            nurseProfileMapper.updateById(profile);
            return Result.success("关联医院已设置", profile);
        }

        if (oldHospital.equals(newHospital)) {
            return Result.badRequest("新关联医院与当前一致，无需申请");
        }

        profile.setPendingHospital(newHospital);
        profile.setHospitalChangeStatus(NurseProfile.HospitalChangeStatus.PENDING);
        profile.setHospitalChangeRemark(StringUtils.hasText(request.getReason()) ? request.getReason().trim() : null);
        profile.setHospitalChangeApplyTime(LocalDateTime.now());
        profile.setHospitalChangeAuditTime(null);
        profile.setUpdateTime(LocalDateTime.now());
        nurseProfileMapper.updateById(profile);

        return Result.success("医院变更申请已提交，等待管理员审核");
    }

    /**
     * 切换接单开关
     * POST /nurse/acceptEnabled
     * body: { "enabled": 1 } 或 { "enabled": 0 }
     */
    @PostMapping("/acceptEnabled")
    public Result<?> toggleAcceptEnabled(@RequestBody AcceptEnabledRequest request) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        if (request.getEnabled() == null || (request.getEnabled() != 0 && request.getEnabled() != 1)) {
            return Result.badRequest("enabled 参数必须为 0 或 1");
        }

        NurseProfile profile = nurseProfileMapper.selectOne(
                new LambdaQueryWrapper<NurseProfile>()
                        .eq(NurseProfile::getUserId, userId)
        );

        if (profile == null) {
            return Result.notFound("尚未提交护士认证资料");
        }

        // 只有审核通过的护士才能开启接单
        if (request.getEnabled() == 1
                && (profile.getAuditStatus() == null
                    || profile.getAuditStatus() != NurseProfile.AuditStatus.APPROVED)) {
            return Result.badRequest("审核未通过，不能开启接单");
        }

        nurseProfileMapper.update(null,
                new LambdaUpdateWrapper<NurseProfile>()
                        .eq(NurseProfile::getUserId, userId)
                        .set(NurseProfile::getAcceptEnabled, request.getEnabled())
                        .set(NurseProfile::getUpdateTime, LocalDateTime.now())
        );

        log.info("护士切换接单状态: userId={}, enabled={}", userId, request.getEnabled());
        return Result.success();
    }

    /**
     * 获取今日拒单次数
     * GET /nurse/reject/countToday
     */
    @GetMapping("/reject/countToday")
    public Result<?> getRejectCountToday() {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        NurseProfile profile = nurseProfileMapper.selectOne(
                new LambdaQueryWrapper<NurseProfile>()
                        .eq(NurseProfile::getUserId, userId)
        );

        if (profile == null) {
            return Result.notFound("尚未提交护士认证资料");
        }

        // 如果记录的拒单日期不是今天，次数应该为 0
        int count = 0;
        if (profile.getRejectDate() != null && profile.getRejectDate().equals(LocalDate.now())) {
            count = profile.getRejectCountToday() != null ? profile.getRejectCountToday() : 0;
        }

        return Result.success(count);
    }

    // ==================== 请求体 ====================

    @Data
    public static class NurseRegisterRequest {
        private String nurseName;
        private String idCardNo;
        private String idCardFrontUrl;
        private String idCardBackUrl;
        private String licenseNo;
        private String licenseUrl;
        private String nursePhotoUrl;
        private String hospital;
        private Integer workYears;
        private String skillDesc;
    }

    @Data
    public static class AcceptEnabledRequest {
        private Integer enabled;
    }

    @Data
    public static class NurseProfileUpdateRequest {
        private String nurseName;
        private String hospital;
        private Integer workYears;
        private String skillDesc;
    }

    @Data
    public static class HospitalChangeApplyRequest {
        private String newHospital;
        private String reason;
    }
}
