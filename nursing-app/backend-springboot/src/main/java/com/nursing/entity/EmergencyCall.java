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
 * SOS 紧急呼叫事件
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("emergency_call")
public class EmergencyCall implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long orderId;
    private String orderNo;

    private Long userId;
    private Long nurseUserId;

    private Long callerUserId;
    /** USER/NURSE */
    private String callerRole;

    /** 1 服务风险 2 身体不适 3 其他 */
    private Integer emergencyType;

    private String description;

    /** 0待处理 1已处理 */
    private Integer status;

    private Long handledBy;
    private LocalDateTime handledTime;
    private String handleRemark;

    private LocalDateTime createTime;
    private LocalDateTime updateTime;

    public static class Status {
        public static final int PENDING = 0;
        public static final int HANDLED = 1;
    }
}
