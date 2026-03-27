package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.NurseProfile;
import com.nursing.entity.NurseWallet;
import com.nursing.entity.SysUser;
import com.nursing.entity.WalletLog;
import com.nursing.mapper.NurseProfileMapper;
import com.nursing.mapper.NurseWalletMapper;
import com.nursing.mapper.SysUserMapper;
import com.nursing.mapper.WalletLogMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 管理员 - 护士钱包管理
 */
@Slf4j
@RestController
@RequestMapping("/admin/wallet")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminWalletController {

    private final NurseWalletMapper nurseWalletMapper;
    private final WalletLogMapper walletLogMapper;
    private final SysUserMapper sysUserMapper;
    private final NurseProfileMapper nurseProfileMapper;

    /**
     * 护士钱包列表（分页 + 按护士手机号/姓名筛选）
     */
    @GetMapping("/list")
    public Result<?> list(@RequestParam(required = false) String nursePhone,
                          @RequestParam(required = false) String nurseName,
                          @RequestParam(defaultValue = "1") Integer pageNo,
                          @RequestParam(defaultValue = "10") Integer pageSize) {
        Page<NurseWallet> page = new Page<>(pageNo, pageSize);
        LambdaQueryWrapper<NurseWallet> wrapper = new LambdaQueryWrapper<>();

        // 按护士手机号筛选：先查 user_account 得到 userId 列表
        if (StringUtils.hasText(nursePhone)) {
            LambdaQueryWrapper<SysUser> userWrapper = new LambdaQueryWrapper<>();
            userWrapper.like(SysUser::getPhone, nursePhone).select(SysUser::getId);
            List<Long> userIds = sysUserMapper.selectList(userWrapper)
                    .stream().map(SysUser::getId).collect(Collectors.toList());
            if (userIds.isEmpty()) {
                return Result.success(new Page<>());
            }
            wrapper.in(NurseWallet::getNurseUserId, userIds);
        }

        // 按护士姓名筛选：先查 nurse_profile 得到 userId 列表
        if (StringUtils.hasText(nurseName)) {
            LambdaQueryWrapper<NurseProfile> profileWrapper = new LambdaQueryWrapper<>();
            profileWrapper.like(NurseProfile::getNurseName, nurseName).select(NurseProfile::getUserId);
            List<Long> nurseUserIds = nurseProfileMapper.selectList(profileWrapper)
                    .stream().map(NurseProfile::getUserId).collect(Collectors.toList());
            if (nurseUserIds.isEmpty()) {
                return Result.success(new Page<>());
            }
            wrapper.in(NurseWallet::getNurseUserId, nurseUserIds);
        }

        wrapper.orderByDesc(NurseWallet::getUpdateTime);
        return Result.success(nurseWalletMapper.selectPage(page, wrapper));
    }

    /**
     * 护士钱包详情（按护士用户ID查询）
     */
    @GetMapping("/detail/{nurseUserId}")
    public Result<?> detail(@PathVariable Long nurseUserId) {
        LambdaQueryWrapper<NurseWallet> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(NurseWallet::getNurseUserId, nurseUserId);
        NurseWallet wallet = nurseWalletMapper.selectOne(wrapper);
        if (wallet == null) {
            return Result.notFound("钱包记录不存在");
        }
        return Result.success(wallet);
    }

    /**
     * 批量获取护士钱包详情（按护士用户ID列表）
     */
    @PostMapping("/batch/detail")
    public Result<?> batchDetail(@RequestBody(required = false) Map<String, List<Long>> body) {
        List<Long> nurseUserIds = body == null ? null : body.get("nurseUserIds");
        if (nurseUserIds == null || nurseUserIds.isEmpty()) {
            return Result.success(Collections.emptyList());
        }

        List<Long> validIds = nurseUserIds.stream()
                .filter(id -> id != null && id > 0)
                .distinct()
                .collect(Collectors.toList());
        if (validIds.isEmpty()) {
            return Result.success(Collections.emptyList());
        }

        LambdaQueryWrapper<NurseWallet> wrapper = new LambdaQueryWrapper<>();
        wrapper.in(NurseWallet::getNurseUserId, validIds);
        return Result.success(nurseWalletMapper.selectList(wrapper));
    }

    /**
     * 钱包流水列表（分页 + 多条件筛选）
     */
    @GetMapping("/log/list")
    public Result<?> logList(@RequestParam(required = false) Long nurseUserId,
                             @RequestParam(required = false) String orderNo,
                             @RequestParam(required = false) Integer logType,
                             @RequestParam(defaultValue = "1") Integer pageNo,
                             @RequestParam(defaultValue = "10") Integer pageSize) {
        Page<WalletLog> page = new Page<>(pageNo, pageSize);
        LambdaQueryWrapper<WalletLog> wrapper = new LambdaQueryWrapper<>();

        if (nurseUserId != null) {
            wrapper.eq(WalletLog::getNurseUserId, nurseUserId);
        }
        if (StringUtils.hasText(orderNo)) {
            wrapper.like(WalletLog::getOrderNo, orderNo);
        }
        if (logType != null) {
            wrapper.eq(WalletLog::getChangeType, logType);
        }

        wrapper.orderByDesc(WalletLog::getCreateTime);
        return Result.success(walletLogMapper.selectPage(page, wrapper));
    }
}
