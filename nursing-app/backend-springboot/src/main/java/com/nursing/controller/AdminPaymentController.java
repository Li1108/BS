package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.PaymentRecord;
import com.nursing.entity.RefundRecord;
import com.nursing.mapper.PaymentRecordMapper;
import com.nursing.mapper.RefundRecordMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 管理员 - 支付记录管理
 */
@Slf4j
@RestController
@RequestMapping("/admin/payment")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminPaymentController {

    private final PaymentRecordMapper paymentRecordMapper;
    private final RefundRecordMapper refundRecordMapper;

    /**
     * 支付记录列表（分页 + 多条件筛选）
     */
    @GetMapping("/list")
    public Result<?> list(@RequestParam(required = false) String orderNo,
                          @RequestParam(required = false) String tradeNo,
                          @RequestParam(required = false) Integer payStatus,
                          @RequestParam(required = false) Integer payMethod,
                          @RequestParam(defaultValue = "1") Integer pageNo,
                          @RequestParam(defaultValue = "10") Integer pageSize) {
        Page<PaymentRecord> page = new Page<>(pageNo, pageSize);
        LambdaQueryWrapper<PaymentRecord> wrapper = new LambdaQueryWrapper<>();

        if (StringUtils.hasText(orderNo)) {
            wrapper.like(PaymentRecord::getOrderNo, orderNo);
        }
        if (StringUtils.hasText(tradeNo)) {
            wrapper.like(PaymentRecord::getTradeNo, tradeNo);
        }
        if (payStatus != null) {
            wrapper.eq(PaymentRecord::getPayStatus, payStatus);
        }
        if (payMethod != null) {
            wrapper.eq(PaymentRecord::getPayMethod, payMethod);
        }

        wrapper.orderByDesc(PaymentRecord::getCreateTime);
        return Result.success(paymentRecordMapper.selectPage(page, wrapper));
    }

    /**
     * 支付记录详情（按订单号查询）
     */
    @GetMapping("/detail/{orderNo}")
    public Result<?> detail(@PathVariable String orderNo) {
        LambdaQueryWrapper<PaymentRecord> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(PaymentRecord::getOrderNo, orderNo);
        PaymentRecord record = paymentRecordMapper.selectOne(wrapper);
        if (record == null) {
            return Result.notFound("支付记录不存在");
        }
        return Result.success(record);
    }

    /**
     * 支付退款对账
     */
    @GetMapping("/reconcile")
    public Result<?> reconcile(@RequestParam(required = false) String orderNo,
                               @RequestParam(defaultValue = "1") Integer pageNo,
                               @RequestParam(defaultValue = "10") Integer pageSize) {
        Page<PaymentRecord> page = paymentRecordMapper.selectPage(
                new Page<>(pageNo, pageSize),
                new LambdaQueryWrapper<PaymentRecord>()
                        .like(StringUtils.hasText(orderNo), PaymentRecord::getOrderNo, orderNo)
                        .orderByDesc(PaymentRecord::getCreateTime)
        );

        List<Map<String, Object>> rows = new ArrayList<>();
        for (PaymentRecord payment : page.getRecords()) {
            RefundRecord refund = refundRecordMapper.selectOne(
                    new LambdaQueryWrapper<RefundRecord>()
                            .eq(RefundRecord::getOrderNo, payment.getOrderNo())
                            .last("limit 1")
            );

            Map<String, Object> row = new LinkedHashMap<>();
            row.put("orderNo", payment.getOrderNo());
            row.put("payAmount", payment.getPayAmount());
            row.put("payStatus", payment.getPayStatus());
            row.put("payTime", payment.getPayTime());
            row.put("tradeNo", payment.getTradeNo());
            row.put("refundAmount", refund == null ? null : refund.getRefundAmount());
            row.put("refundStatus", refund == null ? null : refund.getRefundStatus());
            row.put("refundTime", refund == null ? null : refund.getUpdateTime());
            boolean amountMatched = refund == null || (payment.getPayAmount() != null
                    && refund.getRefundAmount() != null
                    && payment.getPayAmount().compareTo(refund.getRefundAmount()) >= 0);
            row.put("reconcileStatus", amountMatched ? "MATCHED" : "MISMATCH");
            rows.add(row);
        }

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("records", rows);
        data.put("total", page.getTotal());
        data.put("current", page.getCurrent());
        data.put("size", page.getSize());
        return Result.success(data);
    }
}
