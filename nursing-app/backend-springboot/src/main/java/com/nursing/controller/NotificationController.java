package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.Notification;
import com.nursing.mapper.NotificationMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * 通知控制器
 * 处理用户通知列表、标记已读、未读数量
 */
@Slf4j
@RestController
@RequestMapping("/notification")
@RequiredArgsConstructor
public class NotificationController {

    private final NotificationMapper notificationMapper;

    // ==================== GET /notification/list ====================

    /**
     * 通知列表
     * GET /notification/list?readFlag=&pageNo=&pageSize=
     */
    @GetMapping("/list")
    public Result<IPage<Notification>> list(
            @RequestParam(required = false) Integer readFlag,
            @RequestParam(defaultValue = "1") int pageNo,
            @RequestParam(defaultValue = "10") int pageSize) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        LambdaQueryWrapper<Notification> wrapper = new LambdaQueryWrapper<Notification>()
                .eq(Notification::getReceiverUserId, userId)
                .eq(readFlag != null, Notification::getReadFlag, readFlag)
                .orderByDesc(Notification::getCreateTime);

        IPage<Notification> page = notificationMapper.selectPage(new Page<>(pageNo, pageSize), wrapper);
        return Result.success(page);
    }

    // ==================== POST /notification/read/{id} ====================

    /**
     * 标记通知为已读
     * POST /notification/read/{id}
     */
    @PostMapping("/read/{id}")
    public Result<Void> markAsRead(@PathVariable Long id) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        Notification notification = notificationMapper.selectById(id);
        if (notification == null) {
            return Result.notFound("通知不存在");
        }
        if (!userId.equals(notification.getReceiverUserId())) {
            return Result.forbidden("无权操作此通知");
        }
        if (notification.getReadFlag() != null && notification.getReadFlag() == 1) {
            return Result.success("已标记为已读", null);
        }

        notification.setReadFlag(1);
        notificationMapper.updateById(notification);
        return Result.success("已标记为已读", null);
    }

    // ==================== GET /notification/unreadCount ====================

    /**
     * 获取未读通知数量
     * GET /notification/unreadCount
     */
    @GetMapping("/unreadCount")
    public Result<Map<String, Long>> unreadCount() {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        Long count = notificationMapper.selectCount(
                new LambdaQueryWrapper<Notification>()
                        .eq(Notification::getReceiverUserId, userId)
                        .eq(Notification::getReadFlag, 0));

        return Result.success(Map.of("unreadCount", count));
    }

    // ==================== 私有方法 ====================

    /**
     * 从 SecurityContextHolder 获取当前用户ID
     */
    private Long getCurrentUserId() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof Long) {
            return (Long) auth.getPrincipal();
        }
        return null;
    }
}
