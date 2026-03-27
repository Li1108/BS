package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.conditions.update.LambdaUpdateWrapper;
import com.nursing.common.Result;
import com.nursing.entity.UserAddress;
import com.nursing.mapper.UserAddressMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 用户地址控制器
 */
@Slf4j
@RestController
@RequestMapping("/user/address")
@RequiredArgsConstructor
public class UserAddressController {

    private final UserAddressMapper userAddressMapper;

    /**
     * 获取当前用户地址列表
     * GET /api/user/address/list
     */
    @GetMapping("/list")
    public Result<List<UserAddress>> getAddressList() {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        List<UserAddress> list = userAddressMapper.selectList(
                new LambdaQueryWrapper<UserAddress>()
                        .eq(UserAddress::getUserId, userId)
                        .orderByDesc(UserAddress::getIsDefault)
                        .orderByDesc(UserAddress::getUpdateTime)
        );
        return Result.success(list);
    }

    /**
     * 添加地址
     * POST /api/user/address/add
     */
    @PostMapping("/add")
    public Result<UserAddress> addAddress(@RequestBody UserAddress address) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        address.setId(null);
        address.setUserId(userId);
        address.setCreateTime(LocalDateTime.now());
        address.setUpdateTime(LocalDateTime.now());
        if (address.getIsDefault() == null) {
            address.setIsDefault(0);
        }

        // 如果设为默认，先清除其他默认
        if (address.getIsDefault() == 1) {
            clearDefaultAddress(userId);
        }

        userAddressMapper.insert(address);
        log.info("用户{}添加地址, addressId={}", userId, address.getId());
        return Result.success(address);
    }

    /**
     * 更新地址
     * PUT /api/user/address/update/{id}
     */
    @PutMapping("/update/{id}")
    public Result<UserAddress> updateAddress(@PathVariable Long id, @RequestBody UserAddress address) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        // 校验地址属于当前用户
        UserAddress existing = userAddressMapper.selectById(id);
        if (existing == null) {
            return Result.notFound("地址不存在");
        }
        if (!existing.getUserId().equals(userId)) {
            return Result.forbidden("无权操作此地址");
        }

        address.setId(id);
        address.setUserId(userId);
        address.setUpdateTime(LocalDateTime.now());

        // 如果设为默认，先清除其他默认
        if (address.getIsDefault() != null && address.getIsDefault() == 1) {
            clearDefaultAddress(userId);
        }

        userAddressMapper.updateById(address);
        UserAddress updated = userAddressMapper.selectById(id);
        return Result.success(updated);
    }

    /**
     * 删除地址
     * DELETE /api/user/address/delete/{id}
     */
    @DeleteMapping("/delete/{id}")
    public Result<Void> deleteAddress(@PathVariable Long id) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        // 校验地址属于当前用户
        UserAddress existing = userAddressMapper.selectById(id);
        if (existing == null) {
            return Result.notFound("地址不存在");
        }
        if (!existing.getUserId().equals(userId)) {
            return Result.forbidden("无权操作此地址");
        }

        userAddressMapper.deleteById(id);
        log.info("用户{}删除地址, addressId={}", userId, id);
        return Result.success();
    }

    /**
     * 设置默认地址
     * POST /api/user/address/setDefault/{id}
     */
    @PostMapping("/setDefault/{id}")
    public Result<Void> setDefaultAddress(@PathVariable Long id) {
        Long userId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        // 校验地址属于当前用户
        UserAddress existing = userAddressMapper.selectById(id);
        if (existing == null) {
            return Result.notFound("地址不存在");
        }
        if (!existing.getUserId().equals(userId)) {
            return Result.forbidden("无权操作此地址");
        }

        // 1. 清除所有默认
        clearDefaultAddress(userId);

        // 2. 设置当前地址为默认
        existing.setIsDefault(1);
        existing.setUpdateTime(LocalDateTime.now());
        userAddressMapper.updateById(existing);

        log.info("用户{}设置默认地址, addressId={}", userId, id);
        return Result.success();
    }

    /**
     * 清除用户所有默认地址
     */
    private void clearDefaultAddress(Long userId) {
        userAddressMapper.update(null,
                new LambdaUpdateWrapper<UserAddress>()
                        .eq(UserAddress::getUserId, userId)
                        .eq(UserAddress::getIsDefault, 1)
                        .set(UserAddress::getIsDefault, 0)
                        .set(UserAddress::getUpdateTime, LocalDateTime.now())
        );
    }
}
