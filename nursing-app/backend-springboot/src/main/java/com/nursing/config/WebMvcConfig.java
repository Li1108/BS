package com.nursing.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.MediaType;
import org.springframework.lang.NonNull;
import org.springframework.http.converter.HttpMessageConverter;
import org.springframework.http.converter.json.AbstractJackson2HttpMessageConverter;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

/**
 * Web MVC 配置
 * 配置静态资源映射
 */
@Configuration
public class WebMvcConfig implements WebMvcConfigurer {

    @Value("${file.upload.path:T:/static/uploads}")
    private String uploadPath;

    @Value("${file.upload.url-prefix:/uploads/}")
    private String urlPrefix;

    @Override
    public void addResourceHandlers(@NonNull ResourceHandlerRegistry registry) {
        // 映射上传文件目录
        String absolutePath = uploadPath == null ? "" : uploadPath.trim();
        if (!absolutePath.startsWith("file:")) {
            if (absolutePath.startsWith("./") || absolutePath.startsWith(".\\")) {
                Path resolved = Paths.get(System.getProperty("user.dir"))
                        .resolve(absolutePath.substring(2))
                        .toAbsolutePath()
                        .normalize();
                absolutePath = "file:/" + resolved.toString().replace("\\", "/");
            } else if (absolutePath.matches("^[A-Za-z]:[\\\\/].*")) {
                absolutePath = "file:/" + absolutePath.replace("\\", "/");
            } else if (absolutePath.startsWith("/")) {
                absolutePath = "file:" + absolutePath;
            } else {
                Path resolved = Paths.get(System.getProperty("user.dir"))
                        .resolve(absolutePath)
                        .toAbsolutePath()
                        .normalize();
                absolutePath = "file:/" + resolved.toString().replace("\\", "/");
            }
        } else {
            absolutePath = absolutePath.replace("\\", "/");
        }
        if (!absolutePath.endsWith("/")) {
            absolutePath += "/";
        }

        registry.addResourceHandler(urlPrefix + "**")
                .addResourceLocations(absolutePath);
    }

    @Override
    public void extendMessageConverters(@NonNull List<HttpMessageConverter<?>> converters) {
        MediaType jsonUtf8 = new MediaType("application", "json", StandardCharsets.UTF_8);
        for (HttpMessageConverter<?> converter : converters) {
            if (converter instanceof AbstractJackson2HttpMessageConverter jacksonConverter) {
                List<MediaType> mediaTypes = new ArrayList<>(jacksonConverter.getSupportedMediaTypes());
                if (!mediaTypes.contains(jsonUtf8)) {
                    mediaTypes.add(0, jsonUtf8);
                }
                jacksonConverter.setSupportedMediaTypes(mediaTypes);
                jacksonConverter.setDefaultCharset(StandardCharsets.UTF_8);
            }
        }
    }
}
