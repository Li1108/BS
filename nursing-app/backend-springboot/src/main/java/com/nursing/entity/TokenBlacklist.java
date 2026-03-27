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
 * Token黑名单表（退出登录/踢下线，无Redis替代方案）
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("token_blacklist")
public class TokenBlacklist implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long userId;

    /** JWT token */
    private String token;

    /** token过期时间 */
    private LocalDateTime expireTime;

    private LocalDateTime createTime;
}
