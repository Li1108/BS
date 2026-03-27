package com.nursing.config;

import io.micrometer.core.aop.TimedAspect;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Actuator 监控配置
 */
@Configuration
public class ActuatorConfig {

    /**
     * 启用 @Timed 注解支持
     * 可以在方法上添加 @Timed 注解来自动记录方法执行时间
     */
    @Bean
    public TimedAspect timedAspect(MeterRegistry registry) {
        return new TimedAspect(registry);
    }
}
