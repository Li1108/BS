package com.nursing.properties;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

/**
 * 文件存储配置属性
 */
@Data
@Component
@ConfigurationProperties(prefix = "file")
public class FileProperties {
    /**
     * 文件上传配置
     */
    private Upload upload = new Upload();
    
    @Data
    public static class Upload {
        /**
         * 上传文件存储路径
         */
        private String path = "T:/static/uploads";
        
        /**
         * 访问URL前缀
         */
        private String urlPrefix = "/uploads/";
        
        /**
         * 允许的文件类型
         */
        private String allowedTypes = "jpg,jpeg,png,gif,webp";
        
        /**
         * 图片压缩配置
         */
        private Compress compress = new Compress();
    }
    
    @Data
    public static class Compress {
        /**
         * 是否启用压缩
         */
        private Boolean enabled = true;
        
        /**
         * 最大宽度
         */
        private Integer maxWidth = 1920;
        
        /**
         * 最大高度
         */
        private Integer maxHeight = 1080;
        
        /**
         * 压缩质量
         */
        private Double quality = 0.85;
    }
}
