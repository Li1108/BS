package com.nursing.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serial;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 服务打卡照片表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("service_checkin_photo")
public class ServiceCheckinPhoto implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long orderId;
    private String orderNo;
    private Long nurseUserId;

    /** 1到达现场 2开始服务 3完成服务 */
    private Integer checkinType;

    private String photoUrl;
    private String photoDesc;
    private BigDecimal latitude;
    private BigDecimal longitude;
    private LocalDateTime createTime;
}
