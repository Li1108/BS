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
 * 护士位置上报表（必做）
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("nurse_location")
public class NurseLocation implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    /** 护士 user_account.id */
    private Long nurseUserId;

    /** 纬度 */
    private BigDecimal latitude;

    /** 经度 */
    private BigDecimal longitude;

    /** 上报时间 */
    private LocalDateTime reportTime;

    private LocalDateTime updateTime;
}
