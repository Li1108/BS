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
 * 派单记录表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("order_assign_log")
public class OrderAssignLog implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long orderId;
    private String orderNo;

    /** 第几次派单 */
    private Integer tryNo;

    /** 匹配到的护士 */
    private Long nurseUserId;

    /** 距离（km） */
    private BigDecimal distanceKm;

    /** 是否成功 1成功 0失败 */
    private Integer successFlag;

    private String failReason;
    private LocalDateTime createTime;
}
