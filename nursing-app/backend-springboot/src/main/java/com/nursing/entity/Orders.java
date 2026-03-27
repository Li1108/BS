package com.nursing.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import lombok.Builder;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import java.io.Serial;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 订单主表 order_main
 * 订单状态(规则强制): 0待支付 1待接单 2已派单 3已接单 4护士已到达 5服务中 6已完成 7已评价 8已取消 9退款中 10已退款
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("order_main")
public class Orders implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    /** 订单号 */
    private String orderNo;

    /** 下单用户ID */
    private Long userId;

    /** 护士用户ID（派单后填写） */
    private Long nurseUserId;

    /** 服务项目ID */
    private Long serviceId;

    /** 服务名称快照 */
    private String serviceNameSnapshot;

    /** 服务价格快照 */
    private BigDecimal servicePriceSnapshot;

    /** 预约时间 */
    private LocalDateTime appointmentTime;

    /** 备注 */
    private String remark;

    /** 地址快照（文本拼接） */
    private String addressSnapshot;

    /** 地址纬度 */
    private BigDecimal addressLatitude;

    /** 地址经度 */
    private BigDecimal addressLongitude;

    /** 可选项总价快照 */
    private BigDecimal optionTotalPriceSnapshot;

    /** 订单总金额 */
    private BigDecimal totalAmount;

    /** 支付状态 0未支付 1已支付 */
    private Integer payStatus;

    /** 支付方式 1支付宝 2微信 */
    private Integer payMethod;

    /** 支付时间 */
    private LocalDateTime payTime;

    /** 订单状态 0待支付 1待接单 2已派单 3已接单 4已到达 5服务中 6已完成 7已评价 8已取消 9退款中 10已退款 */
    private Integer orderStatus;

    /** 派单重试次数 */
    private Integer assignRetryCount;

    /** 上次派单时间 */
    private LocalDateTime lastAssignTime;

    /** 派单失败原因 */
    private String assignFailReason;

    /** 派单乐观锁版本号 */
    private Integer assignVersion;

    /** 护士接单时间 */
    private LocalDateTime nurseAcceptTime;

    /** 到达时间 */
    private LocalDateTime arriveTime;

    /** 开始服务时间 */
    private LocalDateTime startTime;

    /** 完成服务时间 */
    private LocalDateTime finishTime;

    /** 取消时间 */
    private LocalDateTime cancelTime;

    /** 取消原因 */
    private String cancelReason;

    /** 退款金额 */
    private BigDecimal refundAmount;

    private LocalDateTime createTime;
    private LocalDateTime updateTime;

    // ==================== 订单状态枚举（规则强制 0-10） ====================

    public static class Status {
        /** 待支付 */
        public static final int PENDING_PAYMENT = 0;
        /** 待接单 */
        public static final int PENDING_ACCEPT = 1;
        /** 已派单 */
        public static final int DISPATCHED = 2;
        /** 已接单 */
        public static final int ACCEPTED = 3;
        /** 护士已到达 */
        public static final int ARRIVED = 4;
        /** 服务中 */
        public static final int IN_SERVICE = 5;
        /** 已完成 */
        public static final int COMPLETED = 6;
        /** 已评价 */
        public static final int EVALUATED = 7;
        /** 已取消 */
        public static final int CANCELLED = 8;
        /** 退款中 */
        public static final int REFUNDING = 9;
        /** 已退款 */
        public static final int REFUNDED = 10;
    }

    public static class PayStatusEnum {
        public static final int UNPAID = 0;
        public static final int PAID = 1;
        public static final int REFUNDED = 2;
    }
}
