package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.NurseLocation;
import com.nursing.entity.NurseProfile;
import com.nursing.entity.NurseRejectLog;
import com.nursing.entity.Notification;
import com.nursing.entity.OperationLog;
import com.nursing.entity.Role;
import com.nursing.entity.SysConfig;
import com.nursing.entity.UserRole;
import com.nursing.mapper.NurseLocationMapper;
import com.nursing.mapper.NurseRejectLogMapper;
import com.nursing.mapper.NotificationMapper;
import com.nursing.mapper.NurseProfileMapper;
import com.nursing.mapper.OperationLogMapper;
import com.nursing.mapper.RoleMapper;
import com.nursing.mapper.SysConfigMapper;
import com.nursing.mapper.UserRoleMapper;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 管理员 - 护士管理
 */
@Slf4j
@RestController
@RequestMapping("/admin/nurse")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminNurseController {

    private final NurseProfileMapper nurseProfileMapper;
    private final NurseLocationMapper nurseLocationMapper;
    private final NotificationMapper notificationMapper;
    private final OperationLogMapper operationLogMapper;
    private final RoleMapper roleMapper;
    private final UserRoleMapper userRoleMapper;
    private final NurseRejectLogMapper nurseRejectLogMapper;
    private final SysConfigMapper sysConfigMapper;

    /**
     * 护士列表（分页 + 审核状态 + 关键词 + 接单状态）
     */
    @GetMapping("/list")
    public Result<?> list(@RequestParam(required = false) Integer auditStatus,
                          @RequestParam(required = false) String keyword,
                          @RequestParam(required = false) Integer acceptEnabled,
                          @RequestParam(required = false) Integer hospitalChangeStatus,
                          @RequestParam(defaultValue = "1") Integer pageNo,
                          @RequestParam(defaultValue = "10") Integer pageSize) {
        Page<NurseProfile> page = new Page<>(pageNo, pageSize);
        LambdaQueryWrapper<NurseProfile> wrapper = new LambdaQueryWrapper<>();

        if (auditStatus != null) {
            wrapper.eq(NurseProfile::getAuditStatus, auditStatus);
        }
        if (StringUtils.hasText(keyword)) {
            wrapper.and(w -> w.like(NurseProfile::getNurseName, keyword)
                    .or().like(NurseProfile::getIdCardNo, keyword)
                    .or().like(NurseProfile::getLicenseNo, keyword));
        }
        if (acceptEnabled != null) {
            wrapper.eq(NurseProfile::getAcceptEnabled, acceptEnabled);
        }
        if (hospitalChangeStatus != null) {
            wrapper.eq(NurseProfile::getHospitalChangeStatus, hospitalChangeStatus);
        }
        wrapper.orderByDesc(NurseProfile::getCreateTime);

        return Result.success(nurseProfileMapper.selectPage(page, wrapper));
    }

    /**
     * 护士详情
     */
    @GetMapping("/detail/{nurseUserId}")
    public Result<?> detail(@PathVariable Long nurseUserId) {
        LambdaQueryWrapper<NurseProfile> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(NurseProfile::getUserId, nurseUserId);
        NurseProfile profile = nurseProfileMapper.selectOne(wrapper);
        if (profile == null) {
            return Result.notFound("护士资料不存在");
        }
        return Result.success(profile);
    }

    /**
     * 审核通过
     */
    @PostMapping("/auditPass/{nurseUserId}")
    public Result<?> auditPass(@PathVariable Long nurseUserId, HttpServletRequest request) {
        LambdaQueryWrapper<NurseProfile> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(NurseProfile::getUserId, nurseUserId);
        NurseProfile profile = nurseProfileMapper.selectOne(wrapper);
        if (profile == null) {
            return Result.notFound("护士资料不存在");
        }
        if (profile.getAuditStatus() != NurseProfile.AuditStatus.PENDING) {
            return Result.badRequest("当前状态不允许审核");
        }

        profile.setAuditStatus(NurseProfile.AuditStatus.APPROVED);
        profile.setUpdateTime(LocalDateTime.now());
        nurseProfileMapper.updateById(profile);

        ensureNurseRoleBound(nurseUserId);

        notificationMapper.insert(Notification.builder()
            .receiverUserId(nurseUserId)
            .receiverRole("USER")
            .title("护士入驻审核通过")
            .content("您的护士入驻申请已审核通过，请在登录页切换到护士登录入口进行登录。")
            .bizType("AUDIT")
            .bizId(String.valueOf(nurseUserId))
            .readFlag(0)
            .createTime(LocalDateTime.now())
            .build());

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("AUDIT_NURSE_PASS")
                .actionDesc("审核通过护士，nurseUserId=" + nurseUserId)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("nurseUserId=" + nurseUserId)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]审核通过护士[{}]", adminUserId, nurseUserId);
        return Result.success("审核通过");
    }

    /**
     * 医院变更申请通过
     */
    @PostMapping("/hospitalChange/approve/{nurseUserId}")
    public Result<?> approveHospitalChange(@PathVariable Long nurseUserId, HttpServletRequest request) {
        NurseProfile profile = nurseProfileMapper.selectOne(
                new LambdaQueryWrapper<NurseProfile>().eq(NurseProfile::getUserId, nurseUserId)
        );
        if (profile == null) {
            return Result.notFound("护士资料不存在");
        }
        if (profile.getHospitalChangeStatus() == null
                || profile.getHospitalChangeStatus() != NurseProfile.HospitalChangeStatus.PENDING
                || !StringUtils.hasText(profile.getPendingHospital())) {
            return Result.badRequest("当前不存在待审核的医院变更申请");
        }

        String newHospital = profile.getPendingHospital();
        profile.setHospital(newHospital);
        profile.setHospitalChangeStatus(NurseProfile.HospitalChangeStatus.APPROVED);
        profile.setHospitalChangeRemark("审核通过");
        profile.setHospitalChangeAuditTime(LocalDateTime.now());
        profile.setPendingHospital(null);
        profile.setUpdateTime(LocalDateTime.now());
        nurseProfileMapper.updateById(profile);

        notificationMapper.insert(Notification.builder()
                .receiverUserId(nurseUserId)
                .receiverRole("USER")
                .title("关联医院变更审核通过")
                .content("您的关联医院变更申请已通过，当前关联医院：" + newHospital)
                .bizType("AUDIT")
                .bizId(String.valueOf(nurseUserId))
                .readFlag(0)
                .createTime(LocalDateTime.now())
                .build());

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("APPROVE_HOSPITAL_CHANGE")
                .actionDesc("通过护士医院变更，nurseUserId=" + nurseUserId + "，newHospital=" + newHospital)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("nurseUserId=" + nurseUserId)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        return Result.success("医院变更已通过");
    }

    /**
     * 医院变更申请拒绝
     */
    @PostMapping("/hospitalChange/reject/{nurseUserId}")
    public Result<?> rejectHospitalChange(@PathVariable Long nurseUserId,
                                          @RequestBody(required = false) Map<String, String> body,
                                          HttpServletRequest request) {
        String remark = body == null ? null : body.get("remark");
        NurseProfile profile = nurseProfileMapper.selectOne(
                new LambdaQueryWrapper<NurseProfile>().eq(NurseProfile::getUserId, nurseUserId)
        );
        if (profile == null) {
            return Result.notFound("护士资料不存在");
        }
        if (profile.getHospitalChangeStatus() == null
                || profile.getHospitalChangeStatus() != NurseProfile.HospitalChangeStatus.PENDING
                || !StringUtils.hasText(profile.getPendingHospital())) {
            return Result.badRequest("当前不存在待审核的医院变更申请");
        }

        String pendingHospital = profile.getPendingHospital();
        profile.setHospitalChangeStatus(NurseProfile.HospitalChangeStatus.REJECTED);
        profile.setHospitalChangeRemark(StringUtils.hasText(remark) ? remark : "申请资料不完整或不符合要求");
        profile.setHospitalChangeAuditTime(LocalDateTime.now());
        profile.setPendingHospital(null);
        profile.setUpdateTime(LocalDateTime.now());
        nurseProfileMapper.updateById(profile);

        notificationMapper.insert(Notification.builder()
                .receiverUserId(nurseUserId)
                .receiverRole("USER")
                .title("关联医院变更审核未通过")
                .content("您的关联医院变更申请（" + pendingHospital + "）未通过，原因：" + (StringUtils.hasText(remark) ? remark : "申请资料不完整或不符合要求"))
                .bizType("AUDIT")
                .bizId(String.valueOf(nurseUserId))
                .readFlag(0)
                .createTime(LocalDateTime.now())
                .build());

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("REJECT_HOSPITAL_CHANGE")
                .actionDesc("拒绝护士医院变更，nurseUserId=" + nurseUserId + "，pendingHospital=" + pendingHospital)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("nurseUserId=" + nurseUserId + ", remark=" + remark)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        return Result.success("医院变更已拒绝");
    }

    /**
     * 审核拒绝
     */
    @PostMapping("/auditReject/{nurseUserId}")
    public Result<?> auditReject(@PathVariable Long nurseUserId,
                                 @RequestBody Map<String, String> body,
                                 HttpServletRequest request) {
        String remark = body.get("remark");

        LambdaQueryWrapper<NurseProfile> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(NurseProfile::getUserId, nurseUserId);
        NurseProfile profile = nurseProfileMapper.selectOne(wrapper);
        if (profile == null) {
            return Result.notFound("护士资料不存在");
        }
        if (profile.getAuditStatus() != NurseProfile.AuditStatus.PENDING) {
            return Result.badRequest("当前状态不允许审核");
        }

        profile.setAuditStatus(NurseProfile.AuditStatus.REJECTED);
        profile.setAuditRemark(remark);
        profile.setUpdateTime(LocalDateTime.now());
        nurseProfileMapper.updateById(profile);

        notificationMapper.insert(Notification.builder()
            .receiverUserId(nurseUserId)
            .receiverRole("USER")
            .title("护士入驻审核未通过")
            .content("您的护士入驻申请未通过，原因：" + (StringUtils.hasText(remark) ? remark : "资料不完整或不符合要求") + "。请在“我的-申请成为护士”中修改后重新提交。")
            .bizType("AUDIT")
            .bizId(String.valueOf(nurseUserId))
            .readFlag(0)
            .createTime(LocalDateTime.now())
            .build());

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("AUDIT_NURSE_REJECT")
                .actionDesc("审核拒绝护士，nurseUserId=" + nurseUserId + "，原因：" + remark)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("nurseUserId=" + nurseUserId + ", remark=" + remark)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]审核拒绝护士[{}]，原因：{}", adminUserId, nurseUserId, remark);
        return Result.success("审核已拒绝");
    }

    /**
     * 禁止接单
     */
    @PostMapping("/disableAccept/{nurseUserId}")
    public Result<?> disableAccept(@PathVariable Long nurseUserId, HttpServletRequest request) {
        LambdaQueryWrapper<NurseProfile> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(NurseProfile::getUserId, nurseUserId);
        NurseProfile profile = nurseProfileMapper.selectOne(wrapper);
        if (profile == null) {
            return Result.notFound("护士资料不存在");
        }

        profile.setAcceptEnabled(0);
        profile.setUpdateTime(LocalDateTime.now());
        nurseProfileMapper.updateById(profile);

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("DISABLE_NURSE_ACCEPT")
                .actionDesc("禁止护士接单，nurseUserId=" + nurseUserId)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("nurseUserId=" + nurseUserId)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]禁止护士[{}]接单", adminUserId, nurseUserId);
        return Result.success("已禁止接单");
    }

    /**
     * 启用接单
     */
    @PostMapping("/enableAccept/{nurseUserId}")
    public Result<?> enableAccept(@PathVariable Long nurseUserId, HttpServletRequest request) {
        LambdaQueryWrapper<NurseProfile> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(NurseProfile::getUserId, nurseUserId);
        NurseProfile profile = nurseProfileMapper.selectOne(wrapper);
        if (profile == null) {
            return Result.notFound("护士资料不存在");
        }

        profile.setAcceptEnabled(1);
        profile.setUpdateTime(LocalDateTime.now());
        nurseProfileMapper.updateById(profile);

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("ENABLE_NURSE_ACCEPT")
                .actionDesc("启用护士接单，nurseUserId=" + nurseUserId)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("nurseUserId=" + nurseUserId)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]启用护士[{}]接单", adminUserId, nurseUserId);
        return Result.success("已启用接单");
    }

    /**
     * 护士最新位置
     */
    @GetMapping("/location/latest/{nurseUserId}")
    public Result<?> latestLocation(@PathVariable Long nurseUserId) {
        LambdaQueryWrapper<NurseLocation> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(NurseLocation::getNurseUserId, nurseUserId)
                .orderByDesc(NurseLocation::getReportTime)
                .last("LIMIT 1");
        NurseLocation location = nurseLocationMapper.selectOne(wrapper);
        if (location == null) {
            return Result.notFound("暂无位置信息");
        }
        return Result.success(location);
    }

    /**
     * 护士拒单统计
     */
    @GetMapping("/reject/stat/{nurseUserId}")
    public Result<?> rejectStat(@PathVariable Long nurseUserId) {
        LambdaQueryWrapper<NurseProfile> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(NurseProfile::getUserId, nurseUserId);
        NurseProfile profile = nurseProfileMapper.selectOne(wrapper);
        if (profile == null) {
            return Result.notFound("护士资料不存在");
        }

        // 如果统计日期不是今天，则今日拒单次数为0
        int todayRejectCount = 0;
        if (profile.getRejectDate() != null && profile.getRejectDate().equals(LocalDate.now())) {
            todayRejectCount = profile.getRejectCountToday() != null ? profile.getRejectCountToday() : 0;
        }

        return Result.success(Map.of(
                "nurseUserId", nurseUserId,
                "rejectCountToday", todayRejectCount,
                "rejectDate", profile.getRejectDate() != null ? profile.getRejectDate().toString() : ""
        ));
    }

    /**
     * 护士工作模式切换
     */
    @PostMapping("/workMode/{nurseUserId}")
    public Result<?> updateWorkMode(@PathVariable Long nurseUserId,
                                    @RequestBody Map<String, Integer> body,
                                    HttpServletRequest request) {
        Integer workMode = body == null ? null : body.get("workMode");
        if (workMode == null || (workMode != 0 && workMode != 1)) {
            return Result.badRequest("workMode 必须为 0 或 1");
        }

        NurseProfile profile = nurseProfileMapper.selectOne(
                new LambdaQueryWrapper<NurseProfile>().eq(NurseProfile::getUserId, nurseUserId)
        );
        if (profile == null) {
            return Result.notFound("护士资料不存在");
        }

        profile.setWorkMode(workMode);
        profile.setUpdateTime(LocalDateTime.now());
        nurseProfileMapper.updateById(profile);

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("UPDATE_NURSE_WORK_MODE")
                .actionDesc("更新护士工作模式，nurseUserId=" + nurseUserId + "，workMode=" + workMode)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("nurseUserId=" + nurseUserId + ", workMode=" + workMode)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        return Result.success(profile);
    }

    /**
     * 护士拒单记录
     */
    @GetMapping("/reject/log/list")
    public Result<?> rejectLogList(@RequestParam(required = false) Long nurseUserId,
                                   @RequestParam(required = false) String startDate,
                                   @RequestParam(required = false) String endDate,
                                   @RequestParam(defaultValue = "1") Integer pageNo,
                                   @RequestParam(defaultValue = "10") Integer pageSize) {
        LocalDateTime start = null;
        LocalDateTime end = null;
        if (StringUtils.hasText(startDate)) {
            start = LocalDate.parse(startDate).atStartOfDay();
        }
        if (StringUtils.hasText(endDate)) {
            end = LocalDate.parse(endDate).atTime(LocalTime.MAX);
        }

        var page = nurseRejectLogMapper.selectPage(
                new Page<>(pageNo, pageSize),
                new LambdaQueryWrapper<NurseRejectLog>()
                        .eq(nurseUserId != null, NurseRejectLog::getNurseUserId, nurseUserId)
                        .ge(start != null, NurseRejectLog::getRejectTime, start)
                        .le(end != null, NurseRejectLog::getRejectTime, end)
                        .orderByDesc(NurseRejectLog::getRejectTime)
        );
        return Result.success(page);
    }

    /**
     * 护士拒单超限预警
     */
    @GetMapping("/reject/alert")
    public Result<?> rejectAlert() {
        SysConfig limitConfig = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>()
                        .eq(SysConfig::getConfigKey, "reject_limit_per_day")
                        .last("limit 1")
        );
        int limit = 5;
        if (limitConfig != null && StringUtils.hasText(limitConfig.getConfigValue())) {
            try {
                limit = Integer.parseInt(limitConfig.getConfigValue());
            } catch (Exception ignored) {
            }
        }

        List<NurseProfile> profiles = nurseProfileMapper.selectList(
                new LambdaQueryWrapper<NurseProfile>()
                        .eq(NurseProfile::getAuditStatus, NurseProfile.AuditStatus.APPROVED)
                        .eq(NurseProfile::getRejectDate, LocalDate.now())
                        .ge(NurseProfile::getRejectCountToday, limit)
                        .orderByDesc(NurseProfile::getRejectCountToday)
        );

        List<Map<String, Object>> alerts = new ArrayList<>();
        for (NurseProfile profile : profiles) {
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("nurseUserId", profile.getUserId());
            item.put("nurseName", profile.getNurseName());
            item.put("hospital", profile.getHospital());
            item.put("rejectCountToday", profile.getRejectCountToday());
            item.put("limit", limit);
            item.put("overLimit", (profile.getRejectCountToday() == null ? 0 : profile.getRejectCountToday()) - limit);
            alerts.add(item);
        }

        return Result.success(Map.of("limit", limit, "alerts", alerts, "count", alerts.size()));
    }

    /**
     * 护士位置实时监控列表
     */
    @GetMapping("/location/list")
    public Result<?> locationList() {
        List<NurseProfile> profiles = nurseProfileMapper.selectList(
                new LambdaQueryWrapper<NurseProfile>()
                        .eq(NurseProfile::getAuditStatus, NurseProfile.AuditStatus.APPROVED)
        );

        List<Map<String, Object>> rows = new ArrayList<>();
        for (NurseProfile profile : profiles) {
            NurseLocation location = nurseLocationMapper.selectOne(
                    new LambdaQueryWrapper<NurseLocation>()
                            .eq(NurseLocation::getNurseUserId, profile.getUserId())
                            .last("limit 1")
            );

            Map<String, Object> item = new LinkedHashMap<>();
            item.put("nurseUserId", profile.getUserId());
            item.put("nurseName", profile.getNurseName());
            item.put("hospital", profile.getHospital());
            item.put("workMode", profile.getWorkMode());
            item.put("acceptEnabled", profile.getAcceptEnabled());
            item.put("latitude", location == null ? null : location.getLatitude());
            item.put("longitude", location == null ? null : location.getLongitude());
            item.put("reportTime", location == null ? null : location.getReportTime());
            rows.add(item);
        }
        return Result.success(rows);
    }

    private void ensureNurseRoleBound(Long nurseUserId) {
        Role nurseRole = roleMapper.selectOne(
                new LambdaQueryWrapper<Role>()
                        .eq(Role::getRoleCode, "NURSE")
                        .eq(Role::getStatus, 1)
                        .last("LIMIT 1")
        );
        if (nurseRole == null) {
            log.warn("未找到 NURSE 角色，无法绑定护士角色: userId={}", nurseUserId);
            return;
        }

        UserRole existing = userRoleMapper.selectOne(
                new LambdaQueryWrapper<UserRole>()
                        .eq(UserRole::getUserId, nurseUserId)
                        .eq(UserRole::getRoleId, nurseRole.getId())
                        .last("LIMIT 1")
        );
        if (existing != null) {
            return;
        }

        userRoleMapper.insert(UserRole.builder()
                .userId(nurseUserId)
                .roleId(nurseRole.getId())
                .createTime(LocalDateTime.now())
                .build());
    }
}
