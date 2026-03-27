package com.nursing.task;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.nursing.entity.*;
import com.nursing.mapper.*;
import com.nursing.service.AliyunPushService;
import com.nursing.service.EvaluationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 订单定时任务
 * 包含：自动派单（每1分钟）、超时取消（每5分钟）、自动评价（每小时）、护士评分更新（每天凌晨2点）
 */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.scheduling.enabled", havingValue = "true", matchIfMissing = true)
public class OrderScheduledTask {

    private final OrdersMapper ordersMapper;
    private final NurseProfileMapper nurseProfileMapper;
    private final NurseLocationMapper nurseLocationMapper;
    private final OrderAssignLogMapper orderAssignLogMapper;
    private final OrderStatusLogMapper orderStatusLogMapper;
    private final RefundRecordMapper refundRecordMapper;
    private final NotificationMapper notificationMapper;
    private final EvaluationMapper evaluationMapper;
    private final EvaluationService evaluationService;
    private final AliyunPushService aliyunPushService;
    private final SysConfigMapper sysConfigMapper;

    /** 派单最大重试次数 */
    private static final int DEFAULT_MAX_ASSIGN_RETRY = 10;

    /** 护士位置有效期（分钟） */
    private static final int DEFAULT_LOCATION_VALID_MINUTES = 5;

    // ==================== 1. 自动派单任务（每1分钟） ====================

    /**
     * 自动派单定时任务（每1分钟执行）
     * 查找 orderStatus=1（待接单）的订单，为其匹配距离最近的可用护士。
     * <p>
     * 规则：
    * - 可用护士条件：auditStatus=1（审核通过）、acceptEnabled=1（开启接单）、位置上报时间在阈值内（默认5分钟，可配置）
     * - 找到护士：分配护士、状态->2（已派单）、递增 assignRetryCount、写 order_assign_log
     * - 未找到护士：递增 assignRetryCount
    * - assignRetryCount >= 阈值：自动取消（状态->8）、创建退款记录、通知用户（默认10次，可配置）
     * - 使用 assignVersion 乐观锁防止并发派单
     */
    @Scheduled(fixedRate = 60000)
    public void dispatchOrders() {
        log.debug("开始执行自动派单任务...");

        try {
            int maxAssignRetry = getAssignMaxRetry();
            int locationValidMinutes = getLocationValidMinutes();

            // 查询所有待接单订单（orderStatus = 1）
            LambdaQueryWrapper<Orders> orderWrapper = new LambdaQueryWrapper<>();
            orderWrapper.eq(Orders::getOrderStatus, Orders.Status.PENDING_ACCEPT);
            List<Orders> pendingOrders = ordersMapper.selectList(orderWrapper);

            if (pendingOrders.isEmpty()) {
                log.debug("没有待派单订单");
                return;
            }

            log.info("发现{}个待派单订单，开始逐一处理", pendingOrders.size());

            // 逐条处理，保证幂等性
            for (Orders order : pendingOrders) {
                try {
                    processOneDispatch(order, maxAssignRetry, locationValidMinutes);
                } catch (Exception e) {
                    log.error("派单处理异常: orderId={}, orderNo={}", order.getId(), order.getOrderNo(), e);
                }
            }
        } catch (Exception e) {
            log.error("自动派单任务执行失败", e);
        }
    }

    /**
     * 处理单个订单的派单逻辑
     */
    private void processOneDispatch(Orders order, int maxAssignRetry, int locationValidMinutes) {
        int currentRetry = order.getAssignRetryCount() == null ? 0 : order.getAssignRetryCount();
        int tryNo = currentRetry + 1;
        LocalDateTime now = LocalDateTime.now();

        // 订单地址坐标校验
        if (order.getAddressLatitude() == null || order.getAddressLongitude() == null) {
            log.warn("订单缺少地址坐标，跳过派单: orderId={}, orderNo={}", order.getId(), order.getOrderNo());
            return;
        }

        double orderLat = order.getAddressLatitude().doubleValue();
        double orderLon = order.getAddressLongitude().doubleValue();

        // ---- 查找可用护士（审核通过 + 开启接单） ----
        LambdaQueryWrapper<NurseProfile> nurseWrapper = new LambdaQueryWrapper<>();
        nurseWrapper.eq(NurseProfile::getAuditStatus, NurseProfile.AuditStatus.APPROVED)
                    .eq(NurseProfile::getAcceptEnabled, 1);
        List<NurseProfile> availableNurses = nurseProfileMapper.selectList(nurseWrapper);

        // ---- 在可用护士中查找5分钟内上报过位置且距离最近的 ----
        LocalDateTime locationDeadline = now.minusMinutes(locationValidMinutes);
        Long nearestNurseUserId = null;
        double nearestDistance = Double.MAX_VALUE;
        BigDecimal assignedDistanceKm = null;
        String assignMode = "RECENT_LOCATION";

        for (NurseProfile nurse : availableNurses) {
            // 查询该护士最新的有效位置（5分钟内）
            NurseLocation location = findLatestLocation(nurse.getUserId(), locationDeadline);

            if (location == null || location.getLatitude() == null || location.getLongitude() == null) {
                continue; // 无有效位置，跳过
            }

            double distance = haversineKm(
                    orderLat, orderLon,
                    location.getLatitude().doubleValue(),
                    location.getLongitude().doubleValue()
            );

            if (distance < nearestDistance) {
                nearestDistance = distance;
                nearestNurseUserId = nurse.getUserId();
            }
        }

        if (nearestDistance < Double.MAX_VALUE) {
            assignedDistanceKm = BigDecimal.valueOf(nearestDistance);
        }

        // ---- 派单结果处理 ----
        Integer currentVersion = order.getAssignVersion();
        int nextVersion = (currentVersion == null ? 0 : currentVersion) + 1;

        if (nearestNurseUserId != null) {
            // ===== 找到护士：乐观锁更新订单 =====
            LambdaUpdateWrapper<Orders> updateWrapper = new LambdaUpdateWrapper<>();
            updateWrapper.eq(Orders::getId, order.getId());
            applyVersionLock(updateWrapper, currentVersion);
            updateWrapper.set(Orders::getNurseUserId, nearestNurseUserId)
                         .set(Orders::getOrderStatus, Orders.Status.DISPATCHED)
                         .set(Orders::getAssignRetryCount, tryNo)
                         .set(Orders::getLastAssignTime, now)
                         .set(Orders::getAssignVersion, nextVersion);

            int rows = ordersMapper.update(null, updateWrapper);

            if (rows > 0) {
                // 写入派单成功日志
                OrderAssignLog assignLog = OrderAssignLog.builder()
                        .orderId(order.getId())
                        .orderNo(order.getOrderNo())
                        .tryNo(tryNo)
                        .nurseUserId(nearestNurseUserId)
                        .distanceKm(assignedDistanceKm)
                        .successFlag(1)
                        .createTime(now)
                        .build();
                orderAssignLogMapper.insert(assignLog);

                sendDispatchNotifications(order, nearestNurseUserId, assignMode, assignedDistanceKm);

                log.info("派单成功: orderNo={}, nurseUserId={}, distance={}km, tryNo={}, mode={}",
                        order.getOrderNo(), nearestNurseUserId,
                        assignedDistanceKm == null ? "N/A" : String.format("%.2f", nearestDistance),
                        tryNo,
                        assignMode);
            } else {
                log.warn("派单乐观锁冲突，已被其他线程处理: orderId={}, orderNo={}",
                        order.getId(), order.getOrderNo());
            }

        } else {
            // ===== 未找到护士：递增重试次数 =====
            String failReason = availableNurses.isEmpty()
                    ? "暂无审核通过且开启接单的护士"
                    : "无可用护士可分配";

            LambdaUpdateWrapper<Orders> updateWrapper = new LambdaUpdateWrapper<>();
            updateWrapper.eq(Orders::getId, order.getId());
            applyVersionLock(updateWrapper, currentVersion);
            updateWrapper.set(Orders::getAssignRetryCount, tryNo)
                         .set(Orders::getLastAssignTime, now)
                         .set(Orders::getAssignFailReason, failReason)
                         .set(Orders::getAssignVersion, nextVersion);

            int rows = ordersMapper.update(null, updateWrapper);

            if (rows > 0) {
                // 写入派单失败日志
                OrderAssignLog assignLog = OrderAssignLog.builder()
                        .orderId(order.getId())
                        .orderNo(order.getOrderNo())
                        .tryNo(tryNo)
                        .successFlag(0)
                        .failReason(failReason)
                        .createTime(now)
                        .build();
                orderAssignLogMapper.insert(assignLog);

                log.info("派单失败: orderNo={}, tryNo={}, reason={}", order.getOrderNo(), tryNo, failReason);

                // 超过最大重试次数：自动取消 + 退款 + 通知
                if (tryNo >= maxAssignRetry) {
                    autoCancelAndRefund(order, maxAssignRetry);
                }
            } else {
                log.warn("派单乐观锁冲突，已被其他线程处理: orderId={}, orderNo={}",
                        order.getId(), order.getOrderNo());
            }
        }
    }

    /**
     * 查询护士最新位置
     *
     * @param nurseUserId 护士用户ID
     * @param reportAfter 仅查询该时间之后的上报，null 表示不限制
     */
    private NurseLocation findLatestLocation(Long nurseUserId, LocalDateTime reportAfter) {
        if (nurseUserId == null) {
            return null;
        }
        LambdaQueryWrapper<NurseLocation> locWrapper = new LambdaQueryWrapper<>();
        locWrapper.eq(NurseLocation::getNurseUserId, nurseUserId)
                .ge(reportAfter != null, NurseLocation::getReportTime, reportAfter)
                .orderByDesc(NurseLocation::getReportTime)
                .last("LIMIT 1");
        return nurseLocationMapper.selectOne(locWrapper);
    }

    /**
     * 派单成功后通知护士与用户
     */
    private void sendDispatchNotifications(Orders order, Long nurseUserId, String assignMode, BigDecimal distanceKm) {
        LocalDateTime now = LocalDateTime.now();
        String dispatchDistanceText = distanceKm == null
                ? "未知"
                : distanceKm.setScale(2, RoundingMode.HALF_UP).toPlainString();

        Notification nurseNotification = Notification.builder()
                .receiverUserId(nurseUserId)
                .receiverRole("NURSE")
                .title("新订单待接单")
                .content("您有新的护理订单，订单号：" + order.getOrderNo()
                        + "，匹配方式：" + assignMode
                        + "，距离：" + dispatchDistanceText + (distanceKm == null ? "" : "km"))
                .bizType("ORDER")
                .bizId(String.valueOf(order.getId()))
                .readFlag(0)
                .createTime(now)
                .build();
        notificationMapper.insert(nurseNotification);
        aliyunPushService.pushNewOrderToNurse(
            nurseUserId,
            order.getId(),
            order.getOrderNo(),
            nurseNotification.getContent()
        );

        Notification userNotification = Notification.builder()
                .receiverUserId(order.getUserId())
                .receiverRole("USER")
                .title("订单已派单")
                .content("您的订单（" + order.getOrderNo() + "）已匹配护士，请留意服务进度。")
                .bizType("ORDER")
                .bizId(String.valueOf(order.getId()))
                .readFlag(0)
                .createTime(now)
                .build();
        notificationMapper.insert(userNotification);
        aliyunPushService.pushOrderStatusToUser(
            order.getUserId(),
            order.getId(),
            order.getOrderNo(),
            userNotification.getContent()
        );
    }

    /**
     * 派单超时自动取消 + 创建退款记录 + 通知用户
     */
    private void autoCancelAndRefund(Orders order, int maxAssignRetry) {
        LocalDateTime now = LocalDateTime.now();
        String cancelReason = "派单超时（已重试" + maxAssignRetry + "次），系统自动取消";

        try {
            // 1. 取消订单（orderStatus -> 8），再次校验状态防止重复操作
            LambdaUpdateWrapper<Orders> cancelWrapper = new LambdaUpdateWrapper<>();
            cancelWrapper.eq(Orders::getId, order.getId())
                         .eq(Orders::getOrderStatus, Orders.Status.PENDING_ACCEPT)
                         .set(Orders::getOrderStatus, Orders.Status.CANCELLED)
                         .set(Orders::getCancelTime, now)
                         .set(Orders::getCancelReason, cancelReason);

            int cancelRows = ordersMapper.update(null, cancelWrapper);
            if (cancelRows == 0) {
                log.warn("自动取消订单失败（状态已变更）: orderNo={}", order.getOrderNo());
                return;
            }

            orderStatusLogMapper.insert(OrderStatusLog.builder()
                    .orderId(order.getId())
                    .orderNo(order.getOrderNo())
                    .oldStatus(Orders.Status.PENDING_ACCEPT)
                    .newStatus(Orders.Status.CANCELLED)
                    .operatorUserId(null)
                    .operatorRole("SYSTEM")
                    .remark(cancelReason)
                    .createTime(now)
                    .build());

            // 2. 创建退款记录（refundStatus=0 待处理）
            RefundRecord refund = RefundRecord.builder()
                    .orderId(order.getId())
                    .orderNo(order.getOrderNo())
                    .refundAmount(order.getTotalAmount())
                    .refundStatus(0)
                    .refundReason(cancelReason)
                    .createTime(now)
                    .build();
            refundRecordMapper.insert(refund);

            // 3. 发送通知给用户
            Notification notification = Notification.builder()
                    .receiverUserId(order.getUserId())
                    .receiverRole("USER")
                    .title("订单已自动取消")
                    .content("您的订单（" + order.getOrderNo() + "）因长时间未匹配到护士，已自动取消，退款正在处理中。")
                    .bizType("REFUND")
                    .bizId(order.getOrderNo())
                    .readFlag(0)
                    .createTime(now)
                    .build();
            notificationMapper.insert(notification);
                aliyunPushService.pushOrderStatusToUser(
                    order.getUserId(),
                    order.getId(),
                    order.getOrderNo(),
                    notification.getContent()
                );

            log.info("订单派单超时自动取消: orderNo={}, refundAmount={}", order.getOrderNo(), order.getTotalAmount());

        } catch (Exception e) {
            log.error("自动取消退款处理异常: orderNo={}", order.getOrderNo(), e);
        }
    }

    /**
     * 乐观锁版本条件：处理 assignVersion 为 null 的情况
     */
    private void applyVersionLock(LambdaUpdateWrapper<Orders> wrapper, Integer currentVersion) {
        if (currentVersion == null) {
            wrapper.isNull(Orders::getAssignVersion);
        } else {
            wrapper.eq(Orders::getAssignVersion, currentVersion);
        }
    }

    /**
     * Haversine 公式计算两个经纬度之间的距离（单位：km）
     */
    private double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        double earthRadiusKm = 6371.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                 + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                 * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return earthRadiusKm * c;
    }

    private int getAssignMaxRetry() {
        try {
            String value = sysConfigMapper.getValueByKey("assign_max_retry");
            if (StringUtils.hasText(value)) {
                int parsed = Integer.parseInt(value.trim());
                if (parsed > 0) {
                    return parsed;
                }
            }
        } catch (Exception e) {
            log.warn("读取派单最大重试次数失败，使用默认值: {}", e.getMessage());
        }
        return DEFAULT_MAX_ASSIGN_RETRY;
    }

    private int getLocationValidMinutes() {
        try {
            String value = sysConfigMapper.getValueByKey("nurse_online_threshold");
            if (StringUtils.hasText(value)) {
                int seconds = Integer.parseInt(value.trim());
                if (seconds > 0) {
                    int minutes = Math.max(1, (int) Math.ceil(seconds / 60.0));
                    return minutes;
                }
            }
        } catch (Exception e) {
            log.warn("读取护士在线阈值失败，使用默认值: {}", e.getMessage());
        }
        return DEFAULT_LOCATION_VALID_MINUTES;
    }

    // ==================== 2. 超时未支付订单取消（每5分钟） ====================

    /**
     * 超时订单处理（每5分钟执行）
     * 取消超过30分钟未支付的订单
     */
    @Scheduled(fixedRate = 300000)
    @Transactional
    public void cancelTimeoutOrders() {
        log.debug("开始处理超时未支付订单...");

        try {
            // 查询超过30分钟未支付的订单
            LambdaQueryWrapper<Orders> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(Orders::getOrderStatus, Orders.Status.PENDING_PAYMENT)
                   .lt(Orders::getCreateTime, LocalDateTime.now().minusMinutes(30));
            List<Orders> timeoutOrders = ordersMapper.selectList(wrapper);

            if (timeoutOrders.isEmpty()) {
                log.debug("没有超时未支付订单");
                return;
            }

            for (Orders order : timeoutOrders) {
                int oldStatus = order.getOrderStatus();
                order.setOrderStatus(Orders.Status.CANCELLED);
                order.setCancelTime(LocalDateTime.now());
                order.setCancelReason("支付超时自动取消");
                ordersMapper.updateById(order);

                orderStatusLogMapper.insert(OrderStatusLog.builder()
                        .orderId(order.getId())
                        .orderNo(order.getOrderNo())
                        .oldStatus(oldStatus)
                        .newStatus(Orders.Status.CANCELLED)
                        .operatorUserId(null)
                        .operatorRole("SYSTEM")
                        .remark("支付超时自动取消")
                        .createTime(LocalDateTime.now())
                        .build());
                log.info("超时订单已取消: orderNo={}", order.getOrderNo());
            }

            log.info("超时订单处理完成，共取消{}个订单", timeoutOrders.size());
        } catch (Exception e) {
            log.error("超时订单处理失败", e);
        }
    }

    // ==================== 3. 超时未评价订单自动完成（每小时） ====================

    /**
     * 订单完成自动评价（每小时执行）
     * 超过7天未评价的已完成订单自动标记为已评价（默认好评）
     */
    @Scheduled(cron = "0 0 * * * ?")
    @Transactional
    public void autoCompleteOrders() {
        log.debug("开始处理超时未评价订单...");

        try {
            // 查询超过7天未评价的已完成订单（orderStatus = 6 已完成 -> 7 已评价）
            LocalDateTime sevenDaysAgo = LocalDateTime.now().minusDays(7);

            LambdaQueryWrapper<Orders> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(Orders::getOrderStatus, Orders.Status.COMPLETED)
                   .lt(Orders::getFinishTime, sevenDaysAgo);

            List<Orders> timeoutOrders = ordersMapper.selectList(wrapper);

            if (timeoutOrders.isEmpty()) {
                log.debug("没有超时未评价订单");
                return;
            }

            for (Orders order : timeoutOrders) {
                Long evaluatedCount = evaluationMapper.selectCount(
                        new LambdaQueryWrapper<Evaluation>()
                                .eq(Evaluation::getOrderNo, order.getOrderNo())
                );

                if (evaluatedCount == null || evaluatedCount == 0) {
                    Evaluation defaultEvaluation = Evaluation.builder()
                            .orderId(order.getId())
                            .orderNo(order.getOrderNo())
                            .userId(order.getUserId())
                            .nurseUserId(order.getNurseUserId())
                            .rating(5)
                            .content("系统默认五星好评（超时未评价）")
                            .createTime(LocalDateTime.now())
                            .build();
                    evaluationMapper.insert(defaultEvaluation);
                }

                order.setOrderStatus(Orders.Status.EVALUATED);
                ordersMapper.updateById(order);

                if (order.getNurseUserId() != null) {
                    evaluationService.updateNurseRating(order.getNurseUserId());
                }
                log.info("订单自动评价完成: orderNo={}", order.getOrderNo());
            }

            log.info("超时未评价订单处理完成，共自动完成{}个订单", timeoutOrders.size());
        } catch (Exception e) {
            log.error("超时未评价订单处理失败", e);
        }
    }

    // ==================== 4. 护士评分批量更新（每天凌晨2点） ====================

    /**
     * 批量更新护士评分（每天凌晨2点执行）
     * 重新计算所有护士的评分，保证数据一致性
     */
    @Scheduled(cron = "0 0 2 * * ?")
    @Transactional
    public void batchUpdateNurseRatings() {
        log.info("开始批量更新护士评分...");

        try {
            // 查询所有已审核通过的护士
            LambdaQueryWrapper<NurseProfile> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(NurseProfile::getAuditStatus, NurseProfile.AuditStatus.APPROVED);

            List<NurseProfile> nurses = nurseProfileMapper.selectList(wrapper);

            int updateCount = 0;
            for (NurseProfile nurse : nurses) {
                evaluationService.updateNurseRating(nurse.getUserId());
                updateCount++;
            }

            log.info("护士评分批量更新完成，共更新{}名护士", updateCount);
        } catch (Exception e) {
            log.error("护士评分批量更新失败", e);
        }
    }
}
