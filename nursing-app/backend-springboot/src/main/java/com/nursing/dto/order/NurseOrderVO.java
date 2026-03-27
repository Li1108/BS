package com.nursing.dto.order;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 护士端订单VO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NurseOrderVO {

    private Long id;

    private String orderNo;

    // ==================== 用户信息 ====================
    private Long userId;

    private String userName;

    private String userPhone;

    private String userAvatar;

    // ==================== 服务信息 ====================
    private Long serviceId;

    private String serviceName;

    private BigDecimal servicePrice;

    // ==================== 费用信息 ====================
    private BigDecimal totalAmount;

    private BigDecimal nurseIncome;

    // ==================== 地址信息 ====================
    private String contactName;

    private String contactPhone;

    private String address;

    private BigDecimal latitude;

    private BigDecimal longitude;

    /**
     * 距离（米）
     */
    private Long distance;

    /**
     * 距离文本
     */
    // ==================== 时间信息 ====================
    private LocalDateTime appointmentTime;

    private String remark;

    // ==================== 状态信息 ====================
    /**
     * 订单状态：2已接单, 3已到达, 4服务中, 5待评价, 6已完成
     */
    private Integer status;

    // ==================== 服务过程 ====================
    private LocalDateTime arrivalTime;

    private String arrivalPhoto;

    private LocalDateTime startTime;

    private String startPhoto;

    private LocalDateTime finishTime;

    private String finishPhoto;

    // ==================== 时间戳 ====================
    private LocalDateTime createdAt;

    /**
     * 获取状态文本
     */
    public String getStatusText() {
        if (status == null) return "";
        return switch (status) {
            case 1 -> "待接单";
            case 2 -> "已接单";
            case 3 -> "已到达";
            case 4 -> "服务中";
            case 5 -> "待评价";
            case 6 -> "已完成";
            case 7 -> "已取消";
            default -> "未知";
        };
    }

    /**
     * 获取距离文本
     */
    public String getDistanceText() {
        if (distance == null) return "";
        if (distance < 1000) {
            return distance + "m";
        }
        return String.format("%.1fkm", distance / 1000.0);
    }
}
