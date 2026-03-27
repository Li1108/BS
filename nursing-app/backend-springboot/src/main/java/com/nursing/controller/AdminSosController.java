package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.EmergencyCall;
import com.nursing.entity.Notification;
import com.nursing.mapper.EmergencyCallMapper;
import com.nursing.mapper.NotificationMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 管理后台 SOS 紧急事件
 */
@Slf4j
@RestController
@RequestMapping("/admin/sos")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminSosController {

    private final EmergencyCallMapper emergencyCallMapper;
    private final NotificationMapper notificationMapper;

    @GetMapping("/list")
    public Result<IPage<EmergencyCall>> list(
            @RequestParam(required = false) Integer status,
            @RequestParam(required = false) String orderNo,
            @RequestParam(defaultValue = "1") Integer pageNo,
            @RequestParam(defaultValue = "10") Integer pageSize
    ) {
        LambdaQueryWrapper<EmergencyCall> wrapper = new LambdaQueryWrapper<EmergencyCall>()
                .eq(status != null, EmergencyCall::getStatus, status)
                .like(StringUtils.hasText(orderNo), EmergencyCall::getOrderNo, orderNo)
                .orderByDesc(EmergencyCall::getCreateTime);

        IPage<EmergencyCall> page = emergencyCallMapper.selectPage(new Page<>(pageNo, pageSize), wrapper);
        return Result.success(page);
    }

    @PostMapping("/handle/{id}")
    public Result<?> handle(@PathVariable Long id, @RequestBody(required = false) Map<String, Object> body) {
        EmergencyCall call = emergencyCallMapper.selectById(id);
        if (call == null) {
            return Result.notFound("SOS事件不存在");
        }
        if (call.getStatus() != null && call.getStatus() == EmergencyCall.Status.HANDLED) {
            return Result.success("该事件已处理", null);
        }

        Long adminId = getCurrentUserId();
        LocalDateTime now = LocalDateTime.now();
        String remark = body == null || body.get("remark") == null ? null : body.get("remark").toString();

        int updated = emergencyCallMapper.update(null,
            new LambdaUpdateWrapper<EmergencyCall>()
                .set(EmergencyCall::getStatus, EmergencyCall.Status.HANDLED)
                .set(EmergencyCall::getHandledBy, adminId)
                .set(EmergencyCall::getHandledTime, now)
                .set(EmergencyCall::getHandleRemark, remark)
                .set(EmergencyCall::getUpdateTime, now)
                .eq(EmergencyCall::getId, id)
                .eq(EmergencyCall::getStatus, EmergencyCall.Status.PENDING));

        if (updated == 0) {
            return Result.success("该事件已处理", null);
        }

        call.setStatus(EmergencyCall.Status.HANDLED);
        call.setHandledBy(adminId);
        call.setHandledTime(now);
        call.setHandleRemark(remark);
        call.setUpdateTime(now);

        notifyHandledResult(call);

        return Result.success();
    }

        /**
         * SOS 统计报表
         */
        @GetMapping("/stats")
        public Result<Map<String, Object>> stats() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime todayStart = LocalDate.now().atStartOfDay();

        Long total = emergencyCallMapper.selectCount(null);
        Long pending = emergencyCallMapper.selectCount(
            new LambdaQueryWrapper<EmergencyCall>()
                .eq(EmergencyCall::getStatus, EmergencyCall.Status.PENDING)
        );
        Long handled = emergencyCallMapper.selectCount(
            new LambdaQueryWrapper<EmergencyCall>()
                .eq(EmergencyCall::getStatus, EmergencyCall.Status.HANDLED)
        );
        Long todayTotal = emergencyCallMapper.selectCount(
            new LambdaQueryWrapper<EmergencyCall>()
                .between(EmergencyCall::getCreateTime, todayStart, now)
        );
        Long todayPending = emergencyCallMapper.selectCount(
            new LambdaQueryWrapper<EmergencyCall>()
                .eq(EmergencyCall::getStatus, EmergencyCall.Status.PENDING)
                .between(EmergencyCall::getCreateTime, todayStart, now)
        );
        Long todayHandled = emergencyCallMapper.selectCount(
            new LambdaQueryWrapper<EmergencyCall>()
                .eq(EmergencyCall::getStatus, EmergencyCall.Status.HANDLED)
                .between(EmergencyCall::getCreateTime, todayStart, now)
        );

        List<Map<String, Object>> trend = new ArrayList<>();
        for (int i = 6; i >= 0; i--) {
            LocalDate day = LocalDate.now().minusDays(i);
            LocalDateTime dayStart = day.atStartOfDay();
            LocalDateTime dayEnd = day.plusDays(1).atStartOfDay().minusSeconds(1);
            Long dayTotal = emergencyCallMapper.selectCount(
                new LambdaQueryWrapper<EmergencyCall>()
                    .between(EmergencyCall::getCreateTime, dayStart, dayEnd)
            );
            Long dayHandled = emergencyCallMapper.selectCount(
                new LambdaQueryWrapper<EmergencyCall>()
                    .eq(EmergencyCall::getStatus, EmergencyCall.Status.HANDLED)
                    .between(EmergencyCall::getCreateTime, dayStart, dayEnd)
            );
            Map<String, Object> item = new LinkedHashMap<>();
            item.put("date", day.toString());
            item.put("total", dayTotal);
            item.put("handled", dayHandled);
            trend.add(item);
        }

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("total", total);
        data.put("pending", pending);
        data.put("handled", handled);
        data.put("todayTotal", todayTotal);
        data.put("todayPending", todayPending);
        data.put("todayHandled", todayHandled);
        data.put("handleRate", total == 0 ? 0D : (double) handled / total);
        data.put("trend", trend);
        return Result.success(data);
        }

    private void notifyHandledResult(EmergencyCall call) {
        LocalDateTime now = LocalDateTime.now();
        String title = "SOS处理结果";
        String baseContent = "订单" + call.getOrderNo() + "的SOS已由管理员处理";
        String content = StringUtils.hasText(call.getHandleRemark())
                ? baseContent + "，处理说明：" + call.getHandleRemark()
                : baseContent;

        if (call.getUserId() != null) {
            notificationMapper.insert(Notification.builder()
                    .receiverUserId(call.getUserId())
                    .receiverRole("USER")
                    .title(title)
                    .content(content)
                    .bizType("SOS")
                    .bizId(call.getOrderNo())
                    .readFlag(0)
                    .createTime(now)
                    .build());
        }

        if (call.getNurseUserId() != null) {
            notificationMapper.insert(Notification.builder()
                    .receiverUserId(call.getNurseUserId())
                    .receiverRole("NURSE")
                    .title(title)
                    .content(content)
                    .bizType("SOS")
                    .bizId(call.getOrderNo())
                    .readFlag(0)
                    .createTime(now)
                    .build());
        }
    }

    private Long getCurrentUserId() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof Long) {
            return (Long) auth.getPrincipal();
        }
        return null;
    }
}
