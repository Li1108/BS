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
 * 系统配置表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("system_config")
public class SysConfig implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private String configKey;
    private String configValue;
    private String remark;
    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
