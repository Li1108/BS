package com.nursing.controller;

import com.nursing.common.Result;
import com.nursing.entity.Orders;
import com.nursing.entity.PaymentRecord;
import com.nursing.mapper.NotificationMapper;
import com.nursing.mapper.OrderStatusLogMapper;
import com.nursing.mapper.OrdersMapper;
import com.nursing.mapper.PaymentRecordMapper;
import com.nursing.service.AlipayService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PaymentControllerTest {

    @Mock
    private OrdersMapper ordersMapper;
    @Mock
    private PaymentRecordMapper paymentRecordMapper;
    @Mock
    private OrderStatusLogMapper orderStatusLogMapper;
    @Mock
    private NotificationMapper notificationMapper;
    @Mock
    private AlipayService alipayService;

    @InjectMocks
    private PaymentController paymentController;

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void payOrderShouldUpdateOrderAndCreatePaymentRecord() {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(2001L, null)
        );

        Orders order = Orders.builder()
                .id(1L)
                .orderNo("PAY_TEST_001")
                .userId(2001L)
                .orderStatus(Orders.Status.PENDING_PAYMENT)
                .payStatus(Orders.PayStatusEnum.UNPAID)
                .totalAmount(new BigDecimal("88.00"))
                .build();

        when(ordersMapper.selectOne(any())).thenReturn(order);
        when(paymentRecordMapper.selectOne(any())).thenReturn(null);
        when(alipayService.createAppPayOrder(any(), any(), any(), any())).thenReturn("mock-pay-info");

        Map<String, Object> body = new HashMap<>();
        body.put("orderNo", "PAY_TEST_001");
        body.put("payMethod", 1);

        Result<?> result = paymentController.payOrder(body);

        assertEquals(0, result.getCode());
        verify(paymentRecordMapper).insert(any(PaymentRecord.class));
        verify(ordersMapper, never()).updateById(order);
    }

    @Test
    void payOrderShouldBeIdempotentWhenAlreadyPaid() {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(2001L, null)
        );

        Orders order = Orders.builder()
                .id(1L)
                .orderNo("PAY_TEST_002")
                .userId(2001L)
                .orderStatus(Orders.Status.PENDING_PAYMENT)
                .totalAmount(new BigDecimal("66.00"))
                .build();

        when(ordersMapper.selectOne(any())).thenReturn(order);
        when(paymentRecordMapper.selectOne(any())).thenReturn(PaymentRecord.builder().id(99L).build());

        Map<String, Object> body = Map.of("orderNo", "PAY_TEST_002", "payMethod", 1);
        Result<?> result = paymentController.payOrder(body);

        assertEquals(400, result.getCode());
        assertTrue(result.getMessage().contains("已支付"));
    }
}
