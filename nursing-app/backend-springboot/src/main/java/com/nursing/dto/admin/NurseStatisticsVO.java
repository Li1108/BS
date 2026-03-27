package com.nursing.dto.admin;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NurseStatisticsVO {
    private Long totalCount;
    private Long pendingCount;
    private Long approvedCount;
    private Long rejectedCount;
    private Long disabledCount;
}

