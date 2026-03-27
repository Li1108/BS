package com.nursing.dto.admin;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EvaluationStatisticsVO {
    private Long totalCount;
    private BigDecimal avgRating;
    private Long fiveStarCount;
    private BigDecimal fiveStarRate;
    private Long lowRatingCount;
    private List<RatingDistributionItem> distribution;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class RatingDistributionItem {
        private Integer rating;
        private Long count;
    }
}

