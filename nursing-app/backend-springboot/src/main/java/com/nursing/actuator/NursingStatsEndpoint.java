package com.nursing.actuator;

import com.nursing.mapper.NurseProfileMapper;
import com.nursing.mapper.OrdersMapper;
import com.nursing.mapper.SysUserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.actuate.endpoint.annotation.Endpoint;
import org.springframework.boot.actuate.endpoint.annotation.ReadOperation;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * 自定义 Actuator 端点 - 业务统计
 */
@Component
@Endpoint(id = "nursing-stats")
@RequiredArgsConstructor
public class NursingStatsEndpoint {

    private final SysUserMapper sysUserMapper;
    private final OrdersMapper ordersMapper;
    private final NurseProfileMapper nurseProfileMapper;

    @ReadOperation
    public Map<String, Object> stats() {
        Map<String, Object> stats = new HashMap<>();
        
        stats.put("timestamp", LocalDateTime.now().toString());
        
        // 用户统计
        Map<String, Object> users = new HashMap<>();
        users.put("total", countTotalUsers());
        users.put("nurses", countNurses());
        users.put("activeNurses", countActiveNurses());
        stats.put("users", users);
        
        // 订单统计
        Map<String, Object> orders = new HashMap<>();
        orders.put("total", countTotalOrders());
        orders.put("today", countTodayOrders());
        orders.put("pending", countPendingOrders());
        orders.put("inProgress", countInProgressOrders());
        stats.put("orders", orders);
        
        return stats;
    }

    private long countTotalUsers() {
        try {
            return sysUserMapper.selectCount(null);
        } catch (Exception e) {
            return 0;
        }
    }

    private long countNurses() {
        try {
            return nurseProfileMapper.selectCount(null);
        } catch (Exception e) {
            return 0;
        }
    }

    private long countActiveNurses() {
        try {
            // 简化实现，实际需根据work_mode和audit_status统计
            return nurseProfileMapper.selectCount(null);
        } catch (Exception e) {
            return 0;
        }
    }

    private long countTotalOrders() {
        try {
            return ordersMapper.selectCount(null);
        } catch (Exception e) {
            return 0;
        }
    }

    private long countTodayOrders() {
        try {
            // 简化实现
            return 0;
        } catch (Exception e) {
            return 0;
        }
    }

    private long countPendingOrders() {
        try {
            // 简化实现
            return 0;
        } catch (Exception e) {
            return 0;
        }
    }

    private long countInProgressOrders() {
        try {
            // 简化实现
            return 0;
        } catch (Exception e) {
            return 0;
        }
    }
}
