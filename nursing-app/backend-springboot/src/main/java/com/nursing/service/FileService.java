package com.nursing.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import net.coobird.thumbnailator.Thumbnails;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Arrays;
import java.util.Base64;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

/**
 * 文件上传服务
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class FileService {

    @Value("${file.upload.path:./static/uploads/}")
    private String uploadPath;

    @Value("${file.upload.url-prefix:/uploads/}")
    private String urlPrefix;

    @Value("${file.upload.allowed-types:jpg,jpeg,png,gif,webp}")
    private String allowedTypes;

    @Value("${file.upload.compress.enabled:true}")
    private boolean compressEnabled;

    @Value("${file.upload.compress.max-width:1920}")
    private int maxWidth;

    @Value("${file.upload.compress.max-height:1080}")
    private int maxHeight;

    @Value("${file.upload.compress.quality:0.85}")
    private double quality;

    /**
     * 允许的图片类型
     */
    private static final List<String> IMAGE_TYPES = Arrays.asList("jpg", "jpeg", "png", "gif", "webp");

    /**
     * 上传文件（简化方法）
     */
    public String uploadFile(MultipartFile file, String type) throws IOException {
        return uploadFile(file, type, true);
    }

    /**
     * 上传Base64图片
     */
    public String uploadBase64(String base64Data, String subDir) throws IOException {
        // 处理data URL格式
        String pureBase64 = base64Data;
        String extension = "png";
        
        if (base64Data.contains(",")) {
            String[] parts = base64Data.split(",");
            pureBase64 = parts[1];
            // 从data:image/png;base64,提取扩展名
            if (parts[0].contains("/")) {
                String mimeType = parts[0].split("/")[1].split(";")[0];
                extension = mimeType.equals("jpeg") ? "jpg" : mimeType;
            }
        }

        if (!isAllowedType(extension) || !isImageType(extension)) {
            throw new IllegalArgumentException("不支持的图片类型: " + extension);
        }
        
        // 解码Base64
        byte[] imageBytes = Base64.getDecoder().decode(pureBase64);
        
        // 生成存储路径
        String datePath = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy/MM"));
        String fileName = UUID.randomUUID().toString().replace("-", "") + "." + extension;
        String relativePath = (StringUtils.hasText(subDir) ? subDir + "/" : "") + datePath + "/" + fileName;
        
        // 创建目录
        Path fullPath = Paths.get(uploadPath, relativePath);
        Files.createDirectories(fullPath.getParent());
        
        // 保存文件
        File destFile = Objects.requireNonNull(fullPath.toFile());
        
        if (compressEnabled && isImageType(extension)) {
            // 压缩图片
            Thumbnails.of(new ByteArrayInputStream(imageBytes))
                    .size(maxWidth, maxHeight)
                    .keepAspectRatio(true)
                    .outputQuality(quality)
                    .outputFormat(extension.equals("jpg") ? "jpeg" : extension)
                    .toFile(destFile);
        } else {
            Files.write(fullPath, imageBytes);
        }
        
        log.info("Base64图片上传成功: {}", relativePath);
        return urlPrefix + relativePath;
    }

    /**
     * 上传文件
     *
     * @param file     文件
     * @param subDir   子目录（如 avatars, certificates）
     * @param compress 是否压缩（仅图片有效）
     * @return 文件访问URL（相对路径）
     */
    public String uploadFile(MultipartFile file, String subDir, boolean compress) throws IOException {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("文件不能为空");
        }

        // 获取文件扩展名
        String originalFilename = file.getOriginalFilename();
        String extension = getFileExtension(originalFilename);

        // 验证文件类型
        if (!isAllowedType(extension)) {
            throw new IllegalArgumentException("不支持的文件类型: " + extension);
        }

        // 生成存储路径：uploads/subDir/yyyy/MM/uuid.ext
        String datePath = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyy/MM"));
        String fileName = UUID.randomUUID().toString().replace("-", "") + "." + extension;
        String relativePath = (StringUtils.hasText(subDir) ? subDir + "/" : "") + datePath + "/" + fileName;

        // 创建目录
        Path fullPath = Paths.get(uploadPath, relativePath);
        Files.createDirectories(fullPath.getParent());

        // 保存文件
        File destFile = Objects.requireNonNull(fullPath.toFile());

        if (compress && compressEnabled && isImageType(extension)) {
            // 压缩图片
            compressAndSaveImage(file, destFile, extension);
        } else {
            // 直接保存
            file.transferTo(destFile);
        }

        log.info("文件上传成功: {}", relativePath);
        return urlPrefix + relativePath;
    }

    /**
     * 上传图片（自动压缩）
     *
     * @param file   文件
     * @param subDir 子目录
     * @return 文件访问URL
     */
    public String uploadImage(MultipartFile file, String subDir) throws IOException {
        return uploadFile(file, subDir, true);
    }

    /**
     * 上传头像
     *
     * @param file 文件
     * @return 文件访问URL
     */
    public String uploadAvatar(MultipartFile file) throws IOException {
        return uploadImage(file, "avatars");
    }

    /**
     * 上传护士证件照片
     *
     * @param file 文件
     * @param type 类型：id_card_front, id_card_back, certificate
     * @return 文件访问URL
     */
    public String uploadNurseCertificate(MultipartFile file, String type) throws IOException {
        return uploadImage(file, "certificates/" + type);
    }

    /**
     * 上传订单照片
     *
     * @param file    文件
     * @param orderId 订单ID
     * @param stage   阶段：arrival, start, finish
     * @return 文件访问URL
     */
    public String uploadOrderPhoto(MultipartFile file, Long orderId, String stage) throws IOException {
        return uploadImage(file, "orders/" + orderId + "/" + stage);
    }

    /**
     * 删除文件
     *
     * @param fileUrl 文件URL（相对路径）
     * @return 是否删除成功
     */
    public boolean deleteFile(String fileUrl) {
        if (!StringUtils.hasText(fileUrl)) {
            return false;
        }

        try {
            // 移除URL前缀，获取相对路径
            if (!fileUrl.startsWith(urlPrefix)) {
                return false;
            }
            String relativePath = fileUrl.substring(urlPrefix.length());
            Path filePath = Paths.get(uploadPath, relativePath);

            if (Files.exists(filePath)) {
                Files.delete(filePath);
                log.info("文件删除成功: {}", fileUrl);
                return true;
            }
        } catch (Exception e) {
            log.error("文件删除失败: {}", fileUrl, e);
        }
        return false;
    }

    /**
     * 压缩并保存图片
     */
    private void compressAndSaveImage(MultipartFile file, @NonNull File destFile, String extension) throws IOException {
        // 使用Thumbnailator压缩图片
        Thumbnails.of(file.getInputStream())
                .size(maxWidth, maxHeight)
                .keepAspectRatio(true)
                .outputQuality(quality)
                .outputFormat(extension.equals("jpg") ? "jpeg" : extension)
                .toFile(destFile);
    }

    /**
     * 获取文件扩展名
     */
    private String getFileExtension(String filename) {
        if (filename == null || !filename.contains(".")) {
            return "";
        }
        return filename.substring(filename.lastIndexOf(".") + 1).toLowerCase();
    }

    /**
     * 检查文件类型是否允许
     */
    private boolean isAllowedType(String extension) {
        if (!StringUtils.hasText(extension)) {
            return false;
        }
        List<String> allowed = Arrays.asList(allowedTypes.split(","));
        return allowed.contains(extension.toLowerCase());
    }

    /**
     * 检查是否为图片类型
     */
    private boolean isImageType(String extension) {
        return IMAGE_TYPES.contains(extension.toLowerCase());
    }
}
