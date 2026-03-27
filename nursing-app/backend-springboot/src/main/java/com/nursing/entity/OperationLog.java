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
 * 管理员操作日志表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("admin_action_log")
public class OperationLog implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long adminUserId;

    /** 操作类型 */
    private String actionType;

    /** 操作描述 */
    private String actionDesc;

    private String requestPath;
    private String requestMethod;
    private String requestParams;
    private String ip;
    private LocalDateTime createTime;
}
