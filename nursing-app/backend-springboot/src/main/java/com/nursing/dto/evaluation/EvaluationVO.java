package com.nursing.dto.evaluation;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 评价VO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EvaluationVO {

    private Long id;

    private Long orderId;

    private String orderNo;

    private Long userId;

    private String userName;

    private String userAvatar;

    private Long nurseId;

    private String nurseName;

    /**
     * 评分（1-5星）
     */
    private Integer rating;

    /**
     * 评价内容
     */
    private String comment;

    /**
     * 服务名称
     */
    private String serviceName;

    /**
     * 创建时间
     */
    private LocalDateTime createdAt;
}
