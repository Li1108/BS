package com.nursing.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import lombok.Builder;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import java.io.Serial;
import java.io.Serializable;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 普通用户扩展资料表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("user_profile")
public class UserProfile implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long userId;

    /** 真实姓名 */
    private String realName;

    /** 身份证号（可选） */
    private String idCardNo;

    private LocalDate birthday;

    /** 紧急联系人 */
    private String emergencyContact;

    /** 紧急联系电话 */
    private String emergencyPhone;

    /** 实名认证状态：0-未认证，1-已认证 */
    @Builder.Default
    private Integer realNameVerified = 0;

    /** 实名认证时间 */
    private LocalDateTime realNameVerifyTime;

    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
