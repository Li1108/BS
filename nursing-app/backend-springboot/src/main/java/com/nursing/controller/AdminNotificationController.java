package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.*;
import com.nursing.mapper.NotificationMapper;
import com.nursing.mapper.UserRoleMapper;
import com.nursing.mapper.RoleMapper;
import com.nursing.mapper.OperationLogMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * 管理员通知控制器
 */
@Slf4j
@RestController
@RequestMapping("/admin/notification")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminNotificationController {

    private final NotificationMapper notificationMapper;
    private final UserRoleMapper userRoleMapper;
    private final RoleMapper roleMapper;
    private final OperationLogMapper operationLogMapper;

    /**
     * 发送通知
     * POST /api/admin/notification/send
     * body: { receiverType: ALL_USER/ALL_NURSE/SINGLE_USER, receiverUserId, title, content }
     */
    @PostMapping("/send")
    public Result<Void> sendNotification(@RequestBody Map<String, Object> body) {
        Long adminId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        String receiverType = (String) body.get("receiverType");
        String title = (String) body.get("title");
        String content = (String) body.get("content");

        if (receiverType == null || receiverType.isBlank()) {
            return Result.badRequest("接收者类型不能为空");
        }
        if (title == null || title.isBlank()) {
            return Result.badRequest("标题不能为空");
        }
        if (content == null || content.isBlank()) {
            return Result.badRequest("内容不能为空");
        }

        int count = 0;

        switch (receiverType) {
            case "SINGLE_USER" -> {
                Object receiverIdObj = body.get("receiverUserId");
                if (receiverIdObj == null) {
                    return Result.badRequest("单发通知需要指定接收者ID");
                }
                Long receiverUserId = Long.parseLong(receiverIdObj.toString());
                String receiverRole = resolveReceiverRole(receiverUserId);
                insertNotification(receiverUserId, receiverRole, title, content);
                count = 1;
            }
            case "ALL_USER" -> {
                // 查找角色编码为USER的角色ID
                Role userRole = roleMapper.selectOne(
                        new LambdaQueryWrapper<Role>().eq(Role::getRoleCode, "USER")
                );
                if (userRole != null) {
                    List<UserRole> userRoles = userRoleMapper.selectList(
                            new LambdaQueryWrapper<UserRole>().eq(UserRole::getRoleId, userRole.getId())
                    );
                    for (UserRole ur : userRoles) {
                        insertNotification(ur.getUserId(), "USER", title, content);
                        count++;
                    }
                }
            }
            case "ALL_NURSE" -> {
                Role nurseRole = roleMapper.selectOne(
                        new LambdaQueryWrapper<Role>().eq(Role::getRoleCode, "NURSE")
                );
                if (nurseRole != null) {
                    List<UserRole> nurseRoles = userRoleMapper.selectList(
                            new LambdaQueryWrapper<UserRole>().eq(UserRole::getRoleId, nurseRole.getId())
                    );
                    for (UserRole ur : nurseRoles) {
                        insertNotification(ur.getUserId(), "NURSE", title, content);
                        count++;
                    }
                }
            }
            default -> {
                return Result.badRequest("不支持的接收者类型: " + receiverType);
            }
        }

        // 写操作日志
        OperationLog opLog = OperationLog.builder()
                .adminUserId(adminId)
                .actionType("SEND_NOTIFICATION")
                .actionDesc("发送通知, 类型=" + receiverType + ", 标题=" + title + ", 发送数=" + count)
                .requestPath("/admin/notification/send")
                .requestMethod("POST")
                .createTime(LocalDateTime.now())
                .build();
        operationLogMapper.insert(opLog);

        log.info("管理员{}发送通知, type={}, count={}", adminId, receiverType, count);
        return Result.success();
    }

    /**
     * 通知列表（分页+筛选）
     * GET /api/admin/notification/list?receiverRole=&keyword=&pageNo=&pageSize=
     */
    @GetMapping("/list")
    public Result<IPage<Notification>> getNotificationList(
            @RequestParam(required = false) String receiverRole,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") Integer pageNo,
            @RequestParam(defaultValue = "10") Integer pageSize) {

        LambdaQueryWrapper<Notification> wrapper = new LambdaQueryWrapper<Notification>()
                .eq(receiverRole != null && !receiverRole.isBlank(), Notification::getReceiverRole, receiverRole)
                .and(keyword != null && !keyword.isBlank(), w ->
                        w.like(Notification::getTitle, keyword)
                                .or().like(Notification::getContent, keyword))
                .orderByDesc(Notification::getCreateTime);

        IPage<Notification> page = notificationMapper.selectPage(new Page<>(pageNo, pageSize), wrapper);
        return Result.success(page);
    }

    private void insertNotification(Long receiverUserId, String receiverRole, String title, String content) {
        Notification notification = Notification.builder()
                .receiverUserId(receiverUserId)
                .receiverRole(receiverRole)
                .title(title)
                .content(content)
                .bizType("SYSTEM")
                .readFlag(0)
                .createTime(LocalDateTime.now())
                .build();
        notificationMapper.insert(notification);
    }

    private String resolveReceiverRole(Long receiverUserId) {
        UserRole userRole = userRoleMapper.selectOne(
                new LambdaQueryWrapper<UserRole>().eq(UserRole::getUserId, receiverUserId).last("LIMIT 1")
        );
        if (userRole == null) {
            return "USER";
        }
        Role role = roleMapper.selectById(userRole.getRoleId());
        return role != null && role.getRoleCode() != null ? role.getRoleCode() : "USER";
    }
}
