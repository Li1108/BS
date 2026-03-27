package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.*;
import com.nursing.mapper.*;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * 护士端订单控制器
 * 处理护士接单、拒单、到达、开始服务、完成服务等操作
 */
@Slf4j
@RestController
@RequestMapping("/nurse/order")
@RequiredArgsConstructor
public class NurseOrderController {

    private static final String BIZ_TYPE_NURSE_ARRIVE = "nurse_arrive";
    private static final String BIZ_TYPE_NURSE_START = "nurse_start";
    private static final String BIZ_TYPE_NURSE_FINISH = "nurse_finish";
    private static final int CHECKIN_TYPE_ARRIVE = 1;
    private static final int CHECKIN_TYPE_START = 2;
    private static final int CHECKIN_TYPE_FINISH = 3;

    private final OrdersMapper ordersMapper;
    private final FileAttachmentMapper fileAttachmentMapper;
    private final ServiceCheckinPhotoMapper serviceCheckinPhotoMapper;
    private final NurseProfileMapper nurseProfileMapper;
    private final NurseRejectLogMapper nurseRejectLogMapper;
    private final OrderAssignLogMapper orderAssignLogMapper;
    private final NurseWalletMapper nurseWalletMapper;
    private final WalletLogMapper walletLogMapper;
    private final OrderStatusLogMapper orderStatusLogMapper;
    private final PaymentRecordMapper paymentRecordMapper;
    private final RefundRecordMapper refundRecordMapper;
    private final EmergencyCallMapper emergencyCallMapper;
    private final NotificationMapper notificationMapper;
    private final OperationLogMapper operationLogMapper;
    private final SysConfigMapper sysConfigMapper;

    private static final BigDecimal DEFAULT_PLATFORM_FEE_RATE = new BigDecimal("0.20");
    private static final int DEFAULT_REJECT_LIMIT_PER_DAY = 5;

    // ==================== GET /nurse/order/list ====================

    /**
     * 护士订单列表
     * - 归属于当前护士的订单（按状态筛选）
     * - 状态为「待接单(1)」且尚未分配护士的新订单（任意护士可见，可主动抢单）
     * GET /nurse/order/list?status=&pageNo=&pageSize=
     */
    @GetMapping("/list")
    public Result<IPage<Orders>> list(
            @RequestParam(required = false) Integer status,
            @RequestParam(defaultValue = "1") int pageNo,
            @RequestParam(defaultValue = "10") int pageSize) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        NurseProfile profile = loadCurrentNurseProfile(userId);
        boolean canReceiveNewOrders = profile != null
            && profile.getAuditStatus() != null
            && profile.getAuditStatus() == NurseProfile.AuditStatus.APPROVED
            && profile.getAcceptEnabled() != null
            && profile.getAcceptEnabled() == 1;

        // 未指定状态或指定待接单时，仅接单中的护士可看到未分配新单。
        final boolean includeUnassigned = canReceiveNewOrders
            && (status == null || status == Orders.Status.PENDING_ACCEPT);

        // 当前护士已拒单的订单，不再展示给本人（避免拒单后仍留在今日任务中）
        List<Long> rejectedOrderIds = nurseRejectLogMapper.selectList(
                new LambdaQueryWrapper<NurseRejectLog>()
                    .select(NurseRejectLog::getOrderId)
                    .eq(NurseRejectLog::getNurseUserId, userId))
            .stream()
            .map(NurseRejectLog::getOrderId)
            .filter(Objects::nonNull)
            .distinct()
            .collect(Collectors.toList());

        LambdaQueryWrapper<Orders> wrapper = new LambdaQueryWrapper<Orders>()
                .and(w -> {
                    // 分支1：归属当前护士的订单
                    w.nested(n -> n
                            .eq(Orders::getNurseUserId, userId)
                            .eq(status != null, Orders::getOrderStatus, status));
                    // 分支2：待接单且无归属护士（只在接单中时加入）
                    if (includeUnassigned) {
                        w.or().nested(n -> n
                                .isNull(Orders::getNurseUserId)
                                .notIn(!rejectedOrderIds.isEmpty(), Orders::getId, rejectedOrderIds)
                                .eq(Orders::getOrderStatus, Orders.Status.PENDING_ACCEPT));
                    }
                })
                .orderByDesc(Orders::getCreateTime);

        IPage<Orders> page = ordersMapper.selectPage(new Page<>(pageNo, pageSize), wrapper);
        return Result.success(page);
    }

    // ==================== GET /nurse/order/detail/{orderNo} ====================

    /**
     * 护士查看订单详情
     * GET /nurse/order/detail/{orderNo}
     */
    @GetMapping("/detail/{orderNo}")
    public Result<Orders> detail(@PathVariable String orderNo) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        Orders order = ordersMapper.selectOne(
                new LambdaQueryWrapper<Orders>().eq(Orders::getOrderNo, orderNo));
        if (order == null) {
            return Result.notFound("订单不存在");
        }
        // 已分配护士的订单：只有对应护士可查看；未分配的待接单订单任意护士可查看
        if (order.getNurseUserId() != null && !userId.equals(order.getNurseUserId())) {
            return Result.forbidden("无权查看此订单");
        }
        return Result.success(order);
    }

    /**
     * 护士查看订单全链路详情（状态流/支付退款/SOS）
     * GET /nurse/order/flow/{orderNo}
     */
    @GetMapping("/flow/{orderNo}")
    public Result<?> flow(@PathVariable String orderNo) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        Orders order = ordersMapper.selectOne(
                new LambdaQueryWrapper<Orders>().eq(Orders::getOrderNo, orderNo));
        if (order == null) {
            return Result.notFound("订单不存在");
        }
        // 已分配护士的订单：仅分配护士可查看；未分配的待接单订单允许护士查看
        if (order.getNurseUserId() != null && !userId.equals(order.getNurseUserId())) {
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

        LinkedHashMap<String, Object> result = new LinkedHashMap<>();
        result.put("orderNo", orderNo);
        result.put("orderId", order.getId());
        result.put("statusLogs", statusLogs);
        result.put("paymentRecords", paymentRecords);
        result.put("refundRecords", refundRecords);
        result.put("sosRecords", sosRecords);
        return Result.success(result);
    }

    // ==================== POST /nurse/order/accept/{orderNo} ====================

    /**
     * 护士接单
     * - 已派单(2)：只有被指定的护士可接单（状态 2 -> 3）
     * - 待接单(1) 且无归属护士：任意合法护士可主动接单（状态 1 -> 3，同时写入 nurseUserId）
     */
    @PostMapping("/accept/{orderNo}")
    @Transactional(rollbackFor = Exception.class)
    public Result<Void> accept(@PathVariable String orderNo) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        NurseProfile profile = loadCurrentNurseProfile(userId);
        if (profile == null) {
            return Result.notFound("护士资料不存在");
        }
        if (profile.getAuditStatus() == null || profile.getAuditStatus() != NurseProfile.AuditStatus.APPROVED) {
            return Result.badRequest("审核未通过，暂不能接单");
        }
        if (profile.getAcceptEnabled() == null || profile.getAcceptEnabled() != 1) {
            return Result.badRequest("当前为休息中，暂不能接单");
        }

        Orders order = getOrderByNo(orderNo);
        if (order == null) {
            return Result.notFound("订单不存在");
        }

        int currentStatus = order.getOrderStatus();

        if (currentStatus == Orders.Status.PENDING_ACCEPT) {
            // 待接单且无归属护士：任意护士可主动接单
            if (order.getNurseUserId() != null && !userId.equals(order.getNurseUserId())) {
                return Result.badRequest("该订单已被其他护士接单");
            }
            order.setNurseUserId(userId);
            order.setOrderStatus(Orders.Status.ACCEPTED);
            order.setNurseAcceptTime(LocalDateTime.now());
            order.setUpdateTime(LocalDateTime.now());
            ordersMapper.updateById(order);

            saveStatusLog(order, currentStatus, Orders.Status.ACCEPTED, userId, "NURSE", "护士主动接单");
            log.info("护士主动接单成功: orderNo={}, nurseUserId={}", orderNo, userId);
            return Result.success("接单成功", null);

        } else if (currentStatus == Orders.Status.DISPATCHED) {
            // 已派单：只有指定护士可接单
            if (!userId.equals(order.getNurseUserId())) {
                return Result.badRequest("该订单未分配给您");
            }
            order.setOrderStatus(Orders.Status.ACCEPTED);
            order.setNurseAcceptTime(LocalDateTime.now());
            order.setUpdateTime(LocalDateTime.now());
            ordersMapper.updateById(order);

            saveStatusLog(order, currentStatus, Orders.Status.ACCEPTED, userId, "NURSE", "护士接单");
            log.info("护士接单成功: orderNo={}, nurseUserId={}", orderNo, userId);
            return Result.success("接单成功", null);

        } else {
            return Result.badRequest("当前订单状态不允许接单，当前状态: " + currentStatus);
        }
    }

    // ==================== POST /nurse/order/reject/{orderNo} ====================

    /**
     * 护士拒单（状态 2已派单 -> 1待接单，清空 nurseUserId，累加拒单次数）
     */
    public Result<Void> reject(String orderNo) {
        return reject(orderNo, null);
    }

    @PostMapping("/reject/{orderNo}")
    @Transactional(rollbackFor = Exception.class)
    public Result<Void> reject(@PathVariable String orderNo, HttpServletRequest request) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        Orders order = getOrderByNo(orderNo);
        if (order == null) {
            return Result.notFound("订单不存在");
        }
        if (!userId.equals(order.getNurseUserId())) {
            return Result.badRequest("该订单未分配给您");
        }
        if (order.getOrderStatus() != Orders.Status.DISPATCHED) {
            return Result.badRequest("当前订单状态不允许拒单");
        }
        // 派单后3分钟内才允许拒单
        if (order.getLastAssignTime() == null
                || LocalDateTime.now().isAfter(order.getLastAssignTime().plusMinutes(3))) {
            return Result.badRequest("拒单超时（仅支持派单后3分钟内拒单）");
        }

        // 查询护士资料，校验每日拒单上限
        NurseProfile profile = nurseProfileMapper.selectOne(
                new LambdaQueryWrapper<NurseProfile>().eq(NurseProfile::getUserId, userId));
        if (profile == null) {
            return Result.notFound("护士资料不存在");
        }

        // 如果日期不是今天，重置拒单计数
        LocalDate today = LocalDate.now();
        if (profile.getRejectDate() == null || !today.equals(profile.getRejectDate())) {
            profile.setRejectCountToday(0);
            profile.setRejectDate(today);
        }

        int rejectLimitPerDay = getRejectLimitPerDay();
        if (profile.getRejectCountToday() != null && profile.getRejectCountToday() >= rejectLimitPerDay) {
            return Result.badRequest("今日拒单次数已达上限（" + rejectLimitPerDay + "次）");
        }

        // 更新订单：状态回退到待接单，清空护士（显式 set null，避免 updateById 忽略 null 字段）
        int oldStatus = order.getOrderStatus();
        int currentRetry = order.getAssignRetryCount() == null ? 0 : order.getAssignRetryCount();
        int updated = ordersMapper.update(null, new LambdaUpdateWrapper<Orders>()
            .eq(Orders::getId, order.getId())
            .eq(Orders::getOrderStatus, Orders.Status.DISPATCHED)
            .eq(Orders::getNurseUserId, userId)
            .set(Orders::getOrderStatus, Orders.Status.PENDING_ACCEPT)
            .set(Orders::getNurseUserId, null)
            .set(Orders::getAssignRetryCount, currentRetry + 1)
            .set(Orders::getUpdateTime, LocalDateTime.now()));
        if (updated == 0) {
            return Result.badRequest("拒单失败：订单状态已变化，请刷新后重试");
        }

        order.setOrderStatus(Orders.Status.PENDING_ACCEPT);
        order.setNurseUserId(null);
        order.setAssignRetryCount(currentRetry + 1);
        order.setUpdateTime(LocalDateTime.now());

        // 累加拒单次数
        profile.setRejectCountToday(
                (profile.getRejectCountToday() == null ? 0 : profile.getRejectCountToday()) + 1);
        if (profile.getRejectCountToday() >= rejectLimitPerDay) {
            // 达到阈值后自动关闭接单开关
            profile.setAcceptEnabled(0);
        }
        profile.setUpdateTime(LocalDateTime.now());
        nurseProfileMapper.updateById(profile);

        NurseRejectLog rejectLog = NurseRejectLog.builder()
            .nurseUserId(userId)
            .orderId(order.getId())
            .orderNo(order.getOrderNo())
            .rejectTime(LocalDateTime.now())
            .rejectReason("护士主动拒单")
            .autoFlag(0)
            .createTime(LocalDateTime.now())
            .build();
        nurseRejectLogMapper.insert(rejectLog);

            // 派单回退日志（供派单管理追踪）
            orderAssignLogMapper.insert(OrderAssignLog.builder()
                .orderId(order.getId())
                .orderNo(order.getOrderNo())
                .tryNo(currentRetry + 1)
                .nurseUserId(userId)
                .successFlag(0)
                .failReason("护士拒单，订单回退待接单")
                .createTime(LocalDateTime.now())
                .build());

            // 管理端操作日志（供运营实时跟踪）
            operationLogMapper.insert(OperationLog.builder()
                .adminUserId(userId)
                .actionType("DISPATCH_ROLLBACK")
                .actionDesc("派单回退：护士拒单，orderNo=" + orderNo + "，nurseUserId=" + userId)
                .requestPath(request == null ? "/nurse/order/reject/" + orderNo : request.getRequestURI())
                .requestMethod(request == null ? "POST" : request.getMethod())
                .requestParams("orderNo=" + orderNo + ", nurseUserId=" + userId)
                .ip(request == null ? "" : request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        saveStatusLog(order, oldStatus, Orders.Status.PENDING_ACCEPT, userId, "NURSE", "护士拒单");
        log.info("护士拒单: orderNo={}, nurseUserId={}, rejectCount={}, acceptEnabled={}",
                orderNo, userId, profile.getRejectCountToday(), profile.getAcceptEnabled());
        if (profile.getRejectCountToday() >= rejectLimitPerDay) {
            return Result.success("已拒单，今日拒单达上限，已自动关闭接单", null);
        }
        return Result.success("已拒单", null);
    }

    // ==================== POST /nurse/order/arrive/{orderNo} ====================

    /**
     * 护士到达（状态 3已接单 -> 4已到达）
     */
    @PostMapping("/arrive/{orderNo}")
    @Transactional(rollbackFor = Exception.class)
    public Result<Void> arrive(@PathVariable String orderNo) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        Orders order = getOrderByNo(orderNo);
        if (order == null) {
            return Result.notFound("订单不存在");
        }
        if (!userId.equals(order.getNurseUserId())) {
            return Result.badRequest("该订单未分配给您");
        }
        if (order.getOrderStatus() != Orders.Status.ACCEPTED) {
            return Result.badRequest("当前订单状态不允许标记到达");
        }

        int oldStatus = order.getOrderStatus();
        order.setOrderStatus(Orders.Status.ARRIVED);
        order.setArriveTime(LocalDateTime.now());
        order.setUpdateTime(LocalDateTime.now());
        ordersMapper.updateById(order);

        syncCheckinPhotoFromAttachment(order, userId, BIZ_TYPE_NURSE_ARRIVE, CHECKIN_TYPE_ARRIVE);

        saveStatusLog(order, oldStatus, Orders.Status.ARRIVED, userId, "NURSE", "护士到达");
        log.info("护士到达: orderNo={}, nurseUserId={}", orderNo, userId);
        return Result.success("已确认到达", null);
    }

    // ==================== POST /nurse/order/start/{orderNo} ====================

    /**
     * 开始服务（状态 4已到达 -> 5服务中）
     */
    @PostMapping("/start/{orderNo}")
    @Transactional(rollbackFor = Exception.class)
    public Result<Void> start(@PathVariable String orderNo) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        Orders order = getOrderByNo(orderNo);
        if (order == null) {
            return Result.notFound("订单不存在");
        }
        if (!userId.equals(order.getNurseUserId())) {
            return Result.badRequest("该订单未分配给您");
        }
        if (order.getOrderStatus() != Orders.Status.ARRIVED) {
            return Result.badRequest("当前订单状态不允许开始服务");
        }

        int oldStatus = order.getOrderStatus();
        order.setOrderStatus(Orders.Status.IN_SERVICE);
        order.setStartTime(LocalDateTime.now());
        order.setUpdateTime(LocalDateTime.now());
        ordersMapper.updateById(order);

        syncCheckinPhotoFromAttachment(order, userId, BIZ_TYPE_NURSE_START, CHECKIN_TYPE_START);

        saveStatusLog(order, oldStatus, Orders.Status.IN_SERVICE, userId, "NURSE", "开始服务");
        log.info("开始服务: orderNo={}, nurseUserId={}", orderNo, userId);
        return Result.success("服务已开始", null);
    }

    // ==================== POST /nurse/order/finish/{orderNo} ====================

    /**
     * 完成服务（状态 5服务中 -> 6已完成），同时创建钱包收入（护士获得80%）
     */
    @PostMapping("/finish/{orderNo}")
    @Transactional(rollbackFor = Exception.class)
    public Result<Void> finish(@PathVariable String orderNo) {
        Long userId = getCurrentUserId();
        if (userId == null) {
            return Result.unauthorized("请先登录");
        }

        Orders order = getOrderByNo(orderNo);
        if (order == null) {
            return Result.notFound("订单不存在");
        }
        if (!userId.equals(order.getNurseUserId())) {
            return Result.badRequest("该订单未分配给您");
        }
        if (order.getOrderStatus() != Orders.Status.IN_SERVICE) {
            return Result.badRequest("当前订单状态不允许完成服务");
        }

        // 更新订单状态
        int oldStatus = order.getOrderStatus();
        order.setOrderStatus(Orders.Status.COMPLETED);
        order.setFinishTime(LocalDateTime.now());
        order.setUpdateTime(LocalDateTime.now());
        ordersMapper.updateById(order);

        syncCheckinPhotoFromAttachment(order, userId, BIZ_TYPE_NURSE_FINISH, CHECKIN_TYPE_FINISH);

        saveStatusLog(order, oldStatus, Orders.Status.COMPLETED, userId, "NURSE", "完成服务");

        // 护士收入 = totalAmount * (1 - 平台费率)
        BigDecimal effectivePlatformFeeRate = getPlatformFeeRate();
        BigDecimal nurseIncomeRate = BigDecimal.ONE.subtract(effectivePlatformFeeRate);
        BigDecimal income = order.getTotalAmount()
            .multiply(nurseIncomeRate)
                .setScale(2, RoundingMode.HALF_UP);

        // 查询或创建护士钱包
        NurseWallet wallet = nurseWalletMapper.selectOne(
                new LambdaQueryWrapper<NurseWallet>().eq(NurseWallet::getNurseUserId, userId));
        if (wallet == null) {
            wallet = NurseWallet.builder()
                    .nurseUserId(userId)
                    .balance(BigDecimal.ZERO)
                    .totalIncome(BigDecimal.ZERO)
                    .totalWithdraw(BigDecimal.ZERO)
                    .createTime(LocalDateTime.now())
                    .updateTime(LocalDateTime.now())
                    .build();
            nurseWalletMapper.insert(wallet);
        }

        // 更新钱包余额
        BigDecimal newBalance = wallet.getBalance().add(income);
        BigDecimal newTotalIncome = wallet.getTotalIncome().add(income);
        wallet.setBalance(newBalance);
        wallet.setTotalIncome(newTotalIncome);
        wallet.setUpdateTime(LocalDateTime.now());
        nurseWalletMapper.updateById(wallet);

        // 写入钱包流水
        WalletLog walletLog = WalletLog.builder()
                .nurseUserId(userId)
                .orderNo(order.getOrderNo())
                .changeType(1) // 1=收入
                .changeAmount(income)
                .balanceAfter(newBalance)
                .remark("订单完成收入（费率" + nurseIncomeRate.multiply(new BigDecimal("100")).setScale(0, RoundingMode.HALF_UP) + "%）")
                .createTime(LocalDateTime.now())
                .build();
        walletLogMapper.insert(walletLog);

            notificationMapper.insert(Notification.builder()
                .receiverUserId(order.getUserId())
                .receiverRole("USER")
                .title("订单服务已完成")
                .content("您的订单" + order.getOrderNo() + "已完成服务，请及时评价。")
                .bizType("ORDER")
                .bizId(order.getOrderNo())
                .readFlag(0)
                .createTime(LocalDateTime.now())
                .build());

        log.info("完成服务: orderNo={}, nurseUserId={}, income={}", orderNo, userId, income);
        return Result.success("服务已完成", null);
    }

    // ==================== 私有方法 ====================

    /**
     * 根据订单号查询订单
     */
    private Orders getOrderByNo(String orderNo) {
        return ordersMapper.selectOne(
                new LambdaQueryWrapper<Orders>().eq(Orders::getOrderNo, orderNo));
    }

    private NurseProfile loadCurrentNurseProfile(Long userId) {
        return nurseProfileMapper.selectOne(
                new LambdaQueryWrapper<NurseProfile>().eq(NurseProfile::getUserId, userId));
    }

    /**
     * 记录订单状态变更日志
     */
    private void saveStatusLog(Orders order, int oldStatus, int newStatus,
                               Long operatorUserId, String operatorRole, String remark) {
        OrderStatusLog statusLog = OrderStatusLog.builder()
                .orderId(order.getId())
                .orderNo(order.getOrderNo())
                .oldStatus(oldStatus)
                .newStatus(newStatus)
                .operatorUserId(operatorUserId)
                .operatorRole(operatorRole)
                .remark(remark)
                .createTime(LocalDateTime.now())
                .build();
        orderStatusLogMapper.insert(statusLog);
    }

    private void syncCheckinPhotoFromAttachment(Orders order, Long nurseUserId, String bizType, int checkinType) {
        try {
            List<FileAttachment> attachments = fileAttachmentMapper.selectList(
                    new LambdaQueryWrapper<FileAttachment>()
                            .eq(FileAttachment::getBizType, bizType)
                            .eq(FileAttachment::getBizId, order.getOrderNo())
                            .eq(FileAttachment::getUploaderUserId, nurseUserId)
                            .orderByDesc(FileAttachment::getCreateTime)
            );

            if (attachments == null || attachments.isEmpty()) {
                log.info("未找到可同步的打卡附件: orderNo={}, nurseUserId={}, bizType={}",
                        order.getOrderNo(), nurseUserId, bizType);
                return;
            }

            FileAttachment latestAttachment = attachments.get(0);
            if (!StringUtils.hasText(latestAttachment.getFilePath())) {
                return;
            }

            ServiceCheckinPhoto existing = serviceCheckinPhotoMapper.selectOne(
                    new LambdaQueryWrapper<ServiceCheckinPhoto>()
                            .eq(ServiceCheckinPhoto::getOrderNo, order.getOrderNo())
                            .eq(ServiceCheckinPhoto::getCheckinType, checkinType)
                            .last("LIMIT 1")
            );

            if (existing != null) {
                existing.setPhotoUrl(latestAttachment.getFilePath());
                existing.setNurseUserId(nurseUserId);
                existing.setOrderId(order.getId());
                existing.setCreateTime(LocalDateTime.now());
                serviceCheckinPhotoMapper.updateById(existing);
                return;
            }

            ServiceCheckinPhoto checkinPhoto = ServiceCheckinPhoto.builder()
                    .orderId(order.getId())
                    .orderNo(order.getOrderNo())
                    .nurseUserId(nurseUserId)
                    .checkinType(checkinType)
                    .photoUrl(latestAttachment.getFilePath())
                    .createTime(LocalDateTime.now())
                    .build();
            serviceCheckinPhotoMapper.insert(checkinPhoto);
        } catch (Exception e) {
            log.warn("同步打卡照片失败: orderNo={}, nurseUserId={}, bizType={}, error={}",
                    order.getOrderNo(), nurseUserId, bizType, e.getMessage());
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

    private BigDecimal getPlatformFeeRate() {
        try {
            String value = sysConfigMapper.getValueByKey("service_fee_rate");
            if (StringUtils.hasText(value)) {
                BigDecimal parsed = new BigDecimal(value.trim());
                if (parsed.compareTo(BigDecimal.ZERO) >= 0 && parsed.compareTo(BigDecimal.ONE) < 0) {
                    return parsed;
                }
            }
        } catch (Exception e) {
            log.warn("读取平台费率配置失败，使用默认值: {}", e.getMessage());
        }
        return DEFAULT_PLATFORM_FEE_RATE;
    }

    private int getRejectLimitPerDay() {
        try {
            String value = sysConfigMapper.getValueByKey("reject_limit_per_day");
            if (StringUtils.hasText(value)) {
                int parsed = Integer.parseInt(value.trim());
                if (parsed > 0) {
                    return parsed;
                }
            }
        } catch (Exception e) {
            log.warn("读取拒单上限配置失败，使用默认值: {}", e.getMessage());
        }
        return DEFAULT_REJECT_LIMIT_PER_DAY;
    }
}
