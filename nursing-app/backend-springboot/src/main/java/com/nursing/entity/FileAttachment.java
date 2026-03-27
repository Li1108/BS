package com.nursing.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import lombok.Builder;
import lombok.NoArgsConstructor;
import lombok.AllArgsConstructor;

import java.io.Serial;
import java.io.Serializable;
import java.time.LocalDateTime;

/**
 * 文件附件统一表
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@TableName("file_attachment")
public class FileAttachment implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    @TableId(value = "id", type = IdType.AUTO)
    private Long id;

    private Long uploaderUserId;

    /** USER/NURSE/ADMIN_SUPER */
    private String uploaderRole;

    /** 业务类型 ORDER/NURSE/SERVICE/AVATAR */
    private String bizType;

    /** 业务ID，如 orderNo */
    private String bizId;

    private String fileName;

    /** 相对路径 /uploads/xxx/xxx.jpg */
    private String filePath;

    /** 文件大小byte */
    private Long fileSize;

    /** image/jpeg等 */
    private String fileType;

    private LocalDateTime createTime;
}
