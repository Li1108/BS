package com.nursing.dto.admin;

import lombok.Data;

import java.time.LocalDateTime;

/**
 * 操作日志查询请求
 */
@Data
public class OperationLogQueryRequest {

    /**
     * 操作类型
     */
    private String actionType;

    /**
     * 用户ID
     */
    private Long userId;

    /**
     * 开始时间
     */
    private LocalDateTime startTime;

    /**
     * 结束时间
     */
    private LocalDateTime endTime;

    /**
     * 页码
     */
    private int page = 1;

    /**
     * 每页数量
     */
    private int size = 20;
}
