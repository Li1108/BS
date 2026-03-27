package com.nursing.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import lombok.Builder;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import java.io.Serial;
import java.io.Serializable;
import java.time.LocalDateTime;

/**
 * 订单状态变更日志
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("order_status_log")
public class OrderStatusLog implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long orderId;
    private String orderNo;
    private Integer oldStatus;
    private Integer newStatus;

    /** 操作人（用户/护士/管理员） */
    private Long operatorUserId;

    /** USER/NURSE/ADMIN_SUPER */
    private String operatorRole;

    private String remark;
    private LocalDateTime createTime;
}
