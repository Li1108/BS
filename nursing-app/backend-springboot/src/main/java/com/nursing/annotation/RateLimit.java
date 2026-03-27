package com.nursing.annotation;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 接口限流注解
 * 用于限制接口的访问频率，防止恶意请求
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface RateLimit {
    
    /**
     * 限流Key前缀
     */
    String key() default "";
    
    /**
     * 时间窗口内最大请求次数
     */
    int maxRequests() default 10;
    
    /**
     * 时间窗口（秒）
     */
    int windowSeconds() default 60;
    
    /**
     * 限流提示消息
     */
    String message() default "请求过于频繁，请稍后再试";
    
    /**
     * 是否按用户限流（否则按IP限流）
     */
    boolean byUser() default false;
}
