package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.OperationLog;
import com.nursing.entity.Orders;
import com.nursing.entity.RefundRecord;
import com.nursing.mapper.OperationLogMapper;
import com.nursing.mapper.OrdersMapper;
import com.nursing.mapper.RefundRecordMapper;
import com.nursing.service.AlipayService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;

/**
 * 管理员 - 退款管理
 */
@Slf4j
@RestController
@RequestMapping("/admin/refund")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminRefundController {

    private final RefundRecordMapper refundRecordMapper;
    private final OrdersMapper ordersMapper;
    private final OperationLogMapper operationLogMapper;
    private final AlipayService alipayService;

    /**
     * 退款记录列表（分页 + 多条件筛选）
     */
    @GetMapping("/list")
    public Result<?> list(@RequestParam(required = false) String orderNo,
                          @RequestParam(required = false) Integer refundStatus,
                          @RequestParam(defaultValue = "1") Integer pageNo,
                          @RequestParam(defaultValue = "10") Integer pageSize) {
        Page<RefundRecord> page = new Page<>(pageNo, pageSize);
        LambdaQueryWrapper<RefundRecord> wrapper = new LambdaQueryWrapper<>();

        if (StringUtils.hasText(orderNo)) {
            wrapper.like(RefundRecord::getOrderNo, orderNo);
        }
        if (refundStatus != null) {
            wrapper.eq(RefundRecord::getRefundStatus, refundStatus);
        }

        wrapper.orderByDesc(RefundRecord::getCreateTime);
        return Result.success(refundRecordMapper.selectPage(page, wrapper));
    }

    /**
     * 退款记录详情（按订单号查询）
     */
    @GetMapping("/detail/{orderNo}")
    public Result<?> detail(@PathVariable String orderNo) {
        LambdaQueryWrapper<RefundRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(RefundRecord::getOrderNo, orderNo);
        RefundRecord record = refundRecordMapper.selectOne(wrapper);
        if (record == null) {
            return Result.notFound("退款记录不存在");
        }
        return Result.success(record);
    }

    /**
     * 审批通过退款
     * 设置 refundStatus=1（退款成功），订单状态改为10（已退款）
     */
    @PostMapping("/approve/{orderNo}")
    @Transactional
    public Result<?> approve(@PathVariable String orderNo,
                             @RequestBody Map<String, String> body,
                             HttpServletRequest request) {
        String remark = body != null ? body.get("remark") : null;

        // 查询退款记录
        LambdaQueryWrapper<RefundRecord> refundWrapper = new LambdaQueryWrapper<>();
        refundWrapper.eq(RefundRecord::getOrderNo, orderNo);
        RefundRecord refund = refundRecordMapper.selectOne(refundWrapper);
        if (refund == null) {
            return Result.notFound("退款记录不存在");
        }
        if (refund.getRefundStatus() != 0) {
            return Result.badRequest("该退款记录已处理，不可重复操作");
        }

        // 查询订单
        LambdaQueryWrapper<Orders> orderWrapper = new LambdaQueryWrapper<>();
        orderWrapper.eq(Orders::getOrderNo, orderNo);
        Orders order = ordersMapper.selectOne(orderWrapper);
        if (order == null) {
            return Result.notFound("订单不存在");
        }

        BigDecimal refundAmount = refund.getRefundAmount() != null ? refund.getRefundAmount() : order.getTotalAmount();
        String refundNo = "RFD" + System.currentTimeMillis() + UUID.randomUUID().toString().replace("-", "").substring(0, 6).toUpperCase();
        boolean refundSuccess = alipayService.refund(
                orderNo,
                refundNo,
                refundAmount,
                StringUtils.hasText(remark) ? remark : "管理员审核通过退款"
        );
        if (!refundSuccess) {
            log.warn("管理员退款审批调用支付宝失败: orderNo={}", orderNo);
            return Result.error("支付宝退款失败，请检查支付宝配置或稍后重试");
        }

        // 更新退款记录状态为成功
        refund.setRefundStatus(1);
        refund.setThirdRefundNo(refundNo);
        refund.setUpdateTime(LocalDateTime.now());
        refundRecordMapper.updateById(refund);

        // 更新订单状态为已退款（10）
        order.setOrderStatus(Orders.Status.REFUNDED);
        order.setPayStatus(Orders.PayStatusEnum.REFUNDED);
        order.setRefundAmount(refundAmount);
        order.setUpdateTime(LocalDateTime.now());
        ordersMapper.updateById(order);

        // 写操作日志
        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("APPROVE_REFUND")
                .actionDesc("审批通过退款，orderNo=" + orderNo + "，备注：" + remark)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("orderNo=" + orderNo + ", remark=" + remark)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]审批通过退款并调用支付宝成功，orderNo={}, refundNo={}", adminUserId, orderNo, refundNo);
        return Result.success("退款审批通过");
    }

    /**
     * 驳回退款
     * 设置 refundStatus=2（退款失败）
     */
    @PostMapping("/reject/{orderNo}")
    @Transactional
    public Result<?> reject(@PathVariable String orderNo,
                            @RequestBody Map<String, String> body,
                            HttpServletRequest request) {
        String remark = body.get("remark");

        // 查询退款记录
        LambdaQueryWrapper<RefundRecord> refundWrapper = new LambdaQueryWrapper<>();
        refundWrapper.eq(RefundRecord::getOrderNo, orderNo);
        RefundRecord refund = refundRecordMapper.selectOne(refundWrapper);
        if (refund == null) {
            return Result.notFound("退款记录不存在");
        }
        if (refund.getRefundStatus() != 0) {
            return Result.badRequest("该退款记录已处理，不可重复操作");
        }

        // 更新退款记录状态为失败
        refund.setRefundStatus(2);
        refund.setUpdateTime(LocalDateTime.now());
        refundRecordMapper.updateById(refund);

        // 写操作日志
        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("REJECT_REFUND")
                .actionDesc("驳回退款，orderNo=" + orderNo + "，备注：" + remark)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("orderNo=" + orderNo + ", remark=" + remark)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]驳回退款，orderNo={}", adminUserId, orderNo);
        return Result.success("退款已驳回");
    }
}
