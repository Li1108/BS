package com.nursing.dto.push;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serial;
import java.io.Serializable;
import java.util.List;
import java.util.Map;

/**
 * 推送消息DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PushMessageDTO implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    /**
     * 推送类型
     */
    private PushType pushType;

    /**
     * 目标用户ID列表
     */
    private List<Long> targetUserIds;

    /**
     * 推送标题
     */
    private String title;

    /**
     * 推送内容
     */
    private String content;

    /**
     * 扩展参数（如订单ID等）
     */
    private Map<String, String> extras;

    /**
     * 推送类型枚举
     */
    public enum PushType {
        /** 新订单通知 */
        NEW_ORDER,
        /** 订单状态更新 */
        ORDER_STATUS,
        /** 审核结果通知 */
        AUDIT_RESULT,
        /** 系统消息 */
        SYSTEM
    }
}
