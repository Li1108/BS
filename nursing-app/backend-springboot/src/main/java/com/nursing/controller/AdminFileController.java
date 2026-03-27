package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.FileAttachment;
import com.nursing.mapper.FileAttachmentMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.io.File;

/**
 * 管理员 - 文件附件管理
 */
@Slf4j
@RestController
@RequestMapping("/admin/file")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminFileController {

    private final FileAttachmentMapper fileAttachmentMapper;

    @Value("${file.upload.path:T:/static/uploads}")
    private String uploadRoot;

    /**
     * 文件附件列表（分页 + 多条件筛选）
     */
    @GetMapping("/list")
    public Result<?> list(@RequestParam(required = false) String bizType,
                          @RequestParam(required = false) String bizId,
                          @RequestParam(required = false) String uploaderRole,
                          @RequestParam(defaultValue = "1") Integer pageNo,
                          @RequestParam(defaultValue = "10") Integer pageSize) {
        Page<FileAttachment> page = new Page<>(pageNo, pageSize);
        LambdaQueryWrapper<FileAttachment> wrapper = new LambdaQueryWrapper<>();

        if (StringUtils.hasText(bizType)) {
            wrapper.eq(FileAttachment::getBizType, bizType);
        }
        if (StringUtils.hasText(bizId)) {
            wrapper.eq(FileAttachment::getBizId, bizId);
        }
        if (StringUtils.hasText(uploaderRole)) {
            wrapper.eq(FileAttachment::getUploaderRole, uploaderRole);
        }

        wrapper.orderByDesc(FileAttachment::getCreateTime);
        return Result.success(fileAttachmentMapper.selectPage(page, wrapper));
    }

    /**
     * 删除文件（数据库记录 + 物理文件）
     */
    @DeleteMapping("/delete/{id}")
    @Transactional
    public Result<?> delete(@PathVariable Long id) {
        FileAttachment attachment = fileAttachmentMapper.selectById(id);
        if (attachment == null) {
            return Result.notFound("文件记录不存在");
        }

        // 删除物理文件
        if (StringUtils.hasText(attachment.getFilePath())) {
            String normalizedRoot = uploadRoot.replace("\\", "/");
            if (normalizedRoot.endsWith("/")) {
                normalizedRoot = normalizedRoot.substring(0, normalizedRoot.length() - 1);
            }
            String relativePath = attachment.getFilePath().startsWith("/uploads/")
                    ? attachment.getFilePath().substring("/uploads/".length())
                    : attachment.getFilePath().replaceFirst("^/", "");
            File physicalFile = new File(normalizedRoot + "/" + relativePath);
            if (physicalFile.exists()) {
                boolean deleted = physicalFile.delete();
                if (!deleted) {
                    log.warn("物理文件删除失败: {}", physicalFile.getAbsolutePath());
                } else {
                    log.info("物理文件已删除: {}", physicalFile.getAbsolutePath());
                }
            } else {
                log.warn("物理文件不存在: {}", physicalFile.getAbsolutePath());
            }
        }

        // 删除数据库记录
        fileAttachmentMapper.deleteById(id);
        log.info("文件记录已删除，id={}, filePath={}", id, attachment.getFilePath());
        return Result.success("文件删除成功");
    }
}
