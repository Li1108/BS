package com.nursing.dto.admin;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NurseLocationVO {
    private Long userId;
    private String realName;
    private String phone;
    private Integer status;
    private Integer workMode;
    private BigDecimal rating;
    private String serviceArea;
    private BigDecimal locationLat;
    private BigDecimal locationLng;
}

