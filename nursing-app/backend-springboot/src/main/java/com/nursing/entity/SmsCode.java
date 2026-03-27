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
 * 短信验证码记录表（无Redis替代方案）
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("sms_code")
public class SmsCode implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    /** 手机号 */
    private String phone;

    /** 验证码 */
    private String code;

    /** 过期时间 */
    private LocalDateTime expireTime;

    /** 是否使用 0未使用 1已使用 */
    private Integer usedFlag;

    private LocalDateTime createTime;
}
