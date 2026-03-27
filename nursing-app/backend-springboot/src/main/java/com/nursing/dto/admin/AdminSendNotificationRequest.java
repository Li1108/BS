package com.nursing.dto.admin;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;

@Data
public class AdminSendNotificationRequest {
    @NotNull
    private Integer type;

    @NotBlank
    private String content;

    private List<Long> userIds;
}

