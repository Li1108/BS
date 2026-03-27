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
 * 订单评价表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("evaluation")
public class Evaluation implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long orderId;
    private String orderNo;
    private Long userId;
    private Long nurseUserId;

    /** 评分 1-5 */
    private Integer rating;

    /** 评价内容 */
    private String content;

    private LocalDateTime createTime;
}
