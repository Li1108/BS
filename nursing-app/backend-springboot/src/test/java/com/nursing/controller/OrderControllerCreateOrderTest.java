package com.nursing.controller;

import com.nursing.common.Result;
import com.nursing.dto.order.CreateOrderRequest;
import com.nursing.dto.order.OrderVO;
import com.nursing.service.OrderService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OrderControllerCreateOrderTest {

    @Mock
    private OrderService orderService;

    @InjectMocks
    private OrderController orderController;

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void createOrderShouldReturnSuccess() {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(1001L, null)
        );

        CreateOrderRequest request = new CreateOrderRequest();
        request.setServiceId(1L);
        request.setAddressId(1L);
        request.setAppointmentTime(LocalDateTime.now().plusDays(1));
        request.setRemark("测试下单");

        OrderVO orderVO = OrderVO.builder()
                .id(10L)
                .orderNo("TEST_ORDER_001")
                .userId(1001L)
                .orderStatus(0)
                .build();

        when(orderService.createOrder(1001L, request)).thenReturn(orderVO);

        Result<OrderVO> result = orderController.createOrder(request);

        assertEquals(0, result.getCode());
        assertNotNull(result.getData());
        assertEquals("TEST_ORDER_001", result.getData().getOrderNo());
    }
}
