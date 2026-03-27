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
import org.junit.jupiter.api.BeforeEach;
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
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PaymentControllerResilienceTest {

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

    @BeforeEach
    void setupAuth() {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(2001L, null)
        );
    }

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void payOrderShouldFailFastWhenAlipayServiceThrows() {
        Orders order = Orders.builder()
                .id(1L)
                .orderNo("PAY_FAULT_001")
                .userId(2001L)
                .orderStatus(Orders.Status.PENDING_PAYMENT)
                .payStatus(Orders.PayStatusEnum.UNPAID)
                .totalAmount(new BigDecimal("88.00"))
                .build();

        when(ordersMapper.selectOne(any())).thenReturn(order);
        when(paymentRecordMapper.selectOne(any())).thenReturn(null);
        when(alipayService.createAppPayOrder(any(), any(), any(), any()))
                .thenThrow(new RuntimeException("injected-alipay-timeout"));

        Map<String, Object> body = new HashMap<>();
        body.put("orderNo", "PAY_FAULT_001");
        body.put("payMethod", 1);

        assertThrows(RuntimeException.class, () -> paymentController.payOrder(body));
        verify(paymentRecordMapper, never()).insert(any(PaymentRecord.class));
        verify(ordersMapper, never()).updateById(any(Orders.class));
    }

    @Test
    void payOrderShouldSurviveBurstRequestsInLoop() {
        Orders order = Orders.builder()
                .id(2L)
                .orderNo("PAY_STRESS_001")
                .userId(2001L)
                .orderStatus(Orders.Status.PENDING_PAYMENT)
                .payStatus(Orders.PayStatusEnum.UNPAID)
                .totalAmount(new BigDecimal("99.00"))
                .build();

        when(ordersMapper.selectOne(any())).thenReturn(order);
        when(paymentRecordMapper.selectOne(any())).thenReturn(null);
        when(alipayService.createAppPayOrder(any(), any(), any(), any())).thenReturn("mock-pay-info");

        for (int i = 0; i < 120; i++) {
            Map<String, Object> body = new HashMap<>();
            body.put("orderNo", "PAY_STRESS_001");
            body.put("payMethod", 1);

            Result<?> result = paymentController.payOrder(body);
            assertEquals(0, result.getCode());
        }

        verify(paymentRecordMapper, times(120)).insert(any(PaymentRecord.class));
    }
}
