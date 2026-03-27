package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.nursing.common.Result;
import com.nursing.entity.ServiceCategory;
import com.nursing.entity.ServiceItem;
import com.nursing.entity.ServiceItemOption;
import com.nursing.mapper.ServiceCategoryMapper;
import com.nursing.mapper.ServiceItemMapper;
import com.nursing.mapper.ServiceItemOptionMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 服务项目控制器（公开接口，无需认证）
 */
@Slf4j
@RestController
@RequestMapping("/service")
@RequiredArgsConstructor
public class ServiceItemController {

    private final ServiceCategoryMapper serviceCategoryMapper;
    private final ServiceItemMapper serviceItemMapper;
    private final ServiceItemOptionMapper serviceItemOptionMapper;

    /**
     * 获取所有服务分类（上架状态）
     * GET /api/service/category/list
     */
    @GetMapping("/category/list")
    public Result<List<ServiceCategory>> getCategoryList() {
        List<ServiceCategory> list = serviceCategoryMapper.selectList(
                new LambdaQueryWrapper<ServiceCategory>()
                        .eq(ServiceCategory::getStatus, 1)
                        .orderByAsc(ServiceCategory::getSortNo)
        );
        return Result.success(list);
    }

    /**
     * 获取服务项目列表（上架状态），可按分类筛选
     * GET /api/service/item/list?categoryId=
     */
    @GetMapping("/item/list")
    public Result<List<ServiceItem>> getItemList(
            @RequestParam(required = false) Long categoryId) {
        LambdaQueryWrapper<ServiceItem> wrapper = new LambdaQueryWrapper<ServiceItem>()
                .eq(ServiceItem::getStatus, 1)
                .eq(categoryId != null, ServiceItem::getCategoryId, categoryId)
                .orderByDesc(ServiceItem::getCreateTime);
        List<ServiceItem> list = serviceItemMapper.selectList(wrapper);
        return Result.success(list);
    }

    /**
     * 获取服务项目详情
     * GET /api/service/item/detail/{id}
     */
    @GetMapping("/item/detail/{id}")
    public Result<ServiceItem> getItemDetail(@PathVariable Long id) {
        ServiceItem item = serviceItemMapper.selectById(id);
        if (item == null) {
            return Result.notFound("服务项目不存在");
        }
        return Result.success(item);
    }

    /**
     * 获取服务的可选项列表
     * GET /api/service/item/options/{serviceId}
     */
    @GetMapping("/item/options/{serviceId}")
    public Result<List<ServiceItemOption>> getItemOptions(@PathVariable Long serviceId) {
        List<ServiceItemOption> list = serviceItemOptionMapper.selectList(
                new LambdaQueryWrapper<ServiceItemOption>()
                        .eq(ServiceItemOption::getServiceId, serviceId)
                        .eq(ServiceItemOption::getStatus, 1)
                        .orderByAsc(ServiceItemOption::getId)
        );
        return Result.success(list);
    }
}
