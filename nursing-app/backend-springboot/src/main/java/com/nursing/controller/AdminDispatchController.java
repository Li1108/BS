package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.OperationLog;
import com.nursing.entity.OrderAssignLog;
import com.nursing.entity.Orders;
import com.nursing.entity.NurseProfile;
import com.nursing.entity.OrderStatusLog;
import com.nursing.entity.Notification;
import com.nursing.mapper.NurseProfileMapper;
import com.nursing.mapper.NotificationMapper;
import com.nursing.mapper.OrderStatusLogMapper;
import com.nursing.mapper.OperationLogMapper;
import com.nursing.mapper.OrderAssignLogMapper;
import com.nursing.mapper.OrdersMapper;
import com.nursing.service.AliyunPushService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;

/**
 * 管理员 - 派单管理
 */
@Slf4j
@RestController
@RequestMapping("/admin/dispatch")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminDispatchController {

    private final OrderAssignLogMapper orderAssignLogMapper;
    private final OrdersMapper ordersMapper;
    private final NurseProfileMapper nurseProfileMapper;
    private final OrderStatusLogMapper orderStatusLogMapper;
    private final NotificationMapper notificationMapper;
    private final OperationLogMapper operationLogMapper;
    private final AliyunPushService aliyunPushService;

    /**
     * 派单日志列表（分页 + 多条件筛选）
     */
    @GetMapping("/log/list")
    public Result<?> logList(@RequestParam(required = false) String orderNo,
                             @RequestParam(required = false) Integer resultStatus,
                             @RequestParam(defaultValue = "1") Integer pageNo,
                             @RequestParam(defaultValue = "10") Integer pageSize) {
        Page<OrderAssignLog> page = new Page<>(pageNo, pageSize);
        LambdaQueryWrapper<OrderAssignLog> wrapper = new LambdaQueryWrapper<>();

        if (StringUtils.hasText(orderNo)) {
            wrapper.like(OrderAssignLog::getOrderNo, orderNo);
        }
        if (resultStatus != null) {
            wrapper.eq(OrderAssignLog::getSuccessFlag, resultStatus);
        }

        wrapper.orderByDesc(OrderAssignLog::getCreateTime);
        return Result.success(orderAssignLogMapper.selectPage(page, wrapper));
    }

    /**
     * 手动派单
     * 将指定护士分配给指定订单，设置订单状态为2（已派单），写派单日志 + 操作日志
     */
    @PostMapping("/manualAssign")
    @Transactional
    public Result<?> manualAssign(@RequestBody Map<String, Object> body,
                                  HttpServletRequest request) {
        String orderNo = (String) body.get("orderNo");
        // 兼容前端传 Number 或 String
        Long nurseUserId = Long.valueOf(body.get("nurseUserId").toString());
        String remark = (String) body.get("remark");

        // 查询订单
        LambdaQueryWrapper<Orders> orderWrapper = new LambdaQueryWrapper<>();
        orderWrapper.eq(Orders::getOrderNo, orderNo);
        Orders order = ordersMapper.selectOne(orderWrapper);
        if (order == null) {
            return Result.notFound("订单不存在");
        }

        // 只允许待接单(1)的订单进行手动派单
        if (order.getOrderStatus() != Orders.Status.PENDING_ACCEPT) {
            return Result.badRequest("当前订单状态不允许派单，仅待接单状态可派单");
        }

        NurseProfile nurseProfile = nurseProfileMapper.selectOne(new LambdaQueryWrapper<NurseProfile>()
                .eq(NurseProfile::getUserId, nurseUserId));
        if (nurseProfile == null) {
            return Result.badRequest("护士不存在或未认证");
        }
        if (nurseProfile.getAuditStatus() == null || nurseProfile.getAuditStatus() != NurseProfile.AuditStatus.APPROVED) {
            return Result.badRequest("护士审核未通过，不能派单");
        }
        if (nurseProfile.getAcceptEnabled() == null || nurseProfile.getAcceptEnabled() != 1) {
            return Result.badRequest("护士当前为休息中，不能派单");
        }

        int oldStatus = order.getOrderStatus();

        // 更新订单：分配护士、设置状态为已派单
        order.setNurseUserId(nurseUserId);
        order.setOrderStatus(Orders.Status.DISPATCHED);
        order.setLastAssignTime(LocalDateTime.now());
        order.setAssignRetryCount((order.getAssignRetryCount() == null ? 0 : order.getAssignRetryCount()) + 1);
        order.setAssignFailReason(null);
        order.setUpdateTime(LocalDateTime.now());
        ordersMapper.updateById(order);

        orderStatusLogMapper.insert(OrderStatusLog.builder()
            .orderId(order.getId())
            .orderNo(orderNo)
            .oldStatus(oldStatus)
            .newStatus(Orders.Status.DISPATCHED)
            .operatorUserId((Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal())
            .operatorRole("ADMIN_SUPER")
            .remark(StringUtils.hasText(remark) ? remark : "管理员手动派单")
            .createTime(LocalDateTime.now())
            .build());

        // 写派单日志
        int tryNo = (order.getAssignRetryCount() != null ? order.getAssignRetryCount() : 0) + 1;
        orderAssignLogMapper.insert(OrderAssignLog.builder()
                .orderId(order.getId())
                .orderNo(orderNo)
                .tryNo(tryNo)
                .nurseUserId(nurseUserId)
                .successFlag(1)
                .createTime(LocalDateTime.now())
                .build());

        Notification nurseNotification = Notification.builder()
            .receiverUserId(nurseUserId)
            .receiverRole("NURSE")
            .title("新订单待接单")
            .content("您有新的护理订单，订单号：" + orderNo + "，请及时处理。")
            .bizType("ORDER")
            .bizId(String.valueOf(order.getId()))
            .readFlag(0)
            .createTime(LocalDateTime.now())
            .build();
        notificationMapper.insert(nurseNotification);
        aliyunPushService.pushNewOrderToNurse(
                nurseUserId,
                order.getId(),
                orderNo,
                nurseNotification.getContent()
        );

        // 写操作日志
        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("MANUAL_ASSIGN")
                .actionDesc("手动派单，orderNo=" + orderNo + "，护士userId=" + nurseUserId + "，备注：" + remark)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("orderNo=" + orderNo + ", nurseUserId=" + nurseUserId + ", remark=" + remark)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]手动派单，orderNo={}，护士userId={}", adminUserId, orderNo, nurseUserId);
        return Result.success("手动派单成功");
    }
}
