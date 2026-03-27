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
 * 服务项目可选项表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("service_item_option")
public class ServiceItemOption implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long serviceId;

    /** 可选项名称 */
    private String optionName;

    /** 可选项加价 */
    private BigDecimal optionPrice;

    /** 状态 1启用 0禁用 */
    private Integer status;

    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
