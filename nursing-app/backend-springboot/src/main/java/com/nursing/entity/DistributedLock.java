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
import java.time.LocalDateTime;

/**
 * 数据库分布式锁表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("distributed_lock")
public class DistributedLock implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "lock_key", type = IdType.INPUT)
    private String lockKey;

    private String lockValue;

    private LocalDateTime expireTime;

    private LocalDateTime createTime;
}
