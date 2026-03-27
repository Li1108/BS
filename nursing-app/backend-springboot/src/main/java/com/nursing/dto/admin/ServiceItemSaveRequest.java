package com.nursing.dto.admin;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class ServiceItemSaveRequest {
    @NotBlank
    private String name;

    @NotNull
    private BigDecimal price;

    private String description;

    private String iconUrl;

    @NotNull
    private Integer status;

    private String category;
}

