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
 * 服务项目表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("service_item")
public class ServiceItem implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long categoryId;

    /** 服务名称 */
    private String serviceName;

    /** 服务描述 */
    private String serviceDesc;

    /** 封面图 /uploads/service/cover/xxx.jpg */
    private String coverImageUrl;

    /** 基础价格 */
    private BigDecimal price;

    /** 服务时长(分钟) */
    private Integer durationMinutes;

    /** 状态 1上架 0下架 */
    private Integer status;

    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
