package com.nursing.task;

import com.nursing.entity.Notification;
import com.nursing.entity.Orders;
import com.nursing.entity.RefundRecord;
import com.nursing.mapper.*;
import com.nursing.service.EvaluationService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Collections;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class OrderScheduledTaskTest {

    @Mock
    private OrdersMapper ordersMapper;
    @Mock
    private NurseProfileMapper nurseProfileMapper;
    @Mock
    private NurseLocationMapper nurseLocationMapper;
    @Mock
    private OrderAssignLogMapper orderAssignLogMapper;
    @Mock
    private RefundRecordMapper refundRecordMapper;
    @Mock
    private NotificationMapper notificationMapper;
    @Mock
    private EvaluationService evaluationService;

    @InjectMocks
    private OrderScheduledTask orderScheduledTask;

    @Test
    void dispatchTaskShouldSkipWhenNoPendingOrder() {
        when(ordersMapper.selectList(any())).thenReturn(Collections.emptyList());
        orderScheduledTask.dispatchOrders();
        verify(ordersMapper).selectList(any());
    }

    @Test
    void dispatchTaskShouldSkipOrderWhenCoordinatesMissing() {
        Orders pendingOrder = Orders.builder()
                .id(1L)
                .orderNo("DISPATCH_TEST_001")
                .userId(3001L)
                .totalAmount(new BigDecimal("128.00"))
                .orderStatus(Orders.Status.PENDING_ACCEPT)
                .assignRetryCount(9)
                .assignVersion(0)
                .build();

        when(ordersMapper.selectList(any())).thenReturn(List.of(pendingOrder));

        orderScheduledTask.dispatchOrders();

        verify(orderAssignLogMapper, never()).insert(any());
        verify(refundRecordMapper, never()).insert(any(RefundRecord.class));
        verify(notificationMapper, never()).insert(any(Notification.class));
    }
}
