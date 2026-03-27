package com.nursing.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.nursing.entity.*;
import com.nursing.mapper.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;

/**
 * 评价业务服务
 * 注意：NurseProfile 表中没有 rating 字段，护士评分暂不存储
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class EvaluationService {

    private final EvaluationMapper evaluationMapper;
    private final NurseProfileMapper nurseProfileMapper;

    @Transactional
    public void updateNurseRating(Long nurseUserId) {
        NurseProfile profile = nurseProfileMapper.selectOne(
                new LambdaQueryWrapper<NurseProfile>()
                        .eq(NurseProfile::getUserId, nurseUserId)
                        .last("LIMIT 1")
        );
        if (profile == null) {
            log.warn("更新护士评分失败，护士资料不存在: nurseUserId={}", nurseUserId);
            return;
        }

        Long count = evaluationMapper.countByNurseUserId(nurseUserId);
        BigDecimal finalRating;

        if (count == null || count == 0) {
            finalRating = BigDecimal.valueOf(5.0);
        } else {
            Double avg = evaluationMapper.avgRatingByNurseUserId(nurseUserId);
            finalRating = BigDecimal.valueOf(avg == null ? 5.0 : avg)
                    .setScale(1, RoundingMode.HALF_UP);
        }

        profile.setRating(finalRating);
        nurseProfileMapper.updateById(profile);

        log.info("护士评分更新完成: nurseUserId={}, 评价数量={}, 评分={}", nurseUserId, count == null ? 0 : count, finalRating);
    }
}
