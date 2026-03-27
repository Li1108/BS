package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.OperationLog;
import com.nursing.mapper.OperationLogMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.time.LocalTime;

/**
 * 管理员 - 操作日志
 */
@Slf4j
@RestController
@RequestMapping("/admin/log")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminLogController {

    private final OperationLogMapper operationLogMapper;

    /**
     * 日志列表（分页 + 管理员ID + 操作类型筛选）
     */
    @GetMapping("/list")
    public Result<?> list(@RequestParam(required = false) Long adminUserId,
                          @RequestParam(required = false) String actionType,
                          @RequestParam(required = false) String keyword,
                          @RequestParam(required = false) String startDate,
                          @RequestParam(required = false) String endDate,
                          @RequestParam(defaultValue = "1") Integer pageNo,
                          @RequestParam(defaultValue = "10") Integer pageSize) {
        Page<OperationLog> page = new Page<>(pageNo, pageSize);
        LambdaQueryWrapper<OperationLog> wrapper = new LambdaQueryWrapper<>();

        if (adminUserId != null) {
            wrapper.eq(OperationLog::getAdminUserId, adminUserId);
        }
        if (StringUtils.hasText(actionType)) {
            wrapper.eq(OperationLog::getActionType, actionType);
        }
        if (StringUtils.hasText(keyword)) {
            wrapper.and(w -> w.like(OperationLog::getActionDesc, keyword)
                    .or().like(OperationLog::getIp, keyword)
                    .or().like(OperationLog::getRequestPath, keyword));
        }
        if (StringUtils.hasText(startDate)) {
            wrapper.ge(OperationLog::getCreateTime, LocalDate.parse(startDate).atStartOfDay());
        }
        if (StringUtils.hasText(endDate)) {
            wrapper.le(OperationLog::getCreateTime, LocalDate.parse(endDate).atTime(LocalTime.MAX));
        }
        wrapper.orderByDesc(OperationLog::getCreateTime);

        return Result.success(operationLogMapper.selectPage(page, wrapper));
    }

    /**
     * 日志详情
     */
    @GetMapping("/detail/{id}")
    public Result<?> detail(@PathVariable Long id) {
        OperationLog log1 = operationLogMapper.selectById(id);
        if (log1 == null) {
            return Result.notFound("日志不存在");
        }
        return Result.success(log1);
    }

    /**
     * 删除日志
     */
    @DeleteMapping("/delete/{id}")
    public Result<?> delete(@PathVariable Long id) {
        OperationLog logRecord = operationLogMapper.selectById(id);
        if (logRecord == null) {
            return Result.notFound("日志不存在");
        }
        operationLogMapper.deleteById(id);
        log.info("删除操作日志，id={}", id);
        return Result.success("日志已删除");
    }
}
