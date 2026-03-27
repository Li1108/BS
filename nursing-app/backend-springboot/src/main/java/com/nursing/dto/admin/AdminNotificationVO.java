package com.nursing.dto.admin;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AdminNotificationVO {
    private Long id;
    private Long userId;
    private String userName;
    private Integer type;
    private String content;
    private Integer isRead;
    private LocalDateTime createdAt;
}

