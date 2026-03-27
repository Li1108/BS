package com.nursing.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.nursing.common.Result;
import com.nursing.dto.order.CancelOrderRequest;
import com.nursing.dto.order.CreateOrderRequest;
import com.nursing.dto.order.OrderVO;
import com.nursing.entity.FileAttachment;
import com.nursing.entity.OrderStatusLog;
import com.nursing.entity.PaymentRecord;
import com.nursing.entity.RefundRecord;
import com.nursing.entity.EmergencyCall;
import com.nursing.entity.ServiceCheckinPhoto;
import com.nursing.mapper.EmergencyCallMapper;
import com.nursing.mapper.FileAttachmentMapper;
import com.nursing.mapper.OrderStatusLogMapper;
import com.nursing.mapper.PaymentRecordMapper;
import com.nursing.mapper.RefundRecordMapper;
import com.nursing.mapper.ServiceCheckinPhotoMapper;
import com.nursing.service.OrderService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 订单控制器
 * 仅包含用户侧订单操作，支付相关接口在 PaymentController
 */
@Slf4j
@RestController
@RequestMapping("/order")
@RequiredArgsConstructor
@Tag(name = "订单模块", description = "订单创建、查询、取消相关接口")
public class OrderController {

    private static final String BIZ_TYPE_NURSE_ARRIVE = "nurse_arrive";
    private static final String BIZ_TYPE_NURSE_START = "nurse_start";
    private static final String BIZ_TYPE_NURSE_FINISH = "nurse_finish";

    private final OrderService orderService;
    private final OrderStatusLogMapper orderStatusLogMapper;
    private final PaymentRecordMapper paymentRecordMapper;
    private final RefundRecordMapper refundRecordMapper;
    private final EmergencyCallMapper emergencyCallMapper;
    private final ServiceCheckinPhotoMapper serviceCheckinPhotoMapper;
    private final FileAttachmentMapper fileAttachmentMapper;

    /**
     * 创建订单
     * POST /api/order/create
     */
    @PostMapping("/create")
    @Operation(summary = "创建订单", description = "用户选择服务后创建订单")
    public Result<OrderVO> createOrder(@Valid @RequestBody CreateOrderRequest request) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        try {
            OrderVO order = orderService.createOrder(userId, request);
            return Result.success("订单创建成功", order);
        } catch (RuntimeException e) {
            log.warn("创建订单失败: {}", e.getMessage());
            return Result.error(e.getMessage());
        }
    }

    /**
     * 获取用户订单列表
     * GET /api/order/list?status=&pageNo=&pageSize=
     */
    @GetMapping("/list")
    @Operation(summary = "我的订单", description = "获取当前用户的订单列表")
    public Result<IPage<OrderVO>> getMyOrders(
            @Parameter(description = "订单状态") @RequestParam(required = false) Integer status,
            @Parameter(description = "页码") @RequestParam(defaultValue = "1") int pageNo,
            @Parameter(description = "每页数量") @RequestParam(defaultValue = "10") int pageSize) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        IPage<OrderVO> orders = orderService.getUserOrders(userId, status, pageNo, pageSize);
        return Result.success(orders);
    }

    /**
     * 获取订单详情（通过订单号）
     * GET /api/order/detail/{orderNo}
     */
    @GetMapping("/detail/{orderNo}")
    @Operation(summary = "订单详情", description = "根据订单号获取订单详细信息")
    public Result<OrderVO> getOrderDetail(@PathVariable String orderNo) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        try {
            OrderVO order = orderService.getOrderByOrderNo(orderNo);
            if (order == null) {
                return Result.notFound("订单不存在");
            }
            // 校验订单归属
            if (!userId.equals(order.getUserId())) {
                return Result.forbidden("无权查看此订单");
            }
            return Result.success(order);
        } catch (RuntimeException e) {
            return Result.error(e.getMessage());
        }
    }

    /**
     * 获取订单流程时间轴
     * GET /api/order/timeline/{orderNo}
     */
    @GetMapping("/timeline/{orderNo}")
    @Operation(summary = "订单流程时间轴", description = "获取下单到完成的流程节点")
    public Result<List<OrderStatusLog>> getOrderTimeline(@PathVariable String orderNo) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        OrderVO order = orderService.getOrderByOrderNo(orderNo);
        if (order == null) {
            return Result.notFound("订单不存在");
        }
        if (!userId.equals(order.getUserId())) {
            return Result.forbidden("无权查看此订单");
        }

        List<OrderStatusLog> logs = orderStatusLogMapper.selectList(
                new LambdaQueryWrapper<OrderStatusLog>()
                        .eq(OrderStatusLog::getOrderNo, orderNo)
                        .orderByAsc(OrderStatusLog::getCreateTime)
        );
        return Result.success(logs);
    }

    /**
     * 获取订单全链路详情（用户侧）
     * GET /api/order/flow/{orderNo}
     */
    @GetMapping("/flow/{orderNo}")
    @Operation(summary = "订单全链路详情", description = "获取订单状态流、支付退款与SOS记录")
    public Result<Map<String, Object>> getOrderFlow(@PathVariable String orderNo) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        OrderVO order = orderService.getOrderByOrderNo(orderNo);
        if (order == null) {
            return Result.notFound("订单不存在");
        }
        if (!userId.equals(order.getUserId())) {
            return Result.forbidden("无权查看此订单");
        }

        List<OrderStatusLog> statusLogs = orderStatusLogMapper.selectList(
                new LambdaQueryWrapper<OrderStatusLog>()
                        .eq(OrderStatusLog::getOrderNo, orderNo)
                        .orderByAsc(OrderStatusLog::getCreateTime)
        );

        List<PaymentRecord> paymentRecords = paymentRecordMapper.selectList(
                new LambdaQueryWrapper<PaymentRecord>()
                        .eq(PaymentRecord::getOrderNo, orderNo)
                        .orderByDesc(PaymentRecord::getCreateTime)
        );

        List<RefundRecord> refundRecords = refundRecordMapper.selectList(
                new LambdaQueryWrapper<RefundRecord>()
                        .eq(RefundRecord::getOrderNo, orderNo)
                        .orderByDesc(RefundRecord::getCreateTime)
        );

        List<EmergencyCall> sosRecords = emergencyCallMapper.selectList(
                new LambdaQueryWrapper<EmergencyCall>()
                        .eq(EmergencyCall::getOrderNo, orderNo)
                        .orderByDesc(EmergencyCall::getCreateTime)
        );

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("orderNo", orderNo);
        result.put("orderId", order.getId());
        result.put("statusLogs", statusLogs);
        result.put("paymentRecords", paymentRecords);
        result.put("refundRecords", refundRecords);
        result.put("sosRecords", sosRecords);
        return Result.success(result);
    }

    /**
     * 获取订单打卡照片
     * GET /api/order/checkinPhotos/{orderNo}
     */
    @GetMapping("/checkinPhotos/{orderNo}")
    @Operation(summary = "订单打卡照片", description = "获取到达/开始/完成打卡照片")
    public Result<List<ServiceCheckinPhoto>> getOrderCheckinPhotos(@PathVariable String orderNo) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        OrderVO order = orderService.getOrderByOrderNo(orderNo);
        if (order == null) {
            return Result.notFound("订单不存在");
        }
        if (!userId.equals(order.getUserId())) {
            return Result.forbidden("无权查看此订单");
        }

        List<ServiceCheckinPhoto> photos = serviceCheckinPhotoMapper.selectList(
                new LambdaQueryWrapper<ServiceCheckinPhoto>()
                        .eq(ServiceCheckinPhoto::getOrderNo, orderNo)
                        .orderByAsc(ServiceCheckinPhoto::getCheckinType)
        );

        if (photos == null || photos.isEmpty()) {
            Map<String, Integer> bizTypeMap = Map.of(
                BIZ_TYPE_NURSE_ARRIVE, 1,
                BIZ_TYPE_NURSE_START, 2,
                BIZ_TYPE_NURSE_FINISH, 3
            );

            List<FileAttachment> attachments = fileAttachmentMapper.selectList(
                new LambdaQueryWrapper<FileAttachment>()
                    .eq(FileAttachment::getBizId, orderNo)
                    .in(FileAttachment::getBizType, bizTypeMap.keySet())
                    .orderByAsc(FileAttachment::getCreateTime)
            );

            if (attachments != null && !attachments.isEmpty()) {
            photos = attachments.stream()
                .map(item -> ServiceCheckinPhoto.builder()
                    .orderNo(orderNo)
                    .checkinType(bizTypeMap.getOrDefault(item.getBizType(), 0))
                    .photoUrl(item.getFilePath())
                    .createTime(item.getCreateTime())
                    .build())
                .collect(Collectors.toList());
            }
        }
        return Result.success(photos);
    }

    /**
     * 取消订单（通过订单号）
     * POST /api/order/cancel/{orderNo}
     */
    @PostMapping("/cancel/{orderNo}")
    @Operation(summary = "取消订单", description = "取消未接单的订单，已支付订单会发起退款")
    public Result<Void> cancelOrder(@PathVariable String orderNo,
                                    @Valid @RequestBody CancelOrderRequest request) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        try {
            // 先通过订单号查到订单，获取orderId
            OrderVO order = orderService.getOrderByOrderNo(orderNo);
            if (order == null) {
                return Result.notFound("订单不存在");
            }
            if (!userId.equals(order.getUserId())) {
                return Result.forbidden("无权操作此订单");
            }
            orderService.cancelOrder(userId, order.getId(), request.getCancelReason());
            return Result.success("订单已取消", null);
        } catch (RuntimeException e) {
            log.warn("取消订单失败: orderNo={}, error={}", orderNo, e.getMessage());
            return Result.error(e.getMessage());
        }
    }

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
