package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.nursing.common.Result;
import com.nursing.entity.EmergencyCall;
import com.nursing.entity.Notification;
import com.nursing.entity.Orders;
import com.nursing.entity.Role;
import com.nursing.entity.UserRole;
import com.nursing.mapper.EmergencyCallMapper;
import com.nursing.mapper.NotificationMapper;
import com.nursing.mapper.OrdersMapper;
import com.nursing.mapper.RoleMapper;
import com.nursing.mapper.UserRoleMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Objects;

/**
 * SOS 紧急呼叫
 */
@Slf4j
@RestController
@RequestMapping("/sos")
@RequiredArgsConstructor
public class SosController {

    private final OrdersMapper ordersMapper;
    private final EmergencyCallMapper emergencyCallMapper;
    private final NotificationMapper notificationMapper;
    private final RoleMapper roleMapper;
    private final UserRoleMapper userRoleMapper;

    @PostMapping("/trigger")
    public Result<?> trigger(@RequestBody Map<String, Object> body) {
        Long currentUserId = getCurrentUserId();
        if (currentUserId == null) {
            return Result.unauthorized("请先登录");
        }

        Object orderIdObj = body.get("orderId");
        if (orderIdObj == null) {
            return Result.badRequest("orderId 不能为空");
        }
        Long orderId;
        try {
            orderId = Long.parseLong(orderIdObj.toString());
        } catch (Exception e) {
            return Result.badRequest("orderId 格式错误");
        }

        Orders order = ordersMapper.selectById(orderId);
        if (order == null) {
            return Result.notFound("订单不存在");
        }
        if (!Objects.equals(order.getOrderStatus(), Orders.Status.IN_SERVICE)) {
            return Result.badRequest("仅服务中订单可发起 SOS");
        }

        boolean callerIsUser = Objects.equals(currentUserId, order.getUserId());
        boolean callerIsNurse = Objects.equals(currentUserId, order.getNurseUserId());
        if (!callerIsUser && !callerIsNurse) {
            return Result.forbidden("无权对该订单发起 SOS");
        }

        Integer emergencyType = 1;
        if (body.get("emergencyType") != null) {
            try {
                emergencyType = Integer.parseInt(body.get("emergencyType").toString());
            } catch (Exception ignored) {
            }
        }
        String description = body.get("description") == null ? "" : body.get("description").toString();

        LocalDateTime now = LocalDateTime.now();
        EmergencyCall call = EmergencyCall.builder()
                .orderId(order.getId())
                .orderNo(order.getOrderNo())
                .userId(order.getUserId())
                .nurseUserId(order.getNurseUserId())
                .callerUserId(currentUserId)
                .callerRole(callerIsNurse ? "NURSE" : "USER")
                .emergencyType(emergencyType)
                .description(description)
                .status(EmergencyCall.Status.PENDING)
                .createTime(now)
                .updateTime(now)
                .build();
        emergencyCallMapper.insert(call);

        String callerText = callerIsNurse ? "护士" : "用户";
        String notifyTitle = "SOS紧急呼叫";
        String notifyContent = "订单" + order.getOrderNo() + "，" + callerText + "发起紧急求助，请立即处理";

        notifyAdmins(notifyTitle, notifyContent, order.getOrderNo(), now);
        notifyCounterpart(order, callerIsNurse, callerIsUser, now);

        log.warn("SOS触发: orderNo={}, callerUserId={}, callerRole={}", order.getOrderNo(), currentUserId, call.getCallerRole());
        return Result.success(Map.of("id", call.getId(), "status", call.getStatus()));
    }

    private void notifyAdmins(String title, String content, String orderNo, LocalDateTime now) {
        Role adminRole = roleMapper.selectOne(new LambdaQueryWrapper<Role>().eq(Role::getRoleCode, "ADMIN_SUPER"));
        if (adminRole == null) {
            return;
        }
        List<UserRole> adminUsers = userRoleMapper.selectList(
                new LambdaQueryWrapper<UserRole>().eq(UserRole::getRoleId, adminRole.getId())
        );
        for (UserRole admin : adminUsers) {
            notificationMapper.insert(Notification.builder()
                    .receiverUserId(admin.getUserId())
                    .receiverRole("ADMIN_SUPER")
                    .title(title)
                    .content(content)
                    .bizType("SOS")
                    .bizId(orderNo)
                    .readFlag(0)
                    .createTime(now)
                    .build());
        }
    }

    private void notifyCounterpart(Orders order, boolean callerIsNurse, boolean callerIsUser, LocalDateTime now) {
        if (callerIsNurse && order.getUserId() != null) {
            notificationMapper.insert(Notification.builder()
                    .receiverUserId(order.getUserId())
                    .receiverRole("USER")
                    .title("服务紧急提醒")
                    .content("您的订单" + order.getOrderNo() + "已触发SOS，平台正在处理")
                    .bizType("SOS")
                    .bizId(order.getOrderNo())
                    .readFlag(0)
                    .createTime(now)
                    .build());
        }
        if (callerIsUser && order.getNurseUserId() != null) {
            notificationMapper.insert(Notification.builder()
                    .receiverUserId(order.getNurseUserId())
                    .receiverRole("NURSE")
                    .title("服务紧急提醒")
                    .content("订单" + order.getOrderNo() + "用户触发SOS，请保持沟通并等待平台联系")
                    .bizType("SOS")
                    .bizId(order.getOrderNo())
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
