package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.nursing.common.Result;
import com.nursing.entity.Orders;
import com.nursing.entity.RefundRecord;
import com.nursing.mapper.OrdersMapper;
import com.nursing.mapper.RefundRecordMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.Map;

/**
 * 退款控制器
 */
@Slf4j
@RestController
@RequestMapping("/refund")
@RequiredArgsConstructor
public class RefundController {

    private final OrdersMapper ordersMapper;
    private final RefundRecordMapper refundRecordMapper;

    /**
     * 用户申请退款
     */
    @PostMapping("/apply")
    @Transactional
    public Result<?> applyRefund(@RequestBody Map<String, Object> body) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        String orderNo = (String) body.get("orderNo");
        String reason = (String) body.get("reason");

        if (orderNo == null || orderNo.isBlank()) {
            return Result.badRequest("订单号不能为空");
        }
        if (reason == null || reason.isBlank()) {
            return Result.badRequest("退款原因不能为空");
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

        // 校验订单状态：允许退款的状态为 1(待接单) 或 2(已派单)
        int status = order.getOrderStatus() != null ? order.getOrderStatus() : -1;
        if (status != Orders.Status.PENDING_ACCEPT && status != Orders.Status.DISPATCHED) {
            return Result.badRequest("当前订单状态不允许申请退款");
        }

        // 检查是否已有退款记录（幂等）
        LambdaQueryWrapper<RefundRecord> existWrapper = new LambdaQueryWrapper<>();
        existWrapper.eq(RefundRecord::getOrderNo, orderNo)
                .in(RefundRecord::getRefundStatus, 0, 1); // 待处理或已退款
        RefundRecord existRecord = refundRecordMapper.selectOne(existWrapper);
        if (existRecord != null) {
            return Result.badRequest("已存在退款申请，请勿重复提交");
        }

        LocalDateTime now = LocalDateTime.now();

        // 创建退款记录
        RefundRecord refundRecord = RefundRecord.builder()
                .orderId(order.getId())
                .orderNo(orderNo)
                .refundAmount(order.getTotalAmount())
                .refundStatus(0) // 待处理
                .refundReason(reason)
                .createTime(now)
                .updateTime(now)
                .build();
        refundRecordMapper.insert(refundRecord);

        // 更新订单状态为退款中(9)
        order.setOrderStatus(Orders.Status.REFUNDING);
        order.setUpdateTime(now);
        ordersMapper.updateById(order);

        log.info("用户申请退款: orderNo={}, reason={}, refundAmount={}", orderNo, reason, order.getTotalAmount());

        return Result.success("退款申请已提交", refundRecord);
    }

    /**
     * 查询退款状态
     */
    @GetMapping("/query/{orderNo}")
    public Result<?> queryRefund(@PathVariable String orderNo) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        // 校验订单归属
        LambdaQueryWrapper<Orders> orderWrapper = new LambdaQueryWrapper<>();
        orderWrapper.eq(Orders::getOrderNo, orderNo);
        Orders order = ordersMapper.selectOne(orderWrapper);

        if (order == null) {
            return Result.badRequest("订单不存在");
        }

        if (!order.getUserId().equals(userId)) {
            return Result.badRequest("无权查询此订单");
        }

        // 查询退款记录
        LambdaQueryWrapper<RefundRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(RefundRecord::getOrderNo, orderNo)
                .orderByDesc(RefundRecord::getCreateTime)
                .last("LIMIT 1");
        RefundRecord record = refundRecordMapper.selectOne(wrapper);

        if (record == null) {
            return Result.badRequest("暂无退款记录");
        }

        return Result.success(record);
    }
}
