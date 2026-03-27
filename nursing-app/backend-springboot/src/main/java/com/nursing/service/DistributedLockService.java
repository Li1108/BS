package com.nursing.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.nursing.entity.DistributedLock;
import com.nursing.mapper.DistributedLockMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;

/**
 * 基于数据库表 distributed_lock 的分布式锁
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class DistributedLockService {

    private final DistributedLockMapper distributedLockMapper;

    /**
     * 尝试获取锁
     */
    public boolean tryLock(String lockKey, String lockValue, long expireSeconds) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime expireTime = now.plusSeconds(expireSeconds);

        try {
            DistributedLock lock = DistributedLock.builder()
                    .lockKey(lockKey)
                    .lockValue(lockValue)
                    .expireTime(expireTime)
                    .createTime(now)
                    .build();
            distributedLockMapper.insert(lock);
            return true;
        } catch (DuplicateKeyException ignored) {
            // 锁已存在，继续尝试抢占过期锁
        }

        int rows = distributedLockMapper.update(
                null,
                new LambdaUpdateWrapper<DistributedLock>()
                        .eq(DistributedLock::getLockKey, lockKey)
                        .lt(DistributedLock::getExpireTime, now)
                        .set(DistributedLock::getLockValue, lockValue)
                        .set(DistributedLock::getExpireTime, expireTime)
                        .set(DistributedLock::getCreateTime, now)
        );
        return rows > 0;
    }

    /**
     * 释放锁（仅持有者可释放）
     */
    public boolean unlock(String lockKey, String lockValue) {
        int rows = distributedLockMapper.delete(
                new LambdaQueryWrapper<DistributedLock>()
                        .eq(DistributedLock::getLockKey, lockKey)
                        .eq(DistributedLock::getLockValue, lockValue)
        );
        return rows > 0;
    }

    /**
     * 清理过期锁
     */
    public int clearExpiredLocks() {
        return distributedLockMapper.delete(
                new LambdaQueryWrapper<DistributedLock>()
                        .lt(DistributedLock::getExpireTime, LocalDateTime.now())
        );
    }
}
