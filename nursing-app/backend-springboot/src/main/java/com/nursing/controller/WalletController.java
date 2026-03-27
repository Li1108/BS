package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.NurseWallet;
import com.nursing.entity.WalletLog;
import com.nursing.mapper.NurseWalletMapper;
import com.nursing.mapper.WalletLogMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

/**
 * 钱包控制器
 */
@Slf4j
@RestController
@RequestMapping("/wallet")
@RequiredArgsConstructor
public class WalletController {

    private final NurseWalletMapper nurseWalletMapper;
    private final WalletLogMapper walletLogMapper;

    /**
     * 获取护士钱包信息
     */
    @GetMapping("/info")
    public Result<?> getWalletInfo() {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        LambdaQueryWrapper<NurseWallet> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(NurseWallet::getNurseUserId, userId);
        NurseWallet wallet = nurseWalletMapper.selectOne(wrapper);

        if (wallet == null) {
            // 如果钱包不存在，返回默认空钱包信息
            wallet = NurseWallet.builder()
                    .nurseUserId(userId)
                    .balance(java.math.BigDecimal.ZERO)
                    .totalIncome(java.math.BigDecimal.ZERO)
                    .totalWithdraw(java.math.BigDecimal.ZERO)
                    .build();
        }

        return Result.success(wallet);
    }

    /**
     * 获取钱包流水记录（分页）
     */
    @GetMapping("/log/list")
    public Result<?> getWalletLogList(
            @RequestParam(defaultValue = "1") Integer pageNo,
            @RequestParam(defaultValue = "10") Integer pageSize) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        Page<WalletLog> page = new Page<>(pageNo, pageSize);
        LambdaQueryWrapper<WalletLog> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(WalletLog::getNurseUserId, userId)
                .orderByDesc(WalletLog::getCreateTime);

        IPage<WalletLog> logPage = walletLogMapper.selectPage(page, wrapper);

        return Result.success(logPage);
    }
}
