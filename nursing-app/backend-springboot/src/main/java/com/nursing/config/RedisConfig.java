package com.nursing.config;

import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.concurrent.ConcurrentMapCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 缓存配置（本地缓存，不使用Redis）
 * 本项目禁止使用Redis，所有缓存使用JVM内存ConcurrentMap实现
 * 验证码、Token黑名单等持久化存储使用MySQL表
 */
@Configuration
@EnableCaching
public class RedisConfig {

    /**
     * 使用本地ConcurrentMap缓存管理器
     * 替代Redis实现简单缓存
     */
    @Bean
    public CacheManager cacheManager() {
        return new ConcurrentMapCacheManager(
                "serviceItems",
                "sysConfig",
                "serviceCategories"
        );
    }
}
