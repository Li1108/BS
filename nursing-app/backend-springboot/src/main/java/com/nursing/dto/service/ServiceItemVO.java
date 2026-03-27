package com.nursing.dto.service;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * 服务项目VO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ServiceItemVO {

    private Long id;

    private String name;

    private BigDecimal price;

    private String description;

    private String iconUrl;

    private String category;
}
