package com.nursing.config;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.concurrent.TimeUnit;

/**
 * 自定义监控指标
 */
@Component
@RequiredArgsConstructor
public class CustomMetrics {

    private final MeterRegistry meterRegistry;

    /**
     * 记录订单创建
     */
    public void recordOrderCreated() {
        Counter.builder("nursing.orders.created")
                .description("订单创建数量")
                .register(meterRegistry)
                .increment();
    }

    /**
     * 记录订单完成
     */
    public void recordOrderCompleted() {
        Counter.builder("nursing.orders.completed")
                .description("订单完成数量")
                .register(meterRegistry)
                .increment();
    }

    /**
     * 记录订单取消
     */
    public void recordOrderCancelled() {
        Counter.builder("nursing.orders.cancelled")
                .description("订单取消数量")
                .register(meterRegistry)
                .increment();
    }

    /**
     * 记录用户登录
     */
    public void recordUserLogin(String role) {
        Counter.builder("nursing.auth.login")
                .tag("role", role)
                .description("用户登录次数")
                .register(meterRegistry)
                .increment();
    }

    /**
     * 记录短信发送
     */
    public void recordSmsSent(boolean success) {
        Counter.builder("nursing.sms.sent")
                .tag("success", String.valueOf(success))
                .description("短信发送次数")
                .register(meterRegistry)
                .increment();
    }

    /**
     * 记录推送发送
     */
    public void recordPushSent(boolean success) {
        Counter.builder("nursing.push.sent")
                .tag("success", String.valueOf(success))
                .description("推送发送次数")
                .register(meterRegistry)
                .increment();
    }

    /**
     * 记录API调用时间
     */
    public void recordApiTime(String endpoint, long durationMs) {
        Timer.builder("nursing.api.duration")
                .tag("endpoint", endpoint)
                .description("API调用耗时")
                .register(meterRegistry)
                .record(durationMs, TimeUnit.MILLISECONDS);
    }

    /**
     * 记录护士上线
     */
    public void recordNurseOnline() {
        Counter.builder("nursing.nurse.online")
                .description("护士上线次数")
                .register(meterRegistry)
                .increment();
    }

    /**
     * 记录提现申请
     */
    public void recordWithdrawalApply() {
        Counter.builder("nursing.withdrawal.apply")
                .description("提现申请次数")
                .register(meterRegistry)
                .increment();
    }
}
