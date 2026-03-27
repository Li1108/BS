package com.nursing.controller;

import com.nursing.common.Result;
import com.nursing.entity.NurseProfile;
import com.nursing.entity.Orders;
import com.nursing.mapper.NurseProfileMapper;
import com.nursing.mapper.NurseWalletMapper;
import com.nursing.mapper.OrderStatusLogMapper;
import com.nursing.mapper.OrdersMapper;
import com.nursing.mapper.WalletLogMapper;
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
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class NurseOrderControllerTest {

    @Mock
    private OrdersMapper ordersMapper;
    @Mock
    private NurseProfileMapper nurseProfileMapper;
    @Mock
    private NurseWalletMapper nurseWalletMapper;
    @Mock
    private WalletLogMapper walletLogMapper;
    @Mock
    private OrderStatusLogMapper orderStatusLogMapper;

    @InjectMocks
    private NurseOrderController nurseOrderController;

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void nurseAcceptOrderFlowShouldSucceed() {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(4001L, null)
        );

        Orders order = Orders.builder()
                .id(11L)
                .orderNo("NURSE_TEST_001")
                .nurseUserId(4001L)
                .orderStatus(Orders.Status.DISPATCHED)
                .build();
        NurseProfile nurseProfile = NurseProfile.builder()
            .userId(4001L)
            .auditStatus(NurseProfile.AuditStatus.APPROVED)
            .acceptEnabled(1)
            .build();

        when(nurseProfileMapper.selectOne(any())).thenReturn(nurseProfile);
        when(ordersMapper.selectOne(any())).thenReturn(order);

        Result<Void> result = nurseOrderController.accept("NURSE_TEST_001");

        assertEquals(0, result.getCode());
        assertEquals(Orders.Status.ACCEPTED, order.getOrderStatus());
        verify(ordersMapper).updateById(order);
        verify(orderStatusLogMapper).insert(any());
    }

    @Test
    void nurseRejectShouldFailWhenTimeoutExceeded() {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(4001L, null)
        );

        Orders order = Orders.builder()
                .id(12L)
                .orderNo("NURSE_TEST_002")
                .nurseUserId(4001L)
                .orderStatus(Orders.Status.DISPATCHED)
                .lastAssignTime(LocalDateTime.now().minusMinutes(5))
                .build();
        when(ordersMapper.selectOne(any())).thenReturn(order);

        Result<Void> result = nurseOrderController.reject("NURSE_TEST_002");

        assertEquals(400, result.getCode());
        assertTrue(result.getMessage().contains("超时"));
        verify(nurseProfileMapper, never()).selectOne(any());
    }
}
