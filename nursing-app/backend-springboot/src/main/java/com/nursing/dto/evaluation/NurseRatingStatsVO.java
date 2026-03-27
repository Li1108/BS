package com.nursing.dto.evaluation;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * 护士评价统计VO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NurseRatingStatsVO {

    /**
     * 护士ID
     */
    private Long nurseId;

    /**
     * 护士姓名
     */
    private String nurseName;

    /**
     * 平均评分
     */
    private BigDecimal averageRating;

    /**
     * 总评价数
     */
    private Integer totalCount;

    /**
     * 5星评价数
     */
    private Integer fiveStarCount;

    /**
     * 4星评价数
     */
    private Integer fourStarCount;

    /**
     * 3星评价数
     */
    private Integer threeStarCount;

    /**
     * 2星评价数
     */
    private Integer twoStarCount;

    /**
     * 1星评价数
     */
    private Integer oneStarCount;

    /**
     * 好评率（4-5星占比）
     */
    private BigDecimal positiveRate;
}
