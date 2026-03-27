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
 * 系统角色表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("role")
public class Role implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    /** 角色编码 USER/NURSE/ADMIN_SUPER */
    private String roleCode;

    /** 角色名称 */
    private String roleName;

    /** 状态 1启用 0禁用 */
    private Integer status;

    private LocalDateTime createTime;
    private LocalDateTime updateTime;
}
