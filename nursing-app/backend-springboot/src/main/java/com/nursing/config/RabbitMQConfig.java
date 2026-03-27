package com.nursing.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.lang.NonNull;

/**
 * RabbitMQ 配置
 */
@Configuration
public class RabbitMQConfig {

    // ==================== Exchange ====================
    /** 推送消息交换机 */
    public static final String PUSH_EXCHANGE = "nursing.push.exchange";

    // ==================== Queue ====================
    /** 新订单推送队列 */
    public static final String NEW_ORDER_PUSH_QUEUE = "nursing.push.new-order";
    /** 订单状态更新推送队列 */
    public static final String ORDER_STATUS_PUSH_QUEUE = "nursing.push.order-status";
    /** 通知消息队列 */
    public static final String NOTIFICATION_QUEUE = "nursing.notification";

    // ==================== Routing Key ====================
    public static final String NEW_ORDER_ROUTING_KEY = "push.new-order";
    public static final String ORDER_STATUS_ROUTING_KEY = "push.order-status";
    public static final String NOTIFICATION_ROUTING_KEY = "notification.#";

    /**
     * 推送消息交换机
     */
    @Bean
    public TopicExchange pushExchange() {
        return new TopicExchange(PUSH_EXCHANGE, true, false);
    }

    /**
     * 新订单推送队列
     */
    @Bean
    public Queue newOrderPushQueue() {
        return QueueBuilder.durable(NEW_ORDER_PUSH_QUEUE)
                .deadLetterExchange(PUSH_EXCHANGE)
                .build();
    }

    /**
     * 订单状态更新推送队列
     */
    @Bean
    public Queue orderStatusPushQueue() {
        return QueueBuilder.durable(ORDER_STATUS_PUSH_QUEUE).build();
    }

    /**
     * 通知消息队列
     */
    @Bean
    public Queue notificationQueue() {
        return QueueBuilder.durable(NOTIFICATION_QUEUE).build();
    }

    /**
     * 绑定新订单队列到交换机
     */
    @Bean
    public Binding newOrderPushBinding() {
        return BindingBuilder.bind(newOrderPushQueue())
                .to(pushExchange())
                .with(NEW_ORDER_ROUTING_KEY);
    }

    /**
     * 绑定订单状态队列到交换机
     */
    @Bean
    public Binding orderStatusPushBinding() {
        return BindingBuilder.bind(orderStatusPushQueue())
                .to(pushExchange())
                .with(ORDER_STATUS_ROUTING_KEY);
    }

    /**
     * 绑定通知队列到交换机
     */
    @Bean
    public Binding notificationBinding() {
        return BindingBuilder.bind(notificationQueue())
                .to(pushExchange())
                .with(NOTIFICATION_ROUTING_KEY);
    }

    /**
     * JSON 消息转换器
     */
    @Bean
    @NonNull
    public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    /**
     * RabbitTemplate 配置
     */
    @Bean
    public RabbitTemplate rabbitTemplate(@NonNull ConnectionFactory connectionFactory) {
        RabbitTemplate rabbitTemplate = new RabbitTemplate(connectionFactory);
        rabbitTemplate.setMessageConverter(jsonMessageConverter());
        return rabbitTemplate;
    }
}
