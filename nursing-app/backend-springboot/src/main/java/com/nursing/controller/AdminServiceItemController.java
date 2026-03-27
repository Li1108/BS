package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.common.Result;
import com.nursing.entity.OperationLog;
import com.nursing.entity.ServiceCategory;
import com.nursing.entity.ServiceItem;
import com.nursing.entity.ServiceItemOption;
import com.nursing.mapper.OperationLogMapper;
import com.nursing.mapper.ServiceCategoryMapper;
import com.nursing.mapper.ServiceItemMapper;
import com.nursing.mapper.ServiceItemOptionMapper;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * 管理员 - 服务分类与服务项目管理
 */
@Slf4j
@RestController
@RequestMapping("/admin/service")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminServiceItemController {

    private final ServiceCategoryMapper serviceCategoryMapper;
    private final ServiceItemMapper serviceItemMapper;
    private final ServiceItemOptionMapper serviceItemOptionMapper;
    private final OperationLogMapper operationLogMapper;

    /**
     * 分类列表（后台）
     */
    @GetMapping("/category/list")
    public Result<List<ServiceCategory>> categoryList() {
        List<ServiceCategory> categories = serviceCategoryMapper.selectList(
                new LambdaQueryWrapper<ServiceCategory>().orderByAsc(ServiceCategory::getSortNo)
        );
        return Result.success(categories);
    }

    /**
     * 服务项目列表（后台，分页）
     */
    @GetMapping("/item/list")
    public Result<Page<ServiceItem>> itemList(@RequestParam(required = false) Long categoryId,
                                              @RequestParam(required = false) Integer status,
                                              @RequestParam(required = false) String keyword,
                                              @RequestParam(defaultValue = "1") Integer pageNo,
                                              @RequestParam(defaultValue = "10") Integer pageSize) {
        LambdaQueryWrapper<ServiceItem> wrapper = new LambdaQueryWrapper<ServiceItem>()
                .eq(categoryId != null, ServiceItem::getCategoryId, categoryId)
                .eq(status != null, ServiceItem::getStatus, status)
                .and(StringUtils.hasText(keyword),
                        w -> w.like(ServiceItem::getServiceName, keyword)
                                .or().like(ServiceItem::getServiceDesc, keyword))
                .orderByDesc(ServiceItem::getCreateTime);
        Page<ServiceItem> page = serviceItemMapper.selectPage(new Page<>(pageNo, pageSize), wrapper);
        return Result.success(page);
    }

    // ==================== 服务分类 ====================

    /**
     * 添加服务分类
     */
    @PostMapping("/category/add")
    public Result<?> addCategory(@RequestBody ServiceCategory category, HttpServletRequest request) {
        category.setCreateTime(LocalDateTime.now());
        category.setUpdateTime(LocalDateTime.now());
        serviceCategoryMapper.insert(category);

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("ADD_SERVICE_CATEGORY")
                .actionDesc("添加服务分类，categoryName=" + category.getCategoryName())
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams(category.toString())
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]添加服务分类[{}]", adminUserId, category.getCategoryName());
        return Result.success(category);
    }

    /**
     * 更新服务分类
     */
    @PutMapping("/category/update/{id}")
    public Result<?> updateCategory(@PathVariable Long id,
                                    @RequestBody ServiceCategory category,
                                    HttpServletRequest request) {
        ServiceCategory existing = serviceCategoryMapper.selectById(id);
        if (existing == null) {
            return Result.notFound("服务分类不存在");
        }

        category.setId(id);
        category.setUpdateTime(LocalDateTime.now());
        serviceCategoryMapper.updateById(category);

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("UPDATE_SERVICE_CATEGORY")
                .actionDesc("更新服务分类，id=" + id + "，categoryName=" + category.getCategoryName())
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams(category.toString())
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]更新服务分类[{}]", adminUserId, id);
        return Result.success(category);
    }

    /**
     * 批量更新分类排序
     */
    @PostMapping("/category/sort")
    public Result<?> sortCategory(@RequestBody List<Map<String, Object>> items,
                                  HttpServletRequest request) {
        if (items == null || items.isEmpty()) {
            return Result.badRequest("排序数据不能为空");
        }

        for (Map<String, Object> item : items) {
            if (item == null || item.get("id") == null || item.get("sortNo") == null) {
                continue;
            }
            Long id = Long.parseLong(String.valueOf(item.get("id")));
            Integer sortNo = Integer.parseInt(String.valueOf(item.get("sortNo")));
            ServiceCategory category = serviceCategoryMapper.selectById(id);
            if (category == null) {
                continue;
            }
            category.setSortNo(sortNo);
            category.setUpdateTime(LocalDateTime.now());
            serviceCategoryMapper.updateById(category);
        }

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("SORT_SERVICE_CATEGORY")
                .actionDesc("批量更新服务分类排序，count=" + items.size())
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("count=" + items.size())
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        return Result.success(true);
    }

    // ==================== 服务项目 ====================

    /**
     * 添加服务项目
     */
    @PostMapping("/item/add")
    public Result<?> addItem(@RequestBody ServiceItem item, HttpServletRequest request) {
        item.setCreateTime(LocalDateTime.now());
        item.setUpdateTime(LocalDateTime.now());
        serviceItemMapper.insert(item);

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("ADD_SERVICE_ITEM")
                .actionDesc("添加服务项目，serviceName=" + item.getServiceName())
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams(item.toString())
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]添加服务项目[{}]", adminUserId, item.getServiceName());
        return Result.success(item);
    }

    /**
     * 更新服务项目
     */
    @PutMapping("/item/update/{id}")
    public Result<?> updateItem(@PathVariable Long id,
                                @RequestBody ServiceItem item,
                                HttpServletRequest request) {
        ServiceItem existing = serviceItemMapper.selectById(id);
        if (existing == null) {
            return Result.notFound("服务项目不存在");
        }

        item.setId(id);
        item.setUpdateTime(LocalDateTime.now());
        serviceItemMapper.updateById(item);

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("UPDATE_SERVICE_ITEM")
                .actionDesc("更新服务项目，id=" + id + "，serviceName=" + item.getServiceName())
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams(item.toString())
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]更新服务项目[{}]", adminUserId, id);
        return Result.success(item);
    }

    /**
     * 删除服务项目
     */
    @DeleteMapping("/item/delete/{id}")
    public Result<?> deleteItem(@PathVariable Long id, HttpServletRequest request) {
        ServiceItem existing = serviceItemMapper.selectById(id);
        if (existing == null) {
            return Result.notFound("服务项目不存在");
        }

        serviceItemMapper.deleteById(id);

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("DELETE_SERVICE_ITEM")
                .actionDesc("删除服务项目，id=" + id + "，serviceName=" + existing.getServiceName())
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("id=" + id)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]删除服务项目[{}]", adminUserId, id);
        return Result.success("服务项目已删除");
    }

    /**
     * 更新服务上下架状态
     */
    @PostMapping("/item/status/{id}")
    public Result<?> updateItemStatus(@PathVariable Long id,
                                      @RequestBody Map<String, Integer> body,
                                      HttpServletRequest request) {
        ServiceItem existing = serviceItemMapper.selectById(id);
        if (existing == null) {
            return Result.notFound("服务项目不存在");
        }
        Integer status = body.get("status");
        if (status == null || (status != 0 && status != 1)) {
            return Result.badRequest("状态参数错误");
        }
        existing.setStatus(status);
        existing.setUpdateTime(LocalDateTime.now());
        serviceItemMapper.updateById(existing);

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("UPDATE_SERVICE_ITEM_STATUS")
                .actionDesc("更新服务项目状态，id=" + id + "，status=" + status)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("id=" + id + ", status=" + status)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        return Result.success(existing);
    }

    /**
     * 批量更新服务上下架状态
     */
    @PostMapping("/item/status/batch")
    public Result<?> batchUpdateItemStatus(@RequestBody Map<String, Object> body,
                                           HttpServletRequest request) {
        Object idsObj = body == null ? null : body.get("ids");
        Integer status = body == null ? null : (Integer) body.get("status");
        if (!(idsObj instanceof List<?> ids) || ids.isEmpty()) {
            return Result.badRequest("ids 不能为空");
        }
        if (status == null || (status != 0 && status != 1)) {
            return Result.badRequest("status 参数错误");
        }

        int updated = 0;
        for (Object obj : ids) {
            Long id;
            try {
                id = Long.parseLong(String.valueOf(obj));
            } catch (Exception e) {
                continue;
            }
            ServiceItem item = serviceItemMapper.selectById(id);
            if (item == null) continue;
            item.setStatus(status);
            item.setUpdateTime(LocalDateTime.now());
            serviceItemMapper.updateById(item);
            updated++;
        }

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("BATCH_UPDATE_SERVICE_ITEM_STATUS")
                .actionDesc("批量更新服务项目状态，status=" + status + "，count=" + updated)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("count=" + updated)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        return Result.success(Map.of("updated", updated));
    }

    // ==================== 服务可选项 ====================

    @GetMapping("/option/list")
    public Result<?> optionList(@RequestParam(required = false) Long serviceId) {
        return Result.success(serviceItemOptionMapper.selectList(
                new LambdaQueryWrapper<ServiceItemOption>()
                        .eq(serviceId != null, ServiceItemOption::getServiceId, serviceId)
                        .orderByDesc(ServiceItemOption::getCreateTime)
        ));
    }

    @PostMapping("/option/add")
    public Result<?> addOption(@RequestBody ServiceItemOption option) {
        option.setCreateTime(LocalDateTime.now());
        option.setUpdateTime(LocalDateTime.now());
        if (option.getStatus() == null) {
            option.setStatus(1);
        }
        serviceItemOptionMapper.insert(option);
        return Result.success(option);
    }

    @PutMapping("/option/update/{id}")
    public Result<?> updateOption(@PathVariable Long id, @RequestBody ServiceItemOption option) {
        ServiceItemOption existing = serviceItemOptionMapper.selectById(id);
        if (existing == null) {
            return Result.notFound("服务可选项不存在");
        }
        option.setId(id);
        option.setUpdateTime(LocalDateTime.now());
        serviceItemOptionMapper.updateById(option);
        return Result.success(option);
    }

    @DeleteMapping("/option/delete/{id}")
    public Result<?> deleteOption(@PathVariable Long id) {
        ServiceItemOption existing = serviceItemOptionMapper.selectById(id);
        if (existing == null) {
            return Result.notFound("服务可选项不存在");
        }
        serviceItemOptionMapper.deleteById(id);
        return Result.success(true);
    }
}
