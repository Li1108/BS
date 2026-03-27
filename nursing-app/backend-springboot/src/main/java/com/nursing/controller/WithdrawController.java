package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.NurseWallet;
import com.nursing.entity.Notification;
import com.nursing.entity.Role;
import com.nursing.entity.UserRole;
import com.nursing.entity.Withdrawal;
import com.nursing.mapper.NurseWalletMapper;
import com.nursing.mapper.NotificationMapper;
import com.nursing.mapper.RoleMapper;
import com.nursing.mapper.UserRoleMapper;
import com.nursing.mapper.WithdrawalMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * 提现控制器
 */
@Slf4j
@RestController
@RequestMapping("/withdraw")
@RequiredArgsConstructor
public class WithdrawController {

    private final WithdrawalMapper withdrawalMapper;
    private final NurseWalletMapper nurseWalletMapper;
    private final NotificationMapper notificationMapper;
    private final RoleMapper roleMapper;
    private final UserRoleMapper userRoleMapper;

    /**
     * 护士申请提现
     */
    @PostMapping("/apply")
    @Transactional
    public Result<?> applyWithdraw(@RequestBody Map<String, Object> body) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        Object amountObj = body.get("amount");
        String bankName = getString(body, "bankName", "bank_name");
        String bankAccount = getString(body, "bankAccount", "bank_account");
        String accountHolder = getString(body, "accountHolder", "account_holder");

        if (amountObj == null) {
            return Result.badRequest("提现金额不能为空");
        }
        BigDecimal amount = new BigDecimal(amountObj.toString());
        if (amount.compareTo(BigDecimal.ZERO) <= 0) {
            return Result.badRequest("提现金额必须大于0");
        }
        if (bankName == null || bankName.isBlank()) {
            return Result.badRequest("银行名称不能为空");
        }
        if (bankAccount == null || bankAccount.isBlank()) {
            return Result.badRequest("银行账号不能为空");
        }
        if (accountHolder == null || accountHolder.isBlank()) {
            return Result.badRequest("账户持有人不能为空");
        }

        // 查询钱包余额
        LambdaQueryWrapper<NurseWallet> walletWrapper = new LambdaQueryWrapper<>();
        walletWrapper.eq(NurseWallet::getNurseUserId, userId);
        NurseWallet wallet = nurseWalletMapper.selectOne(walletWrapper);

        if (wallet == null || wallet.getBalance().compareTo(amount) < 0) {
            return Result.badRequest("余额不足");
        }

        // 检查是否有待审核的提现申请
        LambdaQueryWrapper<Withdrawal> pendingWrapper = new LambdaQueryWrapper<>();
        pendingWrapper.eq(Withdrawal::getNurseUserId, userId)
                .eq(Withdrawal::getStatus, Withdrawal.StatusEnum.PENDING);
        Long pendingCount = withdrawalMapper.selectCount(pendingWrapper);
        if (pendingCount > 0) {
            return Result.badRequest("您有待审核的提现申请，请等待审核完成后再申请");
        }

        LocalDateTime now = LocalDateTime.now();

        // 创建提现申请
        Withdrawal withdrawal = Withdrawal.builder()
                .nurseUserId(userId)
                .withdrawAmount(amount)
                .bankName(bankName)
                .bankAccount(bankAccount)
                .accountHolder(accountHolder)
                .status(Withdrawal.StatusEnum.PENDING)
                .createTime(now)
                .updateTime(now)
                .build();
        withdrawalMapper.insert(withdrawal);

        // 冻结余额（扣减可用余额）
        wallet.setBalance(wallet.getBalance().subtract(amount));
        wallet.setUpdateTime(now);
        nurseWalletMapper.updateById(wallet);

        notifyAdminsForWithdrawApply(userId, amount, now);

        log.info("护士申请提现: userId={}, amount={}, bankName={}", userId, amount, bankName);

        return Result.success("提现申请已提交", withdrawal);
    }

    private String getString(Map<String, Object> body, String... keys) {
        for (String key : keys) {
            Object value = body.get(key);
            if (value != null) {
                String text = value.toString();
                if (!text.isBlank()) {
                    return text;
                }
            }
        }
        return null;
    }

    /**
     * 护士提现记录列表
     */
    @GetMapping("/list")
    public Result<?> getWithdrawList(
            @RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "1") Integer pageNo,
            @RequestParam(defaultValue = "10") Integer pageSize) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        Page<Withdrawal> page = new Page<>(pageNo, pageSize);
        LambdaQueryWrapper<Withdrawal> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Withdrawal::getNurseUserId, userId);

        if (status != null) {
            wrapper.eq(Withdrawal::getStatus, status);
        }

        wrapper.orderByDesc(Withdrawal::getCreateTime);

        IPage<Withdrawal> withdrawalPage = withdrawalMapper.selectPage(page, wrapper);

        return Result.success(withdrawalPage);
    }

    private void notifyAdminsForWithdrawApply(Long nurseUserId, BigDecimal amount, LocalDateTime now) {
        Role adminRole = roleMapper.selectOne(new LambdaQueryWrapper<Role>()
                .eq(Role::getRoleCode, "ADMIN_SUPER")
                .last("limit 1"));
        if (adminRole == null) {
            return;
        }
        List<UserRole> adminUsers = userRoleMapper.selectList(
                new LambdaQueryWrapper<UserRole>().eq(UserRole::getRoleId, adminRole.getId()));
        for (UserRole admin : adminUsers) {
            notificationMapper.insert(Notification.builder()
                    .receiverUserId(admin.getUserId())
                    .receiverRole("ADMIN_SUPER")
                    .title("新的提现申请")
                    .content("护士用户ID=" + nurseUserId + " 提现申请 " + amount.toPlainString() + " 元，待审核。")
                    .bizType("WITHDRAW")
                    .bizId(String.valueOf(nurseUserId))
                    .readFlag(0)
                    .createTime(now)
                    .build());
        }
    }
}
