package com.nursing.task;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.nursing.entity.Notification;
import com.nursing.entity.OrderStatusLog;
import com.nursing.entity.Orders;
import com.nursing.entity.RefundRecord;
import com.nursing.mapper.NotificationMapper;
import com.nursing.mapper.OrderStatusLogMapper;
import com.nursing.mapper.OrdersMapper;
import com.nursing.mapper.RefundRecordMapper;
import com.nursing.service.AlipayService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.UUID;

/**
 * 自动退款定时任务
 *
 * 场景：用户取消已支付订单后，若首次退款调用失败，订单会停留在“退款中”。
 * 该任务会自动重试并在成功后将订单流转到“已退款”。
 */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.scheduling.enabled", havingValue = "true", matchIfMissing = true)
public class RefundScheduledTask {

    private final RefundRecordMapper refundRecordMapper;
    private final OrdersMapper ordersMapper;
    private final OrderStatusLogMapper orderStatusLogMapper;
    private final NotificationMapper notificationMapper;
    private final AlipayService alipayService;

    /**
     * 每分钟扫描一次退款中订单并自动原路退款
     */
    @Scheduled(fixedRate = 60000)
    public void retryRefundingOrders() {
        try {
            List<RefundRecord> pendingRefunds = refundRecordMapper.selectList(
                    new LambdaQueryWrapper<RefundRecord>()
                            .eq(RefundRecord::getRefundStatus, 0)
                            .orderByAsc(RefundRecord::getCreateTime)
                            .last("limit 50")
            );

            if (pendingRefunds.isEmpty()) {
                return;
            }

            for (RefundRecord refund : pendingRefunds) {
                try {
                    processOneRefund(refund);
                } catch (Exception e) {
                    log.error("自动退款处理异常: refundId={}, orderNo={}", refund.getId(), refund.getOrderNo(), e);
                }
            }
        } catch (Exception e) {
            log.error("自动退款任务执行失败", e);
        }
    }

    @Transactional
    protected void processOneRefund(RefundRecord refund) {
        if (refund == null || refund.getId() == null) {
            return;
        }

        RefundRecord latestRefund = refundRecordMapper.selectById(refund.getId());
        if (latestRefund == null || latestRefund.getRefundStatus() == null || latestRefund.getRefundStatus() != 0) {
            return;
        }

        Orders order = ordersMapper.selectOne(
                new LambdaQueryWrapper<Orders>().eq(Orders::getOrderNo, latestRefund.getOrderNo())
        );

        if (order == null) {
            latestRefund.setRefundStatus(2);
            latestRefund.setUpdateTime(LocalDateTime.now());
            refundRecordMapper.updateById(latestRefund);
            log.warn("自动退款失败：订单不存在，orderNo={}", latestRefund.getOrderNo());
            return;
        }

        if (order.getPayStatus() != null && order.getPayStatus() == Orders.PayStatusEnum.REFUNDED) {
            latestRefund.setRefundStatus(1);
            latestRefund.setUpdateTime(LocalDateTime.now());
            refundRecordMapper.updateById(latestRefund);
            return;
        }

        if (order.getPayStatus() == null || order.getPayStatus() != Orders.PayStatusEnum.PAID) {
            return;
        }

        String refundNo = "ARFD"
                + DateTimeFormatter.ofPattern("yyyyMMddHHmmss").format(LocalDateTime.now())
                + UUID.randomUUID().toString().replace("-", "").substring(0, 6).toUpperCase();

        boolean refunded = alipayService.refund(
                order.getOrderNo(),
                refundNo,
                latestRefund.getRefundAmount(),
                latestRefund.getRefundReason() == null ? "用户取消订单自动退款" : latestRefund.getRefundReason()
        );

        latestRefund.setThirdRefundNo(refundNo);
        latestRefund.setUpdateTime(LocalDateTime.now());

        if (!refunded) {
            refundRecordMapper.updateById(latestRefund);
            log.warn("自动退款调用失败，待下次重试: orderNo={}, refundId={}", order.getOrderNo(), latestRefund.getId());
            return;
        }

        Integer oldStatus = order.getOrderStatus();
        order.setOrderStatus(Orders.Status.REFUNDED);
        order.setPayStatus(Orders.PayStatusEnum.REFUNDED);
        order.setRefundAmount(latestRefund.getRefundAmount());
        order.setUpdateTime(LocalDateTime.now());
        ordersMapper.updateById(order);

        latestRefund.setRefundStatus(1);
        refundRecordMapper.updateById(latestRefund);

        if (oldStatus == null || oldStatus != Orders.Status.REFUNDED) {
            orderStatusLogMapper.insert(OrderStatusLog.builder()
                    .orderId(order.getId())
                    .orderNo(order.getOrderNo())
                    .oldStatus(oldStatus == null ? -1 : oldStatus)
                    .newStatus(Orders.Status.REFUNDED)
                    .operatorUserId(order.getUserId())
                    .operatorRole("SYSTEM")
                    .remark("系统自动原路退款成功")
                    .createTime(LocalDateTime.now())
                    .build());
        }

        notificationMapper.insert(Notification.builder()
                .receiverUserId(order.getUserId())
                .receiverRole("USER")
                .title("退款成功")
                .content("订单（" + order.getOrderNo() + "）已自动原路退款成功，请关注支付宝到账通知。")
                .bizType("REFUND")
                .bizId(order.getOrderNo())
                .readFlag(0)
                .createTime(LocalDateTime.now())
                .build());

        log.info("自动退款成功: orderNo={}, refundNo={}", order.getOrderNo(), refundNo);
    }
}
