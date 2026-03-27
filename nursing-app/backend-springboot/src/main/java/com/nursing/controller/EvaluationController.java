package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.Evaluation;
import com.nursing.entity.Orders;
import com.nursing.mapper.EvaluationMapper;
import com.nursing.mapper.OrdersMapper;
import com.nursing.service.EvaluationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 评价控制器
 */
@Slf4j
@RestController
@RequestMapping("/evaluation")
@RequiredArgsConstructor
public class EvaluationController {

    private final EvaluationMapper evaluationMapper;
    private final OrdersMapper ordersMapper;
    private final EvaluationService evaluationService;

    /**
     * 提交评价
     * POST /api/evaluation/submit
     * body: { orderNo, rating, content }
     */
    @PostMapping("/submit")
    public Result<Evaluation> submitEvaluation(@RequestBody Map<String, Object> body) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        String orderNo = (String) body.get("orderNo");
        Integer rating = body.get("rating") != null ? Integer.parseInt(body.get("rating").toString()) : null;
        String content = (String) body.get("content");

        if (orderNo == null || orderNo.isBlank()) {
            return Result.badRequest("订单号不能为空");
        }
        if (rating == null || rating < 1 || rating > 5) {
            return Result.badRequest("评分必须在1-5之间");
        }

        // 1. 查找订单
        Orders order = ordersMapper.selectOne(
                new LambdaQueryWrapper<Orders>().eq(Orders::getOrderNo, orderNo)
        );
        if (order == null) {
            return Result.notFound("订单不存在");
        }

        // 2. 校验订单属于当前用户
        if (!order.getUserId().equals(userId)) {
            return Result.forbidden("无权评价此订单");
        }

        // 3. 校验订单状态为6（已完成）
        if (order.getOrderStatus() != Orders.Status.COMPLETED) {
            return Result.badRequest("只有已完成的订单才能评价");
        }

        // 4. 检查是否已评价（评价提交后不可修改）
        Long existCount = evaluationMapper.selectCount(
                new LambdaQueryWrapper<Evaluation>().eq(Evaluation::getOrderNo, orderNo)
        );
        if (existCount > 0) {
            return Result.badRequest("该订单已评价，不可重复提交");
        }

        // 5. 创建评价记录
        Evaluation evaluation = Evaluation.builder()
                .orderId(order.getId())
                .orderNo(orderNo)
                .userId(userId)
                .nurseUserId(order.getNurseUserId())
                .rating(rating)
                .content(content)
                .createTime(LocalDateTime.now())
                .build();
        evaluationMapper.insert(evaluation);

        // 6. 更新订单状态为7（已评价）
        order.setOrderStatus(Orders.Status.EVALUATED);
        order.setUpdateTime(LocalDateTime.now());
        ordersMapper.updateById(order);

        if (order.getNurseUserId() != null) {
            evaluationService.updateNurseRating(order.getNurseUserId());
        }

        log.info("用户{}对订单{}提交评价，评分={}", userId, orderNo, rating);
        return Result.success(evaluation);
    }

    /**
     * 获取订单评价（公开接口）
     * GET /api/evaluation/order/{orderNo}
     */
    @GetMapping("/order/{orderNo}")
    public Result<Evaluation> getOrderEvaluation(@PathVariable String orderNo) {
        Evaluation evaluation = evaluationMapper.selectOne(
                new LambdaQueryWrapper<Evaluation>().eq(Evaluation::getOrderNo, orderNo)
        );
        if (evaluation == null) {
            return Result.notFound("该订单暂无评价");
        }
        return Result.success(evaluation);
    }

    /**
     * 提交追评（仅支持评价后7天内）
     * POST /api/evaluation/followup
     * body: { orderNo, content }
     */
    @PostMapping("/followup")
    public Result<Evaluation> submitFollowup(@RequestBody Map<String, Object> body) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        String orderNo = body.get("orderNo") == null ? null : body.get("orderNo").toString();
        String content = body.get("content") == null ? "" : body.get("content").toString().trim();

        if (orderNo == null || orderNo.isBlank()) {
            return Result.badRequest("订单号不能为空");
        }
        if (content.isBlank()) {
            return Result.badRequest("追评内容不能为空");
        }

        Evaluation evaluation = evaluationMapper.selectOne(
                new LambdaQueryWrapper<Evaluation>().eq(Evaluation::getOrderNo, orderNo)
        );
        if (evaluation == null) {
            return Result.notFound("该订单暂无评价，无法追评");
        }
        if (!userId.equals(evaluation.getUserId())) {
            return Result.forbidden("无权追评此订单");
        }

        LocalDateTime createdAt = evaluation.getCreateTime();
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
        long days = Duration.between(createdAt, LocalDateTime.now()).toDays();
        if (days > 7) {
            return Result.badRequest("追评窗口已关闭（仅支持评价后7天内）");
        }

        String oldContent = evaluation.getContent() == null ? "" : evaluation.getContent().trim();
        String followupLine = "【追评 " + LocalDateTime.now().toString().replace('T', ' ').substring(0, 16) + "】" + content;
        String merged = oldContent.isEmpty() ? followupLine : oldContent + "\n" + followupLine;

        evaluation.setContent(merged);
        evaluationMapper.updateById(evaluation);
        return Result.success(evaluation);
    }

    /**
     * 我的评价历史
     * GET /api/evaluation/my/list
     */
    @GetMapping("/my/list")
    public Result<?> myEvaluationList(@RequestParam(defaultValue = "1") Integer pageNo,
                                      @RequestParam(defaultValue = "10") Integer pageSize) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        IPage<Evaluation> page = evaluationMapper.selectPage(
                new Page<>(pageNo, pageSize),
                new LambdaQueryWrapper<Evaluation>()
                        .eq(Evaluation::getUserId, userId)
                        .orderByDesc(Evaluation::getCreateTime)
        );

        List<Map<String, Object>> records = page.getRecords().stream().map(item -> {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("id", item.getId());
            row.put("orderId", item.getOrderId());
            row.put("order_id", item.getOrderId());
            row.put("orderNo", item.getOrderNo());
            row.put("order_no", item.getOrderNo());
            row.put("rating", item.getRating());
            row.put("content", item.getContent());
            row.put("createTime", item.getCreateTime());
            row.put("create_time", item.getCreateTime());
            return row;
        }).toList();

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("records", records);
        result.put("total", page.getTotal());
        result.put("pageNo", pageNo);
        result.put("pageSize", pageSize);
        return Result.success(result);
    }
}
