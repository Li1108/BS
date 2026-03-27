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
 * 通知表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("notification")
public class Notification implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long receiverUserId;

    /** USER/NURSE/ADMIN_SUPER */
    private String receiverRole;

    private String title;
    private String content;

    /** 业务类型 ORDER/PAY/REFUND/WITHDRAW */
    private String bizType;

    /** 业务ID，例如orderNo */
    private String bizId;

    /** 是否已读 0未读 1已读 */
    private Integer readFlag;

    private LocalDateTime createTime;
}
