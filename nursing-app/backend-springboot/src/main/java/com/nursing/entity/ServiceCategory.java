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
 * 服务分类表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("service_category")
public class ServiceCategory implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    /** 分类名称 */
    private String categoryName;

    /** 排序 */
    private Integer sortNo;

    /** 状态 1上架 0下架 */
    private Integer status;

    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
