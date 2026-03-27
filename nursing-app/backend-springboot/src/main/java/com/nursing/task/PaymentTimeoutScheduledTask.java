package com.nursing.task;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.nursing.entity.Notification;
import com.nursing.entity.OrderStatusLog;
import com.nursing.entity.Orders;
import com.nursing.mapper.NotificationMapper;
import com.nursing.mapper.OrderStatusLogMapper;
import com.nursing.mapper.OrdersMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 支付超时自动关闭任务
 *
 * 每分钟扫描待支付超时（30分钟）的订单并自动关闭。
 */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.scheduling.enabled", havingValue = "true", matchIfMissing = true)
public class PaymentTimeoutScheduledTask {

    private static final int PAYMENT_TIMEOUT_MINUTES = 30;

    private final OrdersMapper ordersMapper;
    private final OrderStatusLogMapper orderStatusLogMapper;
    private final NotificationMapper notificationMapper;

    /**
     * 每分钟执行一次：自动关闭超时待支付订单
     */
    @Scheduled(fixedRate = 60000)
    public void autoCloseTimeoutPendingPaymentOrders() {
        LocalDateTime deadline = LocalDateTime.now().minusMinutes(PAYMENT_TIMEOUT_MINUTES);

        List<Orders> timeoutOrders = ordersMapper.selectList(
                new LambdaQueryWrapper<Orders>()
                        .eq(Orders::getOrderStatus, Orders.Status.PENDING_PAYMENT)
                        .eq(Orders::getPayStatus, Orders.PayStatusEnum.UNPAID)
                        .le(Orders::getCreateTime, deadline)
                        .last("limit 100")
        );

        if (timeoutOrders.isEmpty()) {
            return;
        }

        for (Orders order : timeoutOrders) {
            try {
                autoCloseOneOrder(order);
            } catch (Exception e) {
                log.error("自动关闭待支付订单异常: orderId={}, orderNo={}", order.getId(), order.getOrderNo(), e);
            }
        }
    }

    private void autoCloseOneOrder(Orders order) {
        if (order == null || order.getId() == null) {
            return;
        }

        LambdaUpdateWrapper<Orders> updateWrapper = new LambdaUpdateWrapper<Orders>()
                .eq(Orders::getId, order.getId())
                .eq(Orders::getOrderStatus, Orders.Status.PENDING_PAYMENT)
                .eq(Orders::getPayStatus, Orders.PayStatusEnum.UNPAID)
                .set(Orders::getOrderStatus, Orders.Status.CANCELLED)
                .set(Orders::getCancelReason, "支付超时自动关闭")
                .set(Orders::getCancelTime, LocalDateTime.now())
                .set(Orders::getUpdateTime, LocalDateTime.now());

        int affected = ordersMapper.update(null, updateWrapper);
        if (affected <= 0) {
            return;
        }

        orderStatusLogMapper.insert(OrderStatusLog.builder()
                .orderId(order.getId())
                .orderNo(order.getOrderNo())
                .oldStatus(Orders.Status.PENDING_PAYMENT)
                .newStatus(Orders.Status.CANCELLED)
                .operatorUserId(order.getUserId())
                .operatorRole("SYSTEM")
                .remark("支付超时自动关闭")
                .createTime(LocalDateTime.now())
                .build());

        notificationMapper.insert(Notification.builder()
                .receiverUserId(order.getUserId())
                .receiverRole("USER")
                .title("订单已自动关闭")
                .content("订单（" + order.getOrderNo() + "）超过30分钟未支付，系统已自动关闭。")
                .bizType("ORDER")
                .bizId(String.valueOf(order.getId()))
                .readFlag(0)
                .createTime(LocalDateTime.now())
                .build());

        log.info("支付超时自动关闭订单成功: orderNo={}", order.getOrderNo());
    }
}
