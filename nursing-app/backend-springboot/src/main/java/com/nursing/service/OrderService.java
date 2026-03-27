package com.nursing.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.nursing.dto.order.CreateOrderRequest;
import com.nursing.dto.order.OrderVO;
import com.nursing.entity.*;
import com.nursing.mapper.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.UUID;

/**
 * 订单业务服务
 * 对应数据库 order_main 表
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class OrderService {

    private final OrdersMapper ordersMapper;
    private final ServiceItemMapper serviceItemMapper;
    private final ServiceItemOptionMapper serviceItemOptionMapper;
    private final OrderOptionMapper orderOptionMapper;
    private final UserAddressMapper userAddressMapper;
    private final RefundRecordMapper refundRecordMapper;
    private final OrderStatusLogMapper orderStatusLogMapper;
    private final NotificationMapper notificationMapper;
    private final AlipayService alipayService;

    /**
     * 创建订单
     */
    @Transactional
    public OrderVO createOrder(Long userId, CreateOrderRequest request) {
        // 1. 获取服务信息
        ServiceItem service = serviceItemMapper.selectById(request.getServiceId());
        if (service == null || service.getStatus() != 1) {
            throw new RuntimeException("服务不存在或已下架");
        }

        // 2. 处理地址
        UserAddress userAddress = userAddressMapper.selectById(request.getAddressId());
        if (userAddress == null || !userAddress.getUserId().equals(userId)) {
            throw new RuntimeException("地址不存在");
        }
        String addressSnapshot = buildAddressSnapshot(userAddress);

        // 3. 计算可选项总价
        BigDecimal optionTotalPrice = BigDecimal.ZERO;
        List<Long> optionIds = request.getOptionIds();
        if (optionIds != null && !optionIds.isEmpty()) {
            for (Long optionId : optionIds) {
                ServiceItemOption option = serviceItemOptionMapper.selectById(optionId);
                if (option != null && option.getStatus() == 1) {
                    optionTotalPrice = optionTotalPrice.add(option.getOptionPrice());
                }
            }
        }

        // 4. 计算订单总金额
        BigDecimal totalAmount = service.getPrice().add(optionTotalPrice);

        // 5. 生成订单号
        String orderNo = generateOrderNo();

        // 6. 创建订单
        Orders order = Orders.builder()
                .orderNo(orderNo)
                .userId(userId)
                .serviceId(service.getId())
                .serviceNameSnapshot(service.getServiceName())
                .servicePriceSnapshot(service.getPrice())
                .appointmentTime(request.getAppointmentTime())
                .remark(request.getRemark())
                .addressSnapshot(addressSnapshot)
                .addressLatitude(userAddress.getLatitude())
                .addressLongitude(userAddress.getLongitude())
                .optionTotalPriceSnapshot(optionTotalPrice)
                .totalAmount(totalAmount)
                .orderStatus(Orders.Status.PENDING_PAYMENT)
                .payStatus(Orders.PayStatusEnum.UNPAID)
                .assignRetryCount(0)
                .assignVersion(0)
                .createTime(LocalDateTime.now())
                .updateTime(LocalDateTime.now())
                .build();

        ordersMapper.insert(order);

        // 7. 保存订单可选项快照
        if (optionIds != null) {
            for (Long optionId : optionIds) {
                ServiceItemOption option = serviceItemOptionMapper.selectById(optionId);
                if (option != null && option.getStatus() == 1) {
                    OrderOption orderOption = OrderOption.builder()
                            .orderId(order.getId())
                            .serviceOptionId(optionId)
                            .optionNameSnapshot(option.getOptionName())
                            .optionPriceSnapshot(option.getOptionPrice())
                            .createTime(LocalDateTime.now())
                            .build();
                    orderOptionMapper.insert(orderOption);
                }
            }
        }

        // 8. 写入订单状态日志
        writeStatusLog(order, null, Orders.Status.PENDING_PAYMENT, userId, "USER", "创建订单");

        // 9. 创建消息通知（用户侧）
        notificationMapper.insert(Notification.builder()
            .receiverUserId(userId)
            .receiverRole("USER")
            .title("订单创建成功")
            .content("您的订单（" + orderNo + "）已创建，请在30分钟内完成支付。")
            .bizType("ORDER")
            .bizId(String.valueOf(order.getId()))
            .readFlag(0)
            .createTime(LocalDateTime.now())
            .build());

        log.info("订单创建成功: orderNo={}, userId={}, serviceId={}, amount={}",
                orderNo, userId, service.getId(), totalAmount);

        return toVO(order);
    }

    /**
     * 获取用户订单列表
     */
    public IPage<OrderVO> getUserOrders(Long userId, Integer status, int pageNo, int pageSize) {
        Page<Orders> page = new Page<>(pageNo, pageSize);
        LambdaQueryWrapper<Orders> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Orders::getUserId, userId);
        if (status != null) {
            wrapper.eq(Orders::getOrderStatus, status);
        }
        wrapper.orderByDesc(Orders::getCreateTime);

        IPage<Orders> ordersPage = ordersMapper.selectPage(page, wrapper);
        return ordersPage.convert(this::toVO);
    }

    /**
     * 获取订单详情（通过订单号）
     */
    public OrderVO getOrderByOrderNo(String orderNo) {
        LambdaQueryWrapper<Orders> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Orders::getOrderNo, orderNo);
        Orders order = ordersMapper.selectOne(wrapper);
        if (order == null) {
            return null;
        }
        return toVO(order);
    }

    /**
     * 取消订单
     */
    @Transactional
    public boolean cancelOrder(Long userId, Long orderId, String cancelReason) {
        Orders order = ordersMapper.selectById(orderId);
        if (order == null) {
            throw new RuntimeException("订单不存在");
        }
        if (!order.getUserId().equals(userId)) {
            throw new RuntimeException("无权操作此订单");
        }

        int oldStatus = order.getOrderStatus();
        boolean paid = order.getPayStatus() != null
            && order.getPayStatus() == Orders.PayStatusEnum.PAID;

        if (oldStatus == Orders.Status.PENDING_PAYMENT && !paid) {
            // 未支付直接取消
            order.setOrderStatus(Orders.Status.CANCELLED);
            order.setCancelTime(LocalDateTime.now());
            order.setCancelReason(cancelReason);
            order.setUpdateTime(LocalDateTime.now());
            ordersMapper.updateById(order);
            writeStatusLog(order, oldStatus, Orders.Status.CANCELLED, userId, "USER", cancelReason);
                notificationMapper.insert(Notification.builder()
                    .receiverUserId(userId)
                    .receiverRole("USER")
                    .title("订单已取消")
                    .content("您的订单（" + order.getOrderNo() + "）已取消。")
                    .bizType("ORDER")
                    .bizId(String.valueOf(order.getId()))
                    .readFlag(0)
                    .createTime(LocalDateTime.now())
                    .build());
            log.info("未支付订单取消成功: orderId={}", orderId);
            return true;
        }

        if (paid && (oldStatus == Orders.Status.PENDING_PAYMENT || oldStatus == Orders.Status.PENDING_ACCEPT)) {
            // 已支付订单（含支付回写延迟仍为待支付状态）-> 退款中
            order.setOrderStatus(Orders.Status.REFUNDING);
            order.setCancelTime(LocalDateTime.now());
            order.setCancelReason(cancelReason);
            order.setRefundAmount(order.getTotalAmount());
            order.setUpdateTime(LocalDateTime.now());
            ordersMapper.updateById(order);

                // 创建退款记录（幂等）
            RefundRecord existing = refundRecordMapper.selectOne(
                    new LambdaQueryWrapper<RefundRecord>().eq(RefundRecord::getOrderNo, order.getOrderNo())
            );
                LocalDateTime now = LocalDateTime.now();
                RefundRecord refundRecord = existing;
            if (existing == null) {
                refundRecord = RefundRecord.builder()
                        .orderId(order.getId())
                        .orderNo(order.getOrderNo())
                        .refundAmount(order.getTotalAmount())
                        .refundStatus(0)
                        .refundReason(cancelReason)
                    .createTime(now)
                    .updateTime(now)
                    .build();
                refundRecordMapper.insert(refundRecord);
            }

            writeStatusLog(order, oldStatus, Orders.Status.REFUNDING, userId, "USER", cancelReason);

                // 调用支付宝退款
                String refundNo = "RFD" + DateTimeFormatter.ofPattern("yyyyMMddHHmmss").format(now)
                    + UUID.randomUUID().toString().replace("-", "").substring(0, 6).toUpperCase();
                boolean refunded = alipayService.refund(
                    order.getOrderNo(),
                    refundNo,
                    order.getTotalAmount(),
                    cancelReason
                );

                if (refunded) {
                order.setOrderStatus(Orders.Status.REFUNDED);
                order.setPayStatus(Orders.PayStatusEnum.REFUNDED);
                order.setUpdateTime(LocalDateTime.now());
                ordersMapper.updateById(order);

                if (refundRecord != null) {
                    refundRecord.setRefundStatus(1);
                    refundRecord.setThirdRefundNo(refundNo);
                    refundRecord.setUpdateTime(LocalDateTime.now());
                    refundRecordMapper.updateById(refundRecord);
                }

                writeStatusLog(order, Orders.Status.REFUNDING, Orders.Status.REFUNDED, userId, "USER", "取消订单退款成功");
                notificationMapper.insert(Notification.builder()
                    .receiverUserId(userId)
                    .receiverRole("USER")
                    .title("退款成功")
                    .content("订单（" + order.getOrderNo() + "）已退款成功，金额将原路退回。")
                    .bizType("REFUND")
                    .bizId(order.getOrderNo())
                    .readFlag(0)
                    .createTime(LocalDateTime.now())
                    .build());
                log.info("订单退款成功: orderId={}, orderNo={}", orderId, order.getOrderNo());
                return true;
                }

                if (refundRecord != null) {
                refundRecord.setRefundStatus(0);
                refundRecord.setThirdRefundNo(refundNo);
                refundRecord.setUpdateTime(LocalDateTime.now());
                refundRecordMapper.updateById(refundRecord);
                }
                notificationMapper.insert(Notification.builder()
                    .receiverUserId(userId)
                    .receiverRole("USER")
                    .title("退款处理中")
                    .content("订单（" + order.getOrderNo() + "）退款申请已提交，系统将自动原路退款。")
                    .bizType("REFUND")
                    .bizId(order.getOrderNo())
                    .readFlag(0)
                    .createTime(LocalDateTime.now())
                    .build());
                log.warn("订单退款调用失败，已标记为退款处理中: orderId={}, orderNo={}", orderId, order.getOrderNo());
                return true;
        }

        throw new RuntimeException("当前状态无法取消订单");
    }

    // ==================== 工具方法 ====================

    private String generateOrderNo() {
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMddHHmmss"));
        String uuid = UUID.randomUUID().toString().replace("-", "").substring(0, 6).toUpperCase();
        return "ORD" + timestamp + uuid;
    }

    private String buildAddressSnapshot(UserAddress addr) {
        StringBuilder sb = new StringBuilder();
        if (addr.getProvince() != null) sb.append(addr.getProvince());
        if (addr.getCity() != null) sb.append(addr.getCity());
        if (addr.getDistrict() != null) sb.append(addr.getDistrict());
        sb.append(addr.getDetailAddress());
        sb.append(" ").append(addr.getContactName()).append(" ").append(addr.getContactPhone());
        return sb.toString();
    }

    private void writeStatusLog(Orders order, Integer oldStatus, int newStatus, Long operatorId, String role, String remark) {
        OrderStatusLog statusLog = OrderStatusLog.builder()
                .orderId(order.getId())
                .orderNo(order.getOrderNo())
                .oldStatus(oldStatus != null ? oldStatus : -1)
                .newStatus(newStatus)
                .operatorUserId(operatorId)
                .operatorRole(role)
                .remark(remark)
                .createTime(LocalDateTime.now())
                .build();
        orderStatusLogMapper.insert(statusLog);
    }

    private OrderVO toVO(Orders order) {
        return OrderVO.builder()
                .id(order.getId())
                .orderNo(order.getOrderNo())
                .userId(order.getUserId())
                .nurseUserId(order.getNurseUserId())
                .serviceId(order.getServiceId())
                .serviceName(order.getServiceNameSnapshot())
                .totalAmount(order.getTotalAmount())
                .orderStatus(order.getOrderStatus())
                .payStatus(order.getPayStatus())
                .appointmentTime(order.getAppointmentTime())
                .addressSnapshot(order.getAddressSnapshot())
                .remark(order.getRemark())
                .arrivalTime(order.getArriveTime())
                .startTime(order.getStartTime())
                .finishTime(order.getFinishTime())
                .createTime(order.getCreateTime())
                .build();
    }
}
