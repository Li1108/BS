package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.Evaluation;
import com.nursing.entity.OperationLog;
import com.nursing.mapper.EvaluationMapper;
import com.nursing.mapper.OperationLogMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

/**
 * 管理员评价控制器
 */
@Slf4j
@RestController
@RequestMapping("/admin/evaluation")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminEvaluationController {

    private final EvaluationMapper evaluationMapper;
    private final OperationLogMapper operationLogMapper;

    /**
     * 评价列表（分页+筛选）
     * GET /api/admin/evaluation/list?nurseUserId=&orderNo=&rating=&keyword=&pageNo=&pageSize=
     */
    @GetMapping("/list")
    public Result<IPage<Evaluation>> getEvaluationList(
            @RequestParam(required = false) Long nurseUserId,
            @RequestParam(required = false) String orderNo,
            @RequestParam(required = false) Integer rating,
            @RequestParam(required = false) String keyword,
            @RequestParam(defaultValue = "1") Integer pageNo,
            @RequestParam(defaultValue = "10") Integer pageSize) {

        LambdaQueryWrapper<Evaluation> wrapper = new LambdaQueryWrapper<Evaluation>()
                .eq(nurseUserId != null, Evaluation::getNurseUserId, nurseUserId)
                .eq(orderNo != null && !orderNo.isBlank(), Evaluation::getOrderNo, orderNo)
                .eq(rating != null, Evaluation::getRating, rating)
                .like(keyword != null && !keyword.isBlank(), Evaluation::getContent, keyword)
                .orderByDesc(Evaluation::getCreateTime);

        IPage<Evaluation> page = evaluationMapper.selectPage(new Page<>(pageNo, pageSize), wrapper);
        return Result.success(page);
    }

    /**
     * 评价详情
     * GET /api/admin/evaluation/detail/{id}
     */
    @GetMapping("/detail/{id}")
    public Result<Evaluation> detail(@PathVariable Long id) {
        Evaluation evaluation = evaluationMapper.selectById(id);
        if (evaluation == null) {
            return Result.notFound("评价不存在");
        }
        return Result.success(evaluation);
    }

    /**
     * 删除评价（逻辑删除 - 物理删除）
     * DELETE /api/admin/evaluation/delete/{id}
     */
    @DeleteMapping("/delete/{id}")
    public Result<Void> deleteEvaluation(@PathVariable Long id) {
        Long adminId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        Evaluation evaluation = evaluationMapper.selectById(id);
        if (evaluation == null) {
            return Result.notFound("评价不存在");
        }

        evaluationMapper.deleteById(id);

        // 写操作日志
        OperationLog opLog = OperationLog.builder()
                .adminUserId(adminId)
                .actionType("DELETE_EVALUATION")
                .actionDesc("删除评价，评价ID=" + id + "，订单号=" + evaluation.getOrderNo())
                .requestPath("/admin/evaluation/delete/" + id)
                .requestMethod("DELETE")
                .createTime(LocalDateTime.now())
                .build();
        operationLogMapper.insert(opLog);

        log.info("管理员{}删除评价, evaluationId={}", adminId, id);
        return Result.success();
    }
}
