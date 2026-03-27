package com.nursing.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serial;
import java.io.Serializable;
import java.time.LocalDateTime;

/**
 * 护士拒单记录表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("nurse_reject_log")
public class NurseRejectLog implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long nurseUserId;
    private Long orderId;
    private String orderNo;
    private LocalDateTime rejectTime;
    private String rejectReason;
    private Integer autoFlag;
    private LocalDateTime createTime;
}
