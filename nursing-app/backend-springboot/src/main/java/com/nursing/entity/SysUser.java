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
 * 用户账户表（所有角色共用）
 * 对应数据库 user_account 表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("user_account")
public class SysUser implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    /** 手机号 */
    private String phone;

    /** 预留密码（本项目验证码登录可为空） */
    private String password;

    /** 昵称 */
    private String nickname;

    /** 头像相对路径 /uploads/avatar/xxx.jpg */
    private String avatarUrl;

    /** 性别 0未知 1男 2女 */
    private Integer gender;

    /** 账号状态 1正常 0禁用 */
    private Integer status;

    /** 最后登录时间 */
    private LocalDateTime lastLoginTime;

    private LocalDateTime createTime;
    private LocalDateTime updateTime;

    /**
     * 当前用户角色（非数据库字段，从user_role关联查询）
     */
    @TableField(exist = false)
    private String roleCode;

    /** 状态枚举 */
    public static class StatusEnum {
        public static final int NORMAL = 1;
        public static final int DISABLED = 0;
    }
}
