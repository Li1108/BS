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
 * 用户地址表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("user_address")
public class UserAddress implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long userId;

    /** 联系人 */
    private String contactName;

    /** 联系电话 */
    private String contactPhone;

    private String province;
    private String city;
    private String district;

    /** 详细地址 */
    private String detailAddress;

    /** 纬度 */
    private BigDecimal latitude;

    /** 经度 */
    private BigDecimal longitude;

    /** 是否默认 1是 0否 */
    private Integer isDefault;

    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
