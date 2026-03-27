package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.nursing.common.Result;
import com.nursing.entity.NurseProfile;
import com.nursing.entity.Orders;
import com.nursing.entity.Evaluation;
import com.nursing.entity.NurseLocation;
import com.nursing.entity.WalletLog;
import com.nursing.mapper.EvaluationMapper;
import com.nursing.mapper.NurseLocationMapper;
import com.nursing.mapper.NurseProfileMapper;
import com.nursing.mapper.OrdersMapper;
import com.nursing.mapper.SysUserMapper;
import com.nursing.mapper.WalletLogMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * 管理员仪表盘控制器
 */
@Slf4j
@RestController
@RequestMapping("/admin/stat")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminDashboardController {

    private final OrdersMapper ordersMapper;
    private final SysUserMapper sysUserMapper;
    private final NurseProfileMapper nurseProfileMapper;
    private final WalletLogMapper walletLogMapper;
        private final EvaluationMapper evaluationMapper;
        private final NurseLocationMapper nurseLocationMapper;

    /**
     * 仪表盘统计数据
     * GET /api/admin/stat/dashboard
     */
    @GetMapping("/dashboard")
    public Result<Map<String, Object>> getDashboard() {
        Map<String, Object> data = new LinkedHashMap<>();

        // 总用户数
        Long totalUsers = sysUserMapper.selectCount(null);
        data.put("totalUsers", totalUsers);

        // 总护士数（审核通过）
        Long totalNurses = nurseProfileMapper.selectCount(
                new LambdaQueryWrapper<NurseProfile>()
                        .eq(NurseProfile::getAuditStatus, NurseProfile.AuditStatus.APPROVED)
        );
        data.put("totalNurses", totalNurses);

        // 待审核护士数
        Long pendingNurses = nurseProfileMapper.selectCount(
                new LambdaQueryWrapper<NurseProfile>()
                        .eq(NurseProfile::getAuditStatus, NurseProfile.AuditStatus.PENDING)
        );
        data.put("pendingNurses", pendingNurses);

        // 总订单数
        Long totalOrders = ordersMapper.selectCount(null);
        data.put("totalOrders", totalOrders);

        // 今日订单数
        LocalDateTime todayStart = LocalDate.now().atStartOfDay();
        LocalDateTime todayEnd = LocalDate.now().atTime(LocalTime.MAX);
        Long todayOrders = ordersMapper.selectCount(
                new LambdaQueryWrapper<Orders>()
                        .between(Orders::getCreateTime, todayStart, todayEnd)
        );
        data.put("todayOrders", todayOrders);

        // 待处理订单（待接单 + 已派单）
        Long pendingOrders = ordersMapper.selectCount(
                new LambdaQueryWrapper<Orders>()
                        .in(Orders::getOrderStatus,
                                Orders.Status.PENDING_ACCEPT,
                                Orders.Status.DISPATCHED)
        );
        data.put("pendingOrders", pendingOrders);

        return Result.success(data);
    }

    /**
     * 各状态订单数量
     * GET /api/admin/stat/orderCountByStatus
     */
    @GetMapping("/orderCountByStatus")
    public Result<Map<String, Long>> getOrderCountByStatus() {
        Map<String, Long> statusCount = new LinkedHashMap<>();
        String[] statusNames = {"待支付", "待接单", "已派单", "已接单", "护士已到达", "服务中", "已完成", "已评价", "已取消", "退款中", "已退款"};

        for (int i = 0; i <= 10; i++) {
            Long count = ordersMapper.selectCount(
                    new LambdaQueryWrapper<Orders>().eq(Orders::getOrderStatus, i)
            );
            statusCount.put(statusNames[i], count);
        }
        return Result.success(statusCount);
    }

    /**
     * 收入汇总
     * GET /api/admin/stat/incomeSummary?startDate=&endDate=
     */
    @GetMapping("/incomeSummary")
    public Result<Map<String, Object>> getIncomeSummary(
            @RequestParam(required = false) String startDate,
            @RequestParam(required = false) String endDate) {

        Map<String, Object> data = new LinkedHashMap<>();

        LambdaQueryWrapper<WalletLog> wrapper = new LambdaQueryWrapper<WalletLog>()
                .eq(WalletLog::getChangeType, 1); // 收入类型

        if (startDate != null && !startDate.isBlank()) {
            LocalDateTime start = LocalDate.parse(startDate, DateTimeFormatter.ISO_DATE).atStartOfDay();
            wrapper.ge(WalletLog::getCreateTime, start);
        }
        if (endDate != null && !endDate.isBlank()) {
            LocalDateTime end = LocalDate.parse(endDate, DateTimeFormatter.ISO_DATE).atTime(LocalTime.MAX);
            wrapper.le(WalletLog::getCreateTime, end);
        }

        List<WalletLog> logs = walletLogMapper.selectList(wrapper);

        BigDecimal totalIncome = logs.stream()
                .map(WalletLog::getChangeAmount)
                .filter(Objects::nonNull)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        data.put("totalIncome", totalIncome);
        data.put("recordCount", logs.size());

        return Result.success(data);
    }

    /**
     * 实时运营概览
     */
    @GetMapping("/overviewRealtime")
    public Result<Map<String, Object>> overviewRealtime() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime todayStart = LocalDate.now().atStartOfDay();
        LocalDateTime onlineThreshold = now.minusMinutes(5);

        Long onlineNurseCount = nurseLocationMapper.selectCount(
                new LambdaQueryWrapper<NurseLocation>()
                        .ge(NurseLocation::getReportTime, onlineThreshold)
        );

        Long todayOrderCount = ordersMapper.selectCount(
                new LambdaQueryWrapper<Orders>()
                        .between(Orders::getCreateTime, todayStart, now)
        );

        List<Orders> paidTodayOrders = ordersMapper.selectList(
                new LambdaQueryWrapper<Orders>()
                        .eq(Orders::getPayStatus, Orders.PayStatusEnum.PAID)
                        .between(Orders::getPayTime, todayStart, now)
        );
        BigDecimal todayRevenue = paidTodayOrders.stream()
                .map(Orders::getTotalAmount)
                .filter(Objects::nonNull)
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        long todayFinished = ordersMapper.selectCount(
                new LambdaQueryWrapper<Orders>()
                        .in(Orders::getOrderStatus, Orders.Status.COMPLETED, Orders.Status.EVALUATED)
                        .between(Orders::getCreateTime, todayStart, now)
        );
        double completionRate = todayOrderCount == 0
                ? 0D
                : (double) todayFinished / todayOrderCount;

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("onlineNurseCount", onlineNurseCount);
        data.put("todayOrderCount", todayOrderCount);
        data.put("todayRevenue", todayRevenue);
        data.put("serviceCompletionRate", completionRate);
        return Result.success(data);
    }

    /**
     * 订单漏斗分析（下单->派单->接单->完成）
     */
    @GetMapping("/orderFunnel")
    public Result<Map<String, Object>> orderFunnel(@RequestParam(required = false) String startDate,
                                                   @RequestParam(required = false) String endDate) {
        LocalDateTime start = startDate == null || startDate.isBlank()
                ? LocalDate.now().minusDays(30).atStartOfDay()
                : LocalDate.parse(startDate, DateTimeFormatter.ISO_DATE).atStartOfDay();
        LocalDateTime end = endDate == null || endDate.isBlank()
                ? LocalDateTime.now()
                : LocalDate.parse(endDate, DateTimeFormatter.ISO_DATE).atTime(LocalTime.MAX);

        List<Orders> orders = ordersMapper.selectList(
                new LambdaQueryWrapper<Orders>()
                        .between(Orders::getCreateTime, start, end)
        );

        long placed = orders.size();
        long dispatched = orders.stream().filter(o -> o.getOrderStatus() != null && o.getOrderStatus() >= Orders.Status.DISPATCHED).count();
        long accepted = orders.stream().filter(o -> o.getOrderStatus() != null && o.getOrderStatus() >= Orders.Status.ACCEPTED).count();
        long completed = orders.stream().filter(o -> o.getOrderStatus() != null && o.getOrderStatus() >= Orders.Status.COMPLETED && o.getOrderStatus() <= Orders.Status.EVALUATED).count();

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("placed", placed);
        data.put("dispatched", dispatched);
        data.put("accepted", accepted);
        data.put("completed", completed);
        data.put("placedToDispatchedRate", placed == 0 ? 0D : (double) dispatched / placed);
        data.put("dispatchedToAcceptedRate", dispatched == 0 ? 0D : (double) accepted / dispatched);
        data.put("acceptedToCompletedRate", accepted == 0 ? 0D : (double) completed / accepted);
        data.put("overallRate", placed == 0 ? 0D : (double) completed / placed);
        return Result.success(data);
    }

    /**
     * 护士绩效排行榜
     */
    @GetMapping("/nursePerformance")
    public Result<List<Map<String, Object>>> nursePerformance(@RequestParam(defaultValue = "10") Integer topN) {
        List<NurseProfile> nurses = nurseProfileMapper.selectList(
                new LambdaQueryWrapper<NurseProfile>()
                        .eq(NurseProfile::getAuditStatus, NurseProfile.AuditStatus.APPROVED)
        );

        List<Map<String, Object>> ranking = new ArrayList<>();
        for (NurseProfile nurse : nurses) {
            Long acceptedCount = ordersMapper.selectCount(
                    new LambdaQueryWrapper<Orders>()
                            .eq(Orders::getNurseUserId, nurse.getUserId())
                            .ge(Orders::getOrderStatus, Orders.Status.ACCEPTED)
            );

            List<Evaluation> evaluations = evaluationMapper.selectList(
                    new LambdaQueryWrapper<Evaluation>()
                            .eq(Evaluation::getNurseUserId, nurse.getUserId())
            );
            double avgRating = evaluations.isEmpty()
                    ? 5D
                    : evaluations.stream().mapToInt(Evaluation::getRating).average().orElse(5D);

            double volumeScore = Math.min(acceptedCount, 50L) / 50D * 5D;
            double compositeScore = avgRating * 0.7 + volumeScore * 0.3;

            Map<String, Object> item = new LinkedHashMap<>();
            item.put("nurseUserId", nurse.getUserId());
            item.put("nurseName", nurse.getNurseName());
            item.put("hospital", nurse.getHospital());
            item.put("acceptedCount", acceptedCount);
            item.put("avgRating", avgRating);
            item.put("compositeScore", compositeScore);
            ranking.add(item);
        }

        ranking.sort((a, b) -> Double.compare(
                ((Number) b.get("compositeScore")).doubleValue(),
                ((Number) a.get("compositeScore")).doubleValue()
        ));

        int size = Math.max(1, topN == null ? 10 : topN);
        if (ranking.size() > size) {
            ranking = ranking.subList(0, size);
        }
        return Result.success(ranking);
    }

    /**
     * 订单热力图数据
     */
    @GetMapping("/orderHeatmap")
    public Result<List<Map<String, Object>>> orderHeatmap(@RequestParam(required = false) String startDate,
                                                           @RequestParam(required = false) String endDate) {
        LocalDateTime start = startDate == null || startDate.isBlank()
                ? LocalDate.now().minusDays(30).atStartOfDay()
                : LocalDate.parse(startDate, DateTimeFormatter.ISO_DATE).atStartOfDay();
        LocalDateTime end = endDate == null || endDate.isBlank()
                ? LocalDateTime.now()
                : LocalDate.parse(endDate, DateTimeFormatter.ISO_DATE).atTime(LocalTime.MAX);

        List<Orders> orders = ordersMapper.selectList(
                new LambdaQueryWrapper<Orders>()
                        .between(Orders::getCreateTime, start, end)
                        .isNotNull(Orders::getAddressLatitude)
                        .isNotNull(Orders::getAddressLongitude)
        );

        List<Map<String, Object>> points = new ArrayList<>();
        for (Orders order : orders) {
            Map<String, Object> point = new LinkedHashMap<>();
            point.put("orderNo", order.getOrderNo());
            point.put("lat", order.getAddressLatitude());
            point.put("lng", order.getAddressLongitude());
            point.put("weight", 1);
            point.put("status", order.getOrderStatus());
            points.add(point);
        }
        return Result.success(points);
    }
}
