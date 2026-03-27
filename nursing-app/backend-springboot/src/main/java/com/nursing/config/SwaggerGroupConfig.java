package com.nursing.config;

import org.springdoc.core.models.GroupedOpenApi;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * SpringDoc OpenAPI 分组配置
 * 按模块分组API文档
 */
@Configuration
public class SwaggerGroupConfig {

    /**
     * 认证模块API分组
     */
    @Bean
    public GroupedOpenApi authApi() {
        return GroupedOpenApi.builder()
                .group("1-认证模块")
                .pathsToMatch("/auth/**")
                .build();
    }

    /**
     * 用户端API分组
     */
    @Bean
    public GroupedOpenApi userApi() {
        return GroupedOpenApi.builder()
                .group("2-用户端")
                .pathsToMatch("/orders/**", "/services/**", "/evaluations/**", "/addresses/**", "/notifications/**")
                .build();
    }

    /**
     * 护士端API分组
     */
    @Bean
    public GroupedOpenApi nurseApi() {
        return GroupedOpenApi.builder()
                .group("3-护士端")
                .pathsToMatch("/nurse/**")
                .build();
    }

    /**
     * 管理后台API分组
     */
    @Bean
    public GroupedOpenApi adminApi() {
        return GroupedOpenApi.builder()
                .group("4-管理后台")
                .pathsToMatch("/admin/**")
                .build();
    }

    /**
     * 公共API分组
     */
    @Bean
    public GroupedOpenApi publicApi() {
        return GroupedOpenApi.builder()
                .group("5-公共接口")
                .pathsToMatch("/files/**", "/actuator/**")
                .build();
    }
}
