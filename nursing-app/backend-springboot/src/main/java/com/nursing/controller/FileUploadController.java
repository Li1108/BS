package com.nursing.controller;

import com.nursing.common.Result;
import com.nursing.entity.FileAttachment;
import com.nursing.mapper.FileAttachmentMapper;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * 文件上传控制器
 */
@Slf4j
@RestController
@RequestMapping("/upload")
@RequiredArgsConstructor
public class FileUploadController {

    private final FileAttachmentMapper fileAttachmentMapper;

    @Value("${file.upload.path:T:/static/uploads}")
    private String uploadRoot;

    /**
     * 上传图片
     * POST /api/upload/image
     * multipart: file, bizType, bizId
     */
    @PostMapping("/image")
    public Result<Map<String, String>> uploadImage(
            HttpServletRequest request,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "bizType", defaultValue = "common") String bizType,
            @RequestParam(value = "bizId", required = false) String bizId) {

        if (file.isEmpty()) {
            return Result.badRequest("上传文件不能为空");
        }

        // 校验文件类型
        String contentType = file.getContentType();
        if (contentType == null || !contentType.startsWith("image/")) {
            return Result.badRequest("只允许上传图片文件");
        }

        try {
            // 获取当前用户信息
            Long userId = null;
            String uploaderRole = "ANONYMOUS";
            var auth = SecurityContextHolder.getContext().getAuthentication();
            if (auth != null && auth.getPrincipal() instanceof Long) {
                userId = (Long) auth.getPrincipal();
                // 获取角色
                var authorities = auth.getAuthorities();
                if (authorities != null && !authorities.isEmpty()) {
                    String authority = authorities.iterator().next().getAuthority();
                    uploaderRole = authority.replace("ROLE_", "");
                }
            }

            // 构建存储路径: T:/static/uploads/{bizType}/{yyyyMMdd}/{uuid}.{ext}
            String dateDir = LocalDate.now().format(DateTimeFormatter.ofPattern("yyyyMMdd"));
            String originalFilename = file.getOriginalFilename();
            String ext = "";
            if (originalFilename != null && originalFilename.contains(".")) {
                ext = originalFilename.substring(originalFilename.lastIndexOf("."));
            }
            String newFileName = UUID.randomUUID().toString().replace("-", "") + ext;

            String normalizedRoot = uploadRoot.replace("\\", "/");
            if (normalizedRoot.endsWith("/")) {
                normalizedRoot = normalizedRoot.substring(0, normalizedRoot.length() - 1);
            }

            String dirPath = normalizedRoot + "/" + bizType + "/" + dateDir;
            File dir = new File(dirPath);
            if (!dir.exists() && !dir.mkdirs()) {
                return Result.error("创建上传目录失败");
            }

            // 保存文件
            File destFile = new File(dir, newFileName);
            file.transferTo(destFile);

            // 相对路径（数据库存储）
            String filePath = "/uploads/" + bizType + "/" + dateDir + "/" + newFileName;
            // 完整访问URL
                String fileUrl = request.getScheme() + "://" + request.getServerName() + ":" + request.getServerPort()
                    + request.getContextPath() + filePath;

            // 记录到file_attachment表
            FileAttachment attachment = FileAttachment.builder()
                    .uploaderUserId(userId)
                    .uploaderRole(uploaderRole)
                    .bizType(bizType)
                    .bizId(bizId)
                    .fileName(originalFilename)
                    .filePath(filePath)
                    .fileSize(file.getSize())
                    .fileType(contentType)
                    .createTime(LocalDateTime.now())
                    .build();
            fileAttachmentMapper.insert(attachment);

            // 返回
            Map<String, String> data = new LinkedHashMap<>();
            data.put("filePath", filePath);
            data.put("fileUrl", fileUrl);

            log.info("文件上传成功: userId={}, bizType={}, filePath={}", userId, bizType, filePath);
            return Result.success(data);

        } catch (IOException e) {
            log.error("文件上传失败: {}", e.getMessage(), e);
            return Result.error("文件上传失败：" + e.getMessage());
        }
    }
}
