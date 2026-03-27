package com.nursing.dto.admin;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DashboardStatsVO {
    private Long todayOrders;
    private Long totalOrders;
    private Long totalUsers;
    private Long totalNurses;
    private Long pendingAudit;
    private Long pendingWithdrawals;
    private BigDecimal todayIncome;
    private BigDecimal totalIncome;
}

