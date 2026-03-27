package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.nursing.common.Result;
import com.nursing.entity.NurseLocation;
import com.nursing.entity.NurseProfile;
import com.nursing.entity.OrderAssignLog;
import com.nursing.entity.Orders;
import com.nursing.mapper.NurseLocationMapper;
import com.nursing.mapper.NurseProfileMapper;
import com.nursing.mapper.OrderAssignLogMapper;
import com.nursing.mapper.OrdersMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 手动派单控制器（管理员/测试用）
 */
@Slf4j
@RestController
@RequestMapping("/dispatch")
@RequiredArgsConstructor
public class DispatchController {

    private final OrdersMapper ordersMapper;
    private final NurseProfileMapper nurseProfileMapper;
    private final NurseLocationMapper nurseLocationMapper;
    private final OrderAssignLogMapper orderAssignLogMapper;

    /**
     * 手动触发派单
     * POST /dispatch/manualTrigger/{orderNo}
     */
    @PostMapping("/manualTrigger/{orderNo}")
    public Result<?> manualTrigger(@PathVariable String orderNo) {
        // 1. 查找订单
        Orders order = ordersMapper.selectOne(
                new LambdaQueryWrapper<Orders>()
                        .eq(Orders::getOrderNo, orderNo)
        );
        if (order == null) {
            return Result.notFound("订单不存在: " + orderNo);
        }

        // 2. 校验订单状态必须是 1（待接单）
        if (!Integer.valueOf(Orders.Status.PENDING_ACCEPT).equals(order.getOrderStatus())) {
            return Result.badRequest("订单状态不是待接单，当前状态: " + order.getOrderStatus());
        }

        // 3. 查找可用护士：审核通过 + 开启接单
        List<NurseProfile> availableNurses = nurseProfileMapper.selectList(
                new LambdaQueryWrapper<NurseProfile>()
                        .eq(NurseProfile::getAuditStatus, NurseProfile.AuditStatus.APPROVED)
                        .eq(NurseProfile::getAcceptEnabled, 1)
        );

        if (availableNurses.isEmpty()) {
            log.warn("派单失败: 没有可用护士, orderNo={}", orderNo);
            writeAssignLog(order, null, 0, "没有可用护士（审核通过且开启接单）");
            return Result.error("没有可用护士");
        }

        // 4. 进一步过滤：位置在10分钟内上报过的护士
        LocalDateTime tenMinutesAgo = LocalDateTime.now().minusMinutes(10);
        NurseProfile assignedNurse = null;

        for (NurseProfile nurse : availableNurses) {
            NurseLocation location = nurseLocationMapper.selectOne(
                    new LambdaQueryWrapper<NurseLocation>()
                            .eq(NurseLocation::getNurseUserId, nurse.getUserId())
                            .ge(NurseLocation::getReportTime, tenMinutesAgo)
            );
            if (location != null) {
                assignedNurse = nurse;
                break;
            }
        }

        if (assignedNurse == null) {
            log.warn("派单失败: 没有最近上报位置的护士, orderNo={}", orderNo);
            writeAssignLog(order, null, 0, "没有护士在10分钟内上报位置");
            return Result.error("没有最近上报位置的可用护士");
        }

        // 5. 分配护士，更新订单状态为 2（已派单）
        order.setNurseUserId(assignedNurse.getUserId());
        order.setOrderStatus(Orders.Status.DISPATCHED);
        order.setLastAssignTime(LocalDateTime.now());
        order.setAssignRetryCount(
                (order.getAssignRetryCount() == null ? 0 : order.getAssignRetryCount()) + 1
        );
        ordersMapper.updateById(order);

        // 6. 写入派单记录
        writeAssignLog(order, assignedNurse.getUserId(), 1, null);

        log.info("手动派单成功: orderNo={}, nurseUserId={}", orderNo, assignedNurse.getUserId());
        return Result.success("派单成功，已分配护士: " + assignedNurse.getNurseName(), null);
    }

    /**
     * 写入 order_assign_log
     */
    private void writeAssignLog(Orders order, Long nurseUserId, int successFlag, String failReason) {
        OrderAssignLog assignLog = OrderAssignLog.builder()
                .orderId(order.getId())
                .orderNo(order.getOrderNo())
                .tryNo((order.getAssignRetryCount() == null ? 0 : order.getAssignRetryCount()) + 1)
                .nurseUserId(nurseUserId)
                .successFlag(successFlag)
                .failReason(failReason)
                .createTime(LocalDateTime.now())
                .build();
        orderAssignLogMapper.insert(assignLog);
    }
}
