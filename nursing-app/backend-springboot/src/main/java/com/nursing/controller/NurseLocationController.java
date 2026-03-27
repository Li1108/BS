package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.nursing.common.Result;
import com.nursing.entity.NurseLocation;
import com.nursing.mapper.NurseLocationMapper;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 护士位置上报控制器
 */
@Slf4j
@RestController
@RequestMapping("/nurse/location")
@RequiredArgsConstructor
public class NurseLocationController {

    private final NurseLocationMapper nurseLocationMapper;

    /**
     * 护士上报位置（upsert：按 nurseUserId 插入或更新）
     * POST /nurse/location/report
     */
    @PostMapping("/report")
    public Result<?> reportLocation(@RequestBody LocationReportRequest request) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        if (request.getLatitude() == null || request.getLongitude() == null) {
            return Result.badRequest("经纬度不能为空");
        }

        LocalDateTime now = LocalDateTime.now();

        // 查找是否已有记录
        NurseLocation existing = nurseLocationMapper.selectOne(
                new LambdaQueryWrapper<NurseLocation>()
                        .eq(NurseLocation::getNurseUserId, userId)
        );

        if (existing != null) {
            // 更新
            existing.setLatitude(request.getLatitude());
            existing.setLongitude(request.getLongitude());
            existing.setReportTime(now);
            existing.setUpdateTime(now);
            nurseLocationMapper.updateById(existing);
        } else {
            // 插入
            NurseLocation location = NurseLocation.builder()
                    .nurseUserId(userId)
                    .latitude(request.getLatitude())
                    .longitude(request.getLongitude())
                    .reportTime(now)
                    .updateTime(now)
                    .build();
            nurseLocationMapper.insert(location);
        }

        log.info("护士位置上报成功: userId={}, lat={}, lng={}", userId, request.getLatitude(), request.getLongitude());
        return Result.success();
    }

    /**
     * 获取当前护士最新位置
     * GET /nurse/location/latest
     */
    @GetMapping("/latest")
    public Result<NurseLocation> getLatestLocation() {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        NurseLocation location = nurseLocationMapper.selectOne(
                new LambdaQueryWrapper<NurseLocation>()
                        .eq(NurseLocation::getNurseUserId, userId)
        );

        if (location == null) {
            return Result.notFound("暂无位置记录");
        }

        return Result.success(location);
    }

    // ==================== 请求体 ====================

    @Data
    public static class LocationReportRequest {
        private BigDecimal latitude;
        private BigDecimal longitude;
    }
}
