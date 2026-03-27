package com.nursing.config;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.enums.SecuritySchemeIn;
import io.swagger.v3.oas.annotations.enums.SecuritySchemeType;
import io.swagger.v3.oas.annotations.info.Contact;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.info.License;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.security.SecurityScheme;
import io.swagger.v3.oas.annotations.servers.Server;
import org.springframework.context.annotation.Configuration;

/**
 * OpenAPI (Swagger) 配置
 */
@Configuration
@OpenAPIDefinition(
        info = @Info(
                title = "互联网+护理服务APP API",
                version = "1.0",
                description = "护理服务APP后端API文档，包含用户端、护士端、管理后台接口",
                contact = @Contact(
                        name = "开发者",
                        email = "developer@example.com"
                ),
                license = @License(
                        name = "Apache 2.0",
                        url = "https://www.apache.org/licenses/LICENSE-2.0.html"
                )
        ),
        servers = {
                @Server(url = "http://localhost:8081", description = "本地开发环境"),
                @Server(url = "https://api.example.com", description = "生产环境")
        },
        security = @SecurityRequirement(name = "Bearer Token")
)
@SecurityScheme(
        name = "Bearer Token",
        type = SecuritySchemeType.HTTP,
        scheme = "bearer",
        bearerFormat = "JWT",
        in = SecuritySchemeIn.HEADER,
        description = "请输入JWT Token"
)
public class OpenApiConfig {
}
