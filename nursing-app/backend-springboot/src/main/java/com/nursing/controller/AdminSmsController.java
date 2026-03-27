package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.SmsCode;
import com.nursing.mapper.SmsCodeMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 管理员 - 短信记录查询与统计
 */
@Slf4j
@RestController
@RequestMapping("/admin/sms")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminSmsController {

    private final SmsCodeMapper smsCodeMapper;

    @GetMapping("/list")
    public Result<?> list(@RequestParam(required = false) String phone,
                          @RequestParam(required = false) Integer usedFlag,
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

        Page<SmsCode> page = smsCodeMapper.selectPage(
                new Page<>(pageNo, pageSize),
                new LambdaQueryWrapper<SmsCode>()
                        .like(StringUtils.hasText(phone), SmsCode::getPhone, phone)
                        .eq(usedFlag != null, SmsCode::getUsedFlag, usedFlag)
                        .ge(start != null, SmsCode::getCreateTime, start)
                        .le(end != null, SmsCode::getCreateTime, end)
                        .orderByDesc(SmsCode::getCreateTime)
        );
        return Result.success(page);
    }

    @GetMapping("/stats")
    public Result<?> stats() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime todayStart = LocalDate.now().atStartOfDay();

        Long total = smsCodeMapper.selectCount(null);
        Long todayTotal = smsCodeMapper.selectCount(
                new LambdaQueryWrapper<SmsCode>()
                        .between(SmsCode::getCreateTime, todayStart, now)
        );
        Long todayUsed = smsCodeMapper.selectCount(
                new LambdaQueryWrapper<SmsCode>()
                        .eq(SmsCode::getUsedFlag, 1)
                        .between(SmsCode::getCreateTime, todayStart, now)
        );
        Long todayUnused = smsCodeMapper.selectCount(
                new LambdaQueryWrapper<SmsCode>()
                        .eq(SmsCode::getUsedFlag, 0)
                        .between(SmsCode::getCreateTime, todayStart, now)
        );

        List<Map<String, Object>> trend = new ArrayList<>();
        for (int i = 6; i >= 0; i--) {
            LocalDate day = LocalDate.now().minusDays(i);
            LocalDateTime dayStart = day.atStartOfDay();
            LocalDateTime dayEnd = day.atTime(LocalTime.MAX);
            Long sent = smsCodeMapper.selectCount(
                    new LambdaQueryWrapper<SmsCode>()
                            .between(SmsCode::getCreateTime, dayStart, dayEnd)
            );
            Long used = smsCodeMapper.selectCount(
                    new LambdaQueryWrapper<SmsCode>()
                            .eq(SmsCode::getUsedFlag, 1)
                            .between(SmsCode::getCreateTime, dayStart, dayEnd)
            );
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("date", day.toString());
            item.put("sent", sent);
            item.put("used", used);
            trend.add(item);
        }

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("total", total);
        data.put("todayTotal", todayTotal);
        data.put("todayUsed", todayUsed);
        data.put("todayUnused", todayUnused);
        data.put("todayUseRate", todayTotal == 0 ? 0D : (double) todayUsed / todayTotal);
        data.put("trend", trend);
        return Result.success(data);
    }
}
