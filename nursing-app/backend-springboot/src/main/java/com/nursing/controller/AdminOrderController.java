package com.nursing.controller;

import com.alibaba.excel.EasyExcel;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.dto.admin.AdminOrderVO;
import com.nursing.dto.admin.OrderExportDTO;
import com.nursing.entity.FileAttachment;
import com.nursing.entity.NurseProfile;
import com.nursing.entity.Notification;
import com.nursing.entity.OperationLog;
import com.nursing.entity.Orders;
import com.nursing.entity.RefundRecord;
import com.nursing.entity.PaymentRecord;
import com.nursing.entity.OrderStatusLog;
import com.nursing.entity.OrderAssignLog;
import com.nursing.entity.EmergencyCall;
import com.nursing.entity.SysUser;
import com.nursing.mapper.FileAttachmentMapper;
import com.nursing.mapper.NurseProfileMapper;
import com.nursing.mapper.NotificationMapper;
import com.nursing.mapper.OperationLogMapper;
import com.nursing.mapper.OrdersMapper;
import com.nursing.mapper.RefundRecordMapper;
import com.nursing.mapper.PaymentRecordMapper;
import com.nursing.mapper.OrderStatusLogMapper;
import com.nursing.mapper.OrderAssignLogMapper;
import com.nursing.mapper.EmergencyCallMapper;
import com.nursing.mapper.SysUserMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * 管理员 - 订单管理
 */
@Slf4j
@RestController
@RequestMapping("/admin/order")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminOrderController {

    private static final BigDecimal PLATFORM_FEE_RATE = new BigDecimal("0.20");
    private static final Pattern PHONE_PATTERN = Pattern.compile("^1[3-9]\\d{9}$");
    private static final String BIZ_TYPE_NURSE_ARRIVE = "nurse_arrive";
    private static final String BIZ_TYPE_NURSE_START = "nurse_start";
    private static final String BIZ_TYPE_NURSE_FINISH = "nurse_finish";

    private final OrdersMapper ordersMapper;
    private final SysUserMapper sysUserMapper;
    private final FileAttachmentMapper fileAttachmentMapper;
    private final NurseProfileMapper nurseProfileMapper;
    private final RefundRecordMapper refundRecordMapper;
    private final PaymentRecordMapper paymentRecordMapper;
    private final OrderStatusLogMapper orderStatusLogMapper;
    private final OrderAssignLogMapper orderAssignLogMapper;
    private final EmergencyCallMapper emergencyCallMapper;
    private final NotificationMapper notificationMapper;
    private final OperationLogMapper operationLogMapper;

    /**
     * 订单列表（分页 + 多条件筛选）
     */
    @GetMapping("/list")
    public Result<?> list(@RequestParam(required = false) String orderNo,
                          @RequestParam(required = false) String userPhone,
                          @RequestParam(required = false) String nursePhone,
                          @RequestParam(required = false) Integer orderStatus,
                          @RequestParam(required = false) Integer payStatus,
                          @RequestParam(defaultValue = "1") Integer pageNo,
                          @RequestParam(defaultValue = "10") Integer pageSize) {
        Page<Orders> page = new Page<>(pageNo, pageSize);
        LambdaQueryWrapper<Orders> wrapper = buildOrderWrapper(orderNo, userPhone, nursePhone, orderStatus, payStatus, null);
        IPage<Orders> rawPage = ordersMapper.selectPage(page, wrapper);

        Page<AdminOrderVO> voPage = new Page<>(pageNo, pageSize, rawPage.getTotal());
        voPage.setRecords(buildOrderVOList(rawPage.getRecords()));
        return Result.success(voPage);
    }

    /**
     * 订单详情
     */
    @GetMapping("/detail/{orderNo}")
    public Result<?> detail(@PathVariable String orderNo) {
        Orders order = ordersMapper.selectOne(new LambdaQueryWrapper<Orders>().eq(Orders::getOrderNo, orderNo));
        if (order == null) {
            return Result.notFound("订单不存在");
        }
        List<AdminOrderVO> voList = buildOrderVOList(Collections.singletonList(order));
        return Result.success(voList.isEmpty() ? null : voList.get(0));
    }

        /**
         * 订单全链路明细（状态流 + 派单 + 支付退款 + SOS）
         */
        @GetMapping("/flow/{orderNo}")
        public Result<?> flow(@PathVariable String orderNo) {
        Orders order = ordersMapper.selectOne(new LambdaQueryWrapper<Orders>().eq(Orders::getOrderNo, orderNo));
        if (order == null) {
            return Result.notFound("订单不存在");
        }

        List<OrderStatusLog> statusLogs = orderStatusLogMapper.selectList(
            new LambdaQueryWrapper<OrderStatusLog>()
                .eq(OrderStatusLog::getOrderNo, orderNo)
                .orderByAsc(OrderStatusLog::getCreateTime)
        );

        List<OrderAssignLog> assignLogs = orderAssignLogMapper.selectList(
            new LambdaQueryWrapper<OrderAssignLog>()
                .eq(OrderAssignLog::getOrderNo, orderNo)
                .orderByAsc(OrderAssignLog::getCreateTime)
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
        result.put("orderStatus", order.getOrderStatus());
        result.put("payStatus", order.getPayStatus());
        result.put("statusLogs", statusLogs);
        result.put("assignLogs", assignLogs);
        result.put("paymentRecords", paymentRecords);
        result.put("refundRecords", refundRecords);
        result.put("sosRecords", sosRecords);
        return Result.success(result);
        }

    /**
     * 取消订单
     */
    @PostMapping("/cancel/{orderNo}")
    @Transactional
    public Result<?> cancel(@PathVariable String orderNo,
                            @RequestBody Map<String, String> body,
                            HttpServletRequest request) {
        String reason = body.get("reason");
        String cancelReason = StringUtils.hasText(reason) ? reason : "管理员取消订单";
        Orders order = ordersMapper.selectOne(new LambdaQueryWrapper<Orders>().eq(Orders::getOrderNo, orderNo));
        if (order == null) {
            return Result.notFound("订单不存在");
        }

        int status = order.getOrderStatus();
        if (status == Orders.Status.CANCELLED || status == Orders.Status.REFUNDED
                || status == Orders.Status.REFUNDING || status == Orders.Status.COMPLETED
                || status == Orders.Status.EVALUATED) {
            return Result.badRequest("当前订单状态不允许取消");
        }

        LocalDateTime now = LocalDateTime.now();
        boolean paid = order.getPayStatus() != null && order.getPayStatus() == Orders.PayStatusEnum.PAID;

        if (paid) {
            RefundRecord existing = refundRecordMapper.selectOne(
                    new LambdaQueryWrapper<RefundRecord>().eq(RefundRecord::getOrderNo, orderNo)
            );
            if (existing == null) {
                refundRecordMapper.insert(RefundRecord.builder()
                        .orderId(order.getId())
                        .orderNo(orderNo)
                        .refundAmount(order.getTotalAmount())
                        .refundStatus(1)
                        .refundReason(cancelReason)
                        .createTime(now)
                        .updateTime(now)
                        .build());
            } else {
                existing.setRefundStatus(1);
                existing.setRefundAmount(order.getTotalAmount());
                existing.setRefundReason(cancelReason);
                existing.setUpdateTime(now);
                refundRecordMapper.updateById(existing);
            }

            order.setOrderStatus(Orders.Status.REFUNDED);
            order.setPayStatus(Orders.PayStatusEnum.REFUNDED);
            order.setRefundAmount(order.getTotalAmount());
        } else {
            order.setOrderStatus(Orders.Status.CANCELLED);
        }

        order.setCancelReason(cancelReason);
        order.setCancelTime(now);
        order.setUpdateTime(now);
        ordersMapper.updateById(order);

        writeStatusLog(order, status, order.getOrderStatus(), adminUserIdSafe(), "ADMIN_SUPER", "管理员取消订单：" + cancelReason);

        if (paid) {
            notificationMapper.insert(Notification.builder()
                    .receiverUserId(order.getUserId())
                    .receiverRole("USER")
                    .title("订单已取消并退款")
                    .content("您的订单（" + orderNo + "）已取消，退款金额 "
                            + (order.getTotalAmount() == null ? "0.00" : order.getTotalAmount().toPlainString())
                            + " 元，将原路退回。")
                    .bizType("REFUND")
                    .bizId(orderNo)
                    .readFlag(0)
                    .createTime(now)
                    .build());
        }

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("CANCEL_ORDER")
                .actionDesc("取消订单，orderNo=" + orderNo + "，原因：" + cancelReason
                    + (paid ? "，已自动退款" : ""))
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("orderNo=" + orderNo + ", reason=" + cancelReason)
                .ip(request.getRemoteAddr())
                .createTime(now)
                .build());

            log.info("管理员[{}]取消订单[{}]，原因：{}，paid={} ", adminUserId, orderNo, cancelReason, paid);
            return Result.success(paid ? "订单已取消并自动退款" : "订单已取消");
    }

    /**
     * 退款操作（幂等）
     */
    @PostMapping("/refund/{orderNo}")
    public Result<?> refund(@PathVariable String orderNo,
                            @RequestBody Map<String, String> body,
                            HttpServletRequest request) {
        String reason = body.get("reason");
        Orders order = ordersMapper.selectOne(new LambdaQueryWrapper<Orders>().eq(Orders::getOrderNo, orderNo));
        if (order == null) {
            return Result.notFound("订单不存在");
        }
        if (order.getPayStatus() == null || order.getPayStatus() == Orders.PayStatusEnum.UNPAID) {
            return Result.badRequest("订单未支付，无法退款");
        }

        RefundRecord existing = refundRecordMapper.selectOne(
                new LambdaQueryWrapper<RefundRecord>().eq(RefundRecord::getOrderNo, orderNo)
        );
        if (existing == null) {
            refundRecordMapper.insert(RefundRecord.builder()
                    .orderId(order.getId())
                    .orderNo(orderNo)
                    .refundAmount(order.getTotalAmount())
                    .refundStatus(1)
                    .refundReason(reason)
                    .createTime(LocalDateTime.now())
                    .updateTime(LocalDateTime.now())
                    .build());
        } else {
            existing.setRefundStatus(1);
            if (StringUtils.hasText(reason)) {
                existing.setRefundReason(reason);
            }
            existing.setUpdateTime(LocalDateTime.now());
            refundRecordMapper.updateById(existing);
        }

        Integer oldStatus = order.getOrderStatus();
        order.setOrderStatus(Orders.Status.REFUNDED);
        order.setPayStatus(Orders.PayStatusEnum.REFUNDED);
        order.setRefundAmount(order.getTotalAmount());
        order.setUpdateTime(LocalDateTime.now());
        ordersMapper.updateById(order);

        writeStatusLog(order, oldStatus, Orders.Status.REFUNDED, adminUserIdSafe(), "ADMIN_SUPER", "管理员退款：" + reason);

        notificationMapper.insert(Notification.builder()
            .receiverUserId(order.getUserId())
            .receiverRole("USER")
            .title("订单退款成功")
            .content("您的订单（" + orderNo + "）已退款成功，金额 "
                + (order.getTotalAmount() == null ? "0.00" : order.getTotalAmount().toPlainString())
                + " 元将原路退回。")
            .bizType("REFUND")
            .bizId(orderNo)
            .readFlag(0)
            .createTime(LocalDateTime.now())
            .build());

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("REFUND_ORDER")
                .actionDesc("退款订单，orderNo=" + orderNo + "，金额=" + order.getTotalAmount() + "，原因：" + reason)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("orderNo=" + orderNo + ", reason=" + reason)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]退款订单[{}]，金额={}，原因：{}", adminUserId, orderNo, order.getTotalAmount(), reason);
        return Result.success("退款成功");
    }

    /**
     * 自动取消订单列表（已取消状态）
     */
    @GetMapping("/autoCancel/list")
    public Result<?> autoCancelList(@RequestParam(defaultValue = "1") Integer pageNo,
                                    @RequestParam(defaultValue = "10") Integer pageSize) {
        Page<Orders> page = new Page<>(pageNo, pageSize);
        LambdaQueryWrapper<Orders> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Orders::getOrderStatus, Orders.Status.CANCELLED)
                .orderByDesc(Orders::getCancelTime);
        return Result.success(ordersMapper.selectPage(page, wrapper));
    }

    /**
     * 风险检测：长时间停留“服务中”订单
     */
    @GetMapping("/risk/in-service")
    public Result<?> inServiceRisk(@RequestParam(defaultValue = "120") Integer thresholdMinutes,
                                   @RequestParam(defaultValue = "1") Integer pageNo,
                                   @RequestParam(defaultValue = "10") Integer pageSize) {
        int validThreshold = Math.max(30, thresholdMinutes == null ? 120 : thresholdMinutes);
        LocalDateTime deadline = LocalDateTime.now().minusMinutes(validThreshold);

        Page<Orders> page = ordersMapper.selectPage(
                new Page<>(pageNo, pageSize),
                new LambdaQueryWrapper<Orders>()
                        .eq(Orders::getOrderStatus, Orders.Status.IN_SERVICE)
                        .isNotNull(Orders::getStartTime)
                        .le(Orders::getStartTime, deadline)
                        .orderByAsc(Orders::getStartTime)
        );

        Map<Long, String> userPhoneMap = new LinkedHashMap<>();
        Map<Long, String> nursePhoneMap = new LinkedHashMap<>();
        if (!page.getRecords().isEmpty()) {
            Set<Long> userIds = page.getRecords().stream().map(Orders::getUserId).filter(id -> id != null && id > 0).collect(Collectors.toSet());
            Set<Long> nurseIds = page.getRecords().stream().map(Orders::getNurseUserId).filter(id -> id != null && id > 0).collect(Collectors.toSet());
            if (!userIds.isEmpty()) {
                sysUserMapper.selectBatchIds(userIds).forEach(u -> userPhoneMap.put(u.getId(), u.getPhone()));
            }
            if (!nurseIds.isEmpty()) {
                sysUserMapper.selectBatchIds(nurseIds).forEach(u -> nursePhoneMap.put(u.getId(), u.getPhone()));
            }
        }

        List<Map<String, Object>> rows = new ArrayList<>();
        for (Orders order : page.getRecords()) {
            long inServiceMinutes = order.getStartTime() == null
                    ? 0
                    : Math.max(0, Duration.between(order.getStartTime(), LocalDateTime.now()).toMinutes());
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", order.getId());
            row.put("orderNo", order.getOrderNo());
            row.put("userId", order.getUserId());
            row.put("userPhone", userPhoneMap.get(order.getUserId()));
            row.put("nurseUserId", order.getNurseUserId());
            row.put("nursePhone", nursePhoneMap.get(order.getNurseUserId()));
            row.put("startTime", order.getStartTime());
            row.put("appointmentTime", order.getAppointmentTime());
            row.put("inServiceMinutes", inServiceMinutes);
            row.put("riskLevel", inServiceMinutes >= validThreshold * 2L ? "HIGH" : "MEDIUM");
            rows.add(row);
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("records", rows);
        result.put("total", page.getTotal());
        result.put("pageNo", pageNo);
        result.put("pageSize", pageSize);
        result.put("thresholdMinutes", validThreshold);
        return Result.success(result);
    }

    /**
     * 风险检测统计
     */
    @GetMapping("/risk/in-service/stats")
    public Result<?> inServiceRiskStats(@RequestParam(defaultValue = "120") Integer thresholdMinutes) {
        int validThreshold = Math.max(30, thresholdMinutes == null ? 120 : thresholdMinutes);
        LocalDateTime deadline = LocalDateTime.now().minusMinutes(validThreshold);

        Long totalInService = ordersMapper.selectCount(
                new LambdaQueryWrapper<Orders>()
                        .eq(Orders::getOrderStatus, Orders.Status.IN_SERVICE)
        );
        Long abnormalCount = ordersMapper.selectCount(
                new LambdaQueryWrapper<Orders>()
                        .eq(Orders::getOrderStatus, Orders.Status.IN_SERVICE)
                        .isNotNull(Orders::getStartTime)
                        .le(Orders::getStartTime, deadline)
        );

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("thresholdMinutes", validThreshold);
        result.put("totalInService", totalInService == null ? 0 : totalInService);
        result.put("abnormalCount", abnormalCount == null ? 0 : abnormalCount);
        result.put("safeCount", Math.max(0, (totalInService == null ? 0 : totalInService) - (abnormalCount == null ? 0 : abnormalCount)));
        return Result.success(result);
    }

    /**
     * 导出订单 Excel
     */
    @GetMapping("/export")
    public void export(@RequestParam(required = false) String ids,
                       @RequestParam(required = false) String orderNo,
                       @RequestParam(required = false) String userPhone,
                       @RequestParam(required = false) String nursePhone,
                       @RequestParam(required = false) Integer orderStatus,
                       @RequestParam(required = false) Integer payStatus,
                       HttpServletResponse response) throws IOException {
        LambdaQueryWrapper<Orders> wrapper = buildOrderWrapper(orderNo, userPhone, nursePhone, orderStatus, payStatus, ids);
        List<Orders> orders = ordersMapper.selectList(wrapper);
        List<AdminOrderVO> orderVOList = buildOrderVOList(orders);
        List<OrderExportDTO> exportRows = orderVOList.stream().map(this::toExportRow).toList();

        String fileName = URLEncoder.encode("订单列表", StandardCharsets.UTF_8).replaceAll("\\+", "%20");
        response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.setHeader("Content-Disposition", "attachment;filename*=utf-8''" + fileName + ".xlsx");

        EasyExcel.write(response.getOutputStream(), OrderExportDTO.class)
                .autoCloseStream(false)
                .sheet("订单列表")
                .doWrite(exportRows);
    }

    private LambdaQueryWrapper<Orders> buildOrderWrapper(String orderNo,
                                                         String userPhone,
                                                         String nursePhone,
                                                         Integer orderStatus,
                                                         Integer payStatus,
                                                         String ids) {
        LambdaQueryWrapper<Orders> wrapper = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(orderNo)) {
            wrapper.like(Orders::getOrderNo, orderNo);
        }
        if (orderStatus != null) {
            wrapper.eq(Orders::getOrderStatus, orderStatus);
        }
        if (payStatus != null) {
            wrapper.eq(Orders::getPayStatus, payStatus);
        }
        if (StringUtils.hasText(ids)) {
            List<Long> idList = parseIds(ids);
            if (idList.isEmpty()) {
                wrapper.eq(Orders::getId, -1L);
            } else {
                wrapper.in(Orders::getId, idList);
            }
        }
        if (StringUtils.hasText(userPhone)) {
            List<Long> userIds = sysUserMapper.selectList(
                            new LambdaQueryWrapper<SysUser>().like(SysUser::getPhone, userPhone).select(SysUser::getId))
                    .stream().map(SysUser::getId).toList();
            if (userIds.isEmpty()) {
                wrapper.eq(Orders::getId, -1L);
            } else {
                wrapper.in(Orders::getUserId, userIds);
            }
        }
        if (StringUtils.hasText(nursePhone)) {
            List<Long> nurseUserIds = sysUserMapper.selectList(
                            new LambdaQueryWrapper<SysUser>().like(SysUser::getPhone, nursePhone).select(SysUser::getId))
                    .stream().map(SysUser::getId).toList();
            if (nurseUserIds.isEmpty()) {
                wrapper.eq(Orders::getId, -1L);
            } else {
                wrapper.in(Orders::getNurseUserId, nurseUserIds);
            }
        }
        wrapper.orderByDesc(Orders::getCreateTime);
        return wrapper;
    }

    private Long adminUserIdSafe() {
        try {
            return (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        } catch (Exception e) {
            return null;
        }
    }

    private void writeStatusLog(Orders order,
                                Integer oldStatus,
                                Integer newStatus,
                                Long operatorUserId,
                                String operatorRole,
                                String remark) {
        if (order == null || oldStatus == null || newStatus == null || oldStatus.equals(newStatus)) {
            return;
        }
        orderStatusLogMapper.insert(OrderStatusLog.builder()
                .orderId(order.getId())
                .orderNo(order.getOrderNo())
                .oldStatus(oldStatus)
                .newStatus(newStatus)
                .operatorUserId(operatorUserId)
                .operatorRole(operatorRole)
                .remark(remark)
                .createTime(LocalDateTime.now())
                .build());
    }

    private List<AdminOrderVO> buildOrderVOList(List<Orders> records) {
        if (records == null || records.isEmpty()) {
            return Collections.emptyList();
        }

        Set<Long> userIds = records.stream()
                .map(Orders::getUserId)
                .filter(id -> id != null && id > 0)
                .collect(Collectors.toSet());
        Set<Long> nurseUserIds = records.stream()
                .map(Orders::getNurseUserId)
                .filter(id -> id != null && id > 0)
                .collect(Collectors.toSet());

        Map<Long, String> userPhoneMap = new LinkedHashMap<>();
        Map<Long, String> nursePhoneMap = new LinkedHashMap<>();
        if (!userIds.isEmpty()) {
            sysUserMapper.selectBatchIds(userIds).forEach(user -> userPhoneMap.put(user.getId(), user.getPhone()));
        }
        if (!nurseUserIds.isEmpty()) {
            sysUserMapper.selectBatchIds(nurseUserIds).forEach(user -> nursePhoneMap.put(user.getId(), user.getPhone()));
        }

        Map<Long, String> nurseNameMap = new LinkedHashMap<>();
        if (!nurseUserIds.isEmpty()) {
            nurseProfileMapper.selectList(new LambdaQueryWrapper<NurseProfile>().in(NurseProfile::getUserId, nurseUserIds))
                    .forEach(profile -> nurseNameMap.put(profile.getUserId(), profile.getNurseName()));
        }

        Set<String> orderNos = records.stream()
            .map(Orders::getOrderNo)
            .filter(StringUtils::hasText)
            .collect(Collectors.toSet());
        Map<String, String> arrivalPhotoMap = loadOrderPhotoMap(orderNos, BIZ_TYPE_NURSE_ARRIVE);
        Map<String, String> startPhotoMap = loadOrderPhotoMap(orderNos, BIZ_TYPE_NURSE_START);
        Map<String, String> finishPhotoMap = loadOrderPhotoMap(orderNos, BIZ_TYPE_NURSE_FINISH);

        return records.stream()
            .map(order -> toOrderVO(order, userPhoneMap, nursePhoneMap, nurseNameMap,
                arrivalPhotoMap, startPhotoMap, finishPhotoMap))
                .toList();
    }

    private AdminOrderVO toOrderVO(Orders order,
                                   Map<Long, String> userPhoneMap,
                                   Map<Long, String> nursePhoneMap,
                       Map<Long, String> nurseNameMap,
                       Map<String, String> arrivalPhotoMap,
                       Map<String, String> startPhotoMap,
                       Map<String, String> finishPhotoMap) {
        AddressContact addressContact = parseAddressSnapshot(order.getAddressSnapshot());
        String contactPhone = StringUtils.hasText(addressContact.contactPhone())
                ? addressContact.contactPhone()
                : userPhoneMap.get(order.getUserId());
        BigDecimal totalAmount = order.getTotalAmount() == null ? BigDecimal.ZERO : order.getTotalAmount();
        BigDecimal platformFee = totalAmount.multiply(PLATFORM_FEE_RATE).setScale(2, RoundingMode.HALF_UP);
        BigDecimal nurseIncome = totalAmount.subtract(platformFee).setScale(2, RoundingMode.HALF_UP);

        return AdminOrderVO.builder()
                .id(order.getId())
                .orderNo(order.getOrderNo())
                .serviceName(order.getServiceNameSnapshot())
                .servicePrice(order.getServicePriceSnapshot())
                .totalAmount(totalAmount)
                .platformFee(platformFee)
                .nurseIncome(nurseIncome)
                .contactName(addressContact.contactName())
                .contactPhone(contactPhone)
                .address(addressContact.address())
                .latitude(order.getAddressLatitude())
                .longitude(order.getAddressLongitude())
                .status(order.getOrderStatus())
                .payStatus(order.getPayStatus())
                .refundStatus(resolveRefundStatus(order.getOrderStatus()))
                .nurseName(nurseNameMap.get(order.getNurseUserId()))
                .nursePhone(nursePhoneMap.get(order.getNurseUserId()))
                .remark(order.getRemark())
                .appointmentTime(order.getAppointmentTime())
                .arrivalTime(order.getArriveTime())
                .arrivalPhoto(arrivalPhotoMap.get(order.getOrderNo()))
                .startTime(order.getStartTime())
                .startPhoto(startPhotoMap.get(order.getOrderNo()))
                .finishTime(order.getFinishTime())
                .finishPhoto(finishPhotoMap.get(order.getOrderNo()))
                .createdAt(order.getCreateTime())
                .build();
    }

    private Map<String, String> loadOrderPhotoMap(Set<String> orderNos, String bizType) {
        if (orderNos == null || orderNos.isEmpty()) {
            return Collections.emptyMap();
        }

        List<FileAttachment> attachments = fileAttachmentMapper.selectList(
                new LambdaQueryWrapper<FileAttachment>()
                        .eq(FileAttachment::getBizType, bizType)
                        .in(FileAttachment::getBizId, orderNos)
                        .orderByDesc(FileAttachment::getCreateTime)
        );

        Map<String, String> photoMap = new LinkedHashMap<>();
        for (FileAttachment attachment : attachments) {
            if (attachment == null || !StringUtils.hasText(attachment.getBizId())) {
                continue;
            }
            if (photoMap.containsKey(attachment.getBizId())) {
                continue;
            }
            photoMap.put(attachment.getBizId(), attachment.getFilePath());
        }
        return photoMap;
    }

    private OrderExportDTO toExportRow(AdminOrderVO item) {
        return OrderExportDTO.builder()
                .orderNo(item.getOrderNo())
                .serviceName(item.getServiceName())
                .totalAmount(item.getTotalAmount())
                .platformFee(item.getPlatformFee())
                .nurseIncome(item.getNurseIncome())
                .contactName(item.getContactName())
                .contactPhone(item.getContactPhone())
                .address(item.getAddress())
                .appointmentTime(item.getAppointmentTime())
                .statusDesc(resolveOrderStatusDesc(item.getStatus()))
                .payStatusDesc(resolvePayStatusDesc(item.getPayStatus()))
                .nurseName(item.getNurseName())
                .nursePhone(item.getNursePhone())
                .remark(item.getRemark())
                .createdAt(item.getCreatedAt())
                .build();
    }

    private int resolveRefundStatus(Integer orderStatus) {
        if (orderStatus == null) {
            return 0;
        }
        if (orderStatus == Orders.Status.REFUNDED) {
            return 2;
        }
        if (orderStatus == Orders.Status.REFUNDING) {
            return 1;
        }
        return 0;
    }

    private String resolveOrderStatusDesc(Integer status) {
        if (status == null) {
            return "-";
        }
        return switch (status) {
            case Orders.Status.PENDING_PAYMENT -> "待支付";
            case Orders.Status.PENDING_ACCEPT -> "待接单";
            case Orders.Status.DISPATCHED -> "已派单";
            case Orders.Status.ACCEPTED -> "已接单";
            case Orders.Status.ARRIVED -> "护士已到达";
            case Orders.Status.IN_SERVICE -> "服务中";
            case Orders.Status.COMPLETED -> "已完成";
            case Orders.Status.EVALUATED -> "已评价";
            case Orders.Status.CANCELLED -> "已取消";
            case Orders.Status.REFUNDING -> "退款中";
            case Orders.Status.REFUNDED -> "已退款";
            default -> "未知状态";
        };
    }

    private String resolvePayStatusDesc(Integer payStatus) {
        if (payStatus == null) {
            return "-";
        }
        return switch (payStatus) {
            case Orders.PayStatusEnum.UNPAID -> "未支付";
            case Orders.PayStatusEnum.PAID -> "已支付";
            case Orders.PayStatusEnum.REFUNDED -> "已退款";
            default -> "未知";
        };
    }

    private AddressContact parseAddressSnapshot(String snapshot) {
        if (!StringUtils.hasText(snapshot)) {
            return new AddressContact("", "", "");
        }
        String[] parts = snapshot.trim().split("\\s+");
        if (parts.length >= 3 && PHONE_PATTERN.matcher(parts[parts.length - 1]).matches()) {
            String contactPhone = parts[parts.length - 1];
            String contactName = parts[parts.length - 2];
            String address = String.join(" ", java.util.Arrays.copyOfRange(parts, 0, parts.length - 2));
            return new AddressContact(address, contactName, contactPhone);
        }
        return new AddressContact(snapshot, "", "");
    }

    private List<Long> parseIds(String ids) {
        return List.of(ids.split(",")).stream()
                .map(String::trim)
                .filter(StringUtils::hasText)
                .map(value -> {
                    try {
                        return Long.parseLong(value);
                    } catch (NumberFormatException e) {
                        return null;
                    }
                })
                .filter(value -> value != null && value > 0)
                .toList();
    }

    private record AddressContact(String address, String contactName, String contactPhone) {
    }
}
