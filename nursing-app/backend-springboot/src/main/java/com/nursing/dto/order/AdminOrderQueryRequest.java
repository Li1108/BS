package com.nursing.dto.order;

import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 管理员订单查询请求
 */
@Data
public class AdminOrderQueryRequest {
    /**
     * 订单ID集合（逗号分隔），用于“勾选导出”等场景
     */
    private String ids;

    /**
     * 联系人姓名（模糊匹配）
     */
    private String contactName;

    /**
     * 订单状态
     */
    private Integer status;

    /**
     * 状态列表（多选）
     */
    private List<Integer> statuses;

    /**
     * 支付状态
     */
    private Integer payStatus;

    /**
     * 订单号
     */
    private String orderNo;

    /**
     * 用户ID
     */
    private Long userId;

    /**
     * 护士ID
     */
    private Long nurseId;

    /**
     * 服务ID
     */
    private Long serviceId;

    /**
     * 用户手机号
     */
    private String userPhone;

    /**
     * 护士手机号
     */
    private String nursePhone;

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
    private Integer page = 1;

    /**
     * 每页数量
     */
    private Integer size = 10;
}
