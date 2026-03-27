package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.nursing.common.Result;
import com.nursing.entity.Orders;
import com.nursing.entity.OrderStatusLog;
import com.nursing.entity.PaymentRecord;
import com.nursing.entity.Notification;
import com.nursing.mapper.NotificationMapper;
import com.nursing.mapper.OrdersMapper;
import com.nursing.mapper.OrderStatusLogMapper;
import com.nursing.mapper.PaymentRecordMapper;
import com.nursing.service.AlipayService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 支付控制器
 */
@Slf4j
@RestController
@RequestMapping("/payment")
@RequiredArgsConstructor
public class PaymentController {

    private static final int MAX_TRADE_NO_LENGTH = 64;

    private final OrdersMapper ordersMapper;
    private final PaymentRecordMapper paymentRecordMapper;
    private final OrderStatusLogMapper orderStatusLogMapper;
    private final NotificationMapper notificationMapper;
    private final AlipayService alipayService;

    /**
     * 调试：查看当前支付宝配置生效情况
     */
    @GetMapping("/config-check")
    public Result<?> configCheck() {
        return Result.success(alipayService.getConfigCheckInfo());
    }

    /**
     * 创建支付单（返回支付宝 App 支付串）
     */
    @PostMapping("/pay")
    @Transactional
    public Result<?> payOrder(@RequestBody Map<String, Object> body) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        String orderNo = (String) body.get("orderNo");
        Integer payMethod = body.get("payMethod") != null ? Integer.valueOf(body.get("payMethod").toString()) : 1;

        if (orderNo == null || orderNo.isBlank()) {
            return Result.badRequest("订单号不能为空");
        }

        // 查询订单
        LambdaQueryWrapper<Orders> orderWrapper = new LambdaQueryWrapper<>();
        orderWrapper.eq(Orders::getOrderNo, orderNo);
        Orders order = ordersMapper.selectOne(orderWrapper);

        if (order == null) {
            return Result.badRequest("订单不存在");
        }

        // 校验订单归属
        if (!order.getUserId().equals(userId)) {
            return Result.badRequest("无权操作此订单");
        }

        // 校验订单状态：必须是待支付(0)
        if (order.getOrderStatus() == null || order.getOrderStatus() != Orders.Status.PENDING_PAYMENT) {
            return Result.badRequest("订单状态不允许支付");
        }

        // 检查是否已有已支付记录（幂等）
        LambdaQueryWrapper<PaymentRecord> existWrapper = new LambdaQueryWrapper<>();
        existWrapper.eq(PaymentRecord::getOrderNo, orderNo)
                .eq(PaymentRecord::getPayStatus, 1);
        PaymentRecord existRecord = paymentRecordMapper.selectOne(existWrapper);
        if (existRecord != null) {
            return Result.badRequest("订单已支付，请勿重复支付");
        }

        // 创建支付宝支付串（沙箱）
        String payInfo = alipayService.createAppPayOrder(
                orderNo,
                order.getTotalAmount(),
                "互联网护理服务订单",
                "订单号:" + orderNo
        );

        LocalDateTime now = LocalDateTime.now();

        // 记录待支付支付单（可重复创建，保留最新记录）
        PaymentRecord paymentRecord = PaymentRecord.builder()
                .orderId(order.getId())
                .orderNo(orderNo)
                .payMethod(payMethod)
                .payAmount(order.getTotalAmount())
                .payStatus(0)
                .tradeNo("PRE" + System.currentTimeMillis() + UUID.randomUUID().toString().substring(0, 4).toUpperCase())
                .callbackContent("创建支付单")
                .createTime(now)
                .updateTime(now)
                .build();
        paymentRecordMapper.insert(paymentRecord);

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("order_no", orderNo);
        data.put("pay_method", payMethod);
        data.put("pay_amount", order.getTotalAmount());
        data.put("pay_info", payInfo);
        data.put("expire_time", now.plusMinutes(30));

        log.info("创建支付单成功: orderNo={}, amount={}", orderNo, order.getTotalAmount());
        return Result.success("支付单创建成功", data);
    }

    /**
     * 确认支付结果（App 支付回调后调用）
     */
    @PostMapping("/confirm")
    @Transactional
    public Result<?> confirmPayment(@RequestBody Map<String, Object> body) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        String orderNo = body.get("orderNo") == null ? null : body.get("orderNo").toString();
        String tradeNo = body.get("tradeNo") == null ? null : body.get("tradeNo").toString();
        tradeNo = normalizeTradeNo(tradeNo);

        if (orderNo == null || orderNo.isBlank()) {
            return Result.badRequest("订单号不能为空");
        }

        LambdaQueryWrapper<Orders> orderWrapper = new LambdaQueryWrapper<>();
        orderWrapper.eq(Orders::getOrderNo, orderNo);
        Orders order = ordersMapper.selectOne(orderWrapper);
        if (order == null) {
            return Result.badRequest("订单不存在");
        }
        if (!order.getUserId().equals(userId)) {
            return Result.badRequest("无权操作此订单");
        }

        if (order.getPayStatus() != null && order.getPayStatus() == Orders.PayStatusEnum.PAID) {
            return Result.success("订单已支付", order);
        }

        if (!StringUtils.hasText(tradeNo)) {
            String tradeStatus = alipayService.queryPayStatus(orderNo);
            if (!isTradeSuccess(tradeStatus)) {
                return Result.error("支付处理中，请稍后重试");
            }
        }

        markOrderPaid(order, tradeNo, "App确认支付成功", userId, "USER", "用户支付成功确认");
        Orders refreshed = ordersMapper.selectById(order.getId());
        return Result.success("支付确认成功", refreshed);
    }

    /**
     * 查询支付状态
     */
    @GetMapping("/query/{orderNo}")
    public Result<?> queryPayment(@PathVariable String orderNo) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        // 查询订单归属
        LambdaQueryWrapper<Orders> orderWrapper = new LambdaQueryWrapper<>();
        orderWrapper.eq(Orders::getOrderNo, orderNo);
        Orders order = ordersMapper.selectOne(orderWrapper);

        if (order == null) {
            return Result.badRequest("订单不存在");
        }

        if (!order.getUserId().equals(userId)) {
            return Result.badRequest("无权查询此订单");
        }

        // 查询支付记录
        LambdaQueryWrapper<PaymentRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(PaymentRecord::getOrderNo, orderNo)
                .orderByDesc(PaymentRecord::getCreateTime)
                .last("LIMIT 1");
        PaymentRecord record = paymentRecordMapper.selectOne(wrapper);

        if (record == null || record.getPayStatus() == null || record.getPayStatus() != 1) {
            String tradeStatus = alipayService.queryPayStatus(orderNo);
            if (isTradeSuccess(tradeStatus)) {
                markOrderPaid(order, record != null ? record.getTradeNo() : null,
                        "查询支付状态后自动确认", userId, "USER", "查询支付状态后自动确认");
                record = paymentRecordMapper.selectOne(wrapper);
            }
        }

        if (record == null) {
            return Result.badRequest("暂无支付记录");
        }

        return Result.success(record);
    }

    /**
     * 支付宝异步通知回调（占位实现）
     */
    @PostMapping("/notify")
    public String notifyCallback(@RequestParam Map<String, String> params) {
        log.info("收到支付回调通知: {}", params);
        if (params == null || params.isEmpty()) {
            return "failure";
        }

        boolean verified = alipayService.verifyNotifySign(params);
        if (!verified) {
            log.warn("支付宝异步通知验签失败");
            return "failure";
        }

        String orderNo = params.get("out_trade_no");
        String tradeNo = params.get("trade_no");
        tradeNo = normalizeTradeNo(tradeNo);
        String tradeStatus = params.get("trade_status");

        if (!StringUtils.hasText(orderNo)) {
            return "failure";
        }

        if (isTradeSuccess(tradeStatus)) {
            Orders order = ordersMapper.selectOne(new LambdaQueryWrapper<Orders>()
                    .eq(Orders::getOrderNo, orderNo));
            if (order == null) {
                return "failure";
            }
            markOrderPaid(order, tradeNo, "支付宝异步通知", order.getUserId(), "SYSTEM", "支付宝异步通知支付成功");
        }
        return "success";
    }

    /**
     * 支付宝同步回调（占位实现）
     */
    @GetMapping("/return")
    public Result<?> returnCallback(@RequestParam Map<String, String> params) {
        String outTradeNo = params.get("out_trade_no");
        String tradeNo = params.get("trade_no");
        tradeNo = normalizeTradeNo(tradeNo);
        String totalAmount = params.get("total_amount");
        String tradeStatus = params.get("trade_status");

        if (!StringUtils.hasText(outTradeNo) && StringUtils.hasText(params.get("outTradeNo"))) {
            outTradeNo = params.get("outTradeNo");
        }

        if (!StringUtils.hasText(outTradeNo)) {
            return Result.badRequest("缺少订单号");
        }

        if (!isTradeSuccess(tradeStatus)) {
            String queriedStatus = alipayService.queryPayStatus(outTradeNo);
            if (isTradeSuccess(queriedStatus)) {
                tradeStatus = queriedStatus;
            }
        }

        if (isTradeSuccess(tradeStatus)) {
            Orders order = ordersMapper.selectOne(new LambdaQueryWrapper<Orders>()
                    .eq(Orders::getOrderNo, outTradeNo));
            if (order != null) {
                markOrderPaid(order, tradeNo, "支付宝同步回调", order.getUserId(), "SYSTEM", "支付宝同步回调支付成功");
            }
        }

        Orders latestOrder = ordersMapper.selectOne(new LambdaQueryWrapper<Orders>()
                .eq(Orders::getOrderNo, outTradeNo));
        boolean paid = latestOrder != null
                && latestOrder.getPayStatus() != null
                && latestOrder.getPayStatus() == Orders.PayStatusEnum.PAID;

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("outTradeNo", outTradeNo);
        data.put("tradeNo", tradeNo);
        data.put("totalAmount", totalAmount);
        data.put("tradeStatus", tradeStatus);
        data.put("paid", paid);
        if (paid) {
            return Result.success("支付成功", data);
        }
        return Result.error("支付未完成，请稍后在订单页刷新");
    }

    private boolean isTradeSuccess(String tradeStatus) {
        return "TRADE_SUCCESS".equals(tradeStatus) || "TRADE_FINISHED".equals(tradeStatus);
    }

    private void markOrderPaid(Orders order,
                               String tradeNo,
                               String callbackContent,
                               Long operatorUserId,
                               String operatorRole,
                               String logRemark) {
        LocalDateTime now = LocalDateTime.now();
        boolean wasPaid = order.getPayStatus() != null && order.getPayStatus() == Orders.PayStatusEnum.PAID;

        LambdaQueryWrapper<PaymentRecord> latestWrapper = new LambdaQueryWrapper<>();
        latestWrapper.eq(PaymentRecord::getOrderNo, order.getOrderNo())
                .orderByDesc(PaymentRecord::getCreateTime)
                .last("LIMIT 1");
        PaymentRecord latest = paymentRecordMapper.selectOne(latestWrapper);

        if (latest == null) {
            latest = PaymentRecord.builder()
                    .orderId(order.getId())
                    .orderNo(order.getOrderNo())
                    .payMethod(1)
                    .payAmount(order.getTotalAmount())
                    .createTime(now)
                    .build();
        }

        latest.setPayStatus(1);
        latest.setPayTime(now);
        latest.setUpdateTime(now);
        latest.setCallbackContent(callbackContent);
        String normalizedTradeNo = normalizeTradeNo(tradeNo);
        if (StringUtils.hasText(normalizedTradeNo)) {
            latest.setTradeNo(normalizedTradeNo);
        }

        if (latest.getId() == null) {
            paymentRecordMapper.insert(latest);
        } else {
            paymentRecordMapper.updateById(latest);
        }

        Integer oldStatus = order.getOrderStatus();
        int newStatus = oldStatus != null && oldStatus == Orders.Status.PENDING_PAYMENT
                ? Orders.Status.PENDING_ACCEPT
                : (oldStatus == null ? Orders.Status.PENDING_ACCEPT : oldStatus);

        order.setOrderStatus(newStatus);
        order.setPayStatus(Orders.PayStatusEnum.PAID);
        order.setPayMethod(latest.getPayMethod() == null ? 1 : latest.getPayMethod());
        order.setPayTime(now);
        order.setUpdateTime(now);
        ordersMapper.updateById(order);

        if (oldStatus == null || oldStatus != newStatus) {
            orderStatusLogMapper.insert(OrderStatusLog.builder()
                    .orderId(order.getId())
                    .orderNo(order.getOrderNo())
                    .oldStatus(oldStatus == null ? -1 : oldStatus)
                    .newStatus(newStatus)
                    .operatorUserId(operatorUserId)
                    .operatorRole(operatorRole)
                    .remark(logRemark)
                    .createTime(now)
                    .build());
        }

        if (!wasPaid) {
            createPaymentSuccessNotification(order, now);
        }
    }

    private void createPaymentSuccessNotification(Orders order, LocalDateTime now) {
        String bizId = String.valueOf(order.getId());
        Long exists = notificationMapper.selectCount(new LambdaQueryWrapper<Notification>()
                .eq(Notification::getReceiverUserId, order.getUserId())
                .eq(Notification::getBizType, "PAY")
                .eq(Notification::getBizId, bizId));

        if (exists != null && exists > 0) {
            return;
        }

        notificationMapper.insert(Notification.builder()
                .receiverUserId(order.getUserId())
                .receiverRole("USER")
                .title("支付成功")
                .content("订单（" + order.getOrderNo() + "）支付成功，等待护士接单。")
                .bizType("PAY")
                .bizId(bizId)
                .readFlag(0)
                .createTime(now)
                .build());
    }

    private String normalizeTradeNo(String rawTradeNo) {
        if (!StringUtils.hasText(rawTradeNo)) {
            return null;
        }

        String input = rawTradeNo.trim();

        if (input.startsWith("{") && input.contains("trade_no")) {
            Matcher jsonMatcher = Pattern.compile("\\\"trade_no\\\"\\s*:\\s*\\\"([^\\\"]+)\\\"").matcher(input);
            if (jsonMatcher.find()) {
                input = jsonMatcher.group(1);
            }
        }

        if ((input.contains("trade_no=") || input.contains("tradeNo=")) && input.contains("&")) {
            Matcher queryMatcher = Pattern.compile("(?:^|[&;])(trade_no|tradeNo)=([^&;]+)").matcher(input);
            if (queryMatcher.find()) {
                input = queryMatcher.group(2);
            }
        }

        if (input.length() > MAX_TRADE_NO_LENGTH) {
            input = input.substring(0, MAX_TRADE_NO_LENGTH);
        }
        return input;
    }
}
