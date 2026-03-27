package com.nursing.dto.order;

import lombok.Data;
import org.springframework.web.multipart.MultipartFile;

/**
 * 更新订单状态请求（护士端）
 */
@Data
public class UpdateOrderStatusRequest {

    /**
     * 操作类型：arrival(到达), start(开始服务), finish(完成服务)
     */
    private String action;

    /**
     * 现场照片（可选）
     */
    private MultipartFile photo;
}
