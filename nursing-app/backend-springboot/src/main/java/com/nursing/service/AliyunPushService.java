package com.nursing.service;

import com.aliyuncs.CommonRequest;
import com.aliyuncs.CommonResponse;
import com.aliyuncs.DefaultAcsClient;
import com.aliyuncs.IAcsClient;
import com.aliyuncs.http.MethodType;
import com.aliyuncs.profile.DefaultProfile;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.nursing.config.CustomMetrics;
import com.nursing.mapper.SysConfigMapper;
import com.nursing.properties.AliyunProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 阿里云移动推送服务（默认关闭）
 *
 * 当前项目采用“降级优先”策略：
 * 1. app.push.enabled=false 时不发送真实推送，只记录日志；
 * 2. 即使开启开关，若配置不完整也自动降级；
 * 3. 任何推送异常都不影响主业务流程。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AliyunPushService {

    private final SysConfigMapper sysConfigMapper;
    private final AliyunProperties aliyunProperties;
    private final CustomMetrics customMetrics;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Value("${app.push.enabled:false}")
    private boolean pushEnabled;

    /**
     * 账号维度推送（ACCOUNT）
     */
    public boolean pushNoticeToAccount(Long accountId, String title, String body, Map<String, Object> extData) {
        if (accountId == null || !StringUtils.hasText(title) || !StringUtils.hasText(body)) {
            log.warn("推送参数不完整，跳过发送: accountId={}, title={}, body={}", accountId, title, body);
            customMetrics.recordPushSent(false);
            return false;
        }

        if (!pushEnabled) {
            log.info("阿里云推送开关关闭(app.push.enabled=false)，降级为仅站内通知: accountId={}, title={}", accountId, title);
            customMetrics.recordPushSent(false);
            return false;
        }

        String appKey = getPushConfig(
                aliyunProperties.getPush().getAppKey(),
                "aliyun_push_app_key"
        );
        String accessKeyId = getPushConfig(
                aliyunProperties.getPush().getAccessKeyId(),
                "aliyun_push_access_key_id",
                "aliyun_sms_access_key"
        );
        String accessKeySecret = getPushConfig(
                aliyunProperties.getPush().getAccessKeySecret(),
                "aliyun_push_access_key_secret",
                "aliyun_push_app_secret",
                "aliyun_sms_secret"
        );
        String regionId = StringUtils.hasText(aliyunProperties.getPush().getRegionId())
                ? aliyunProperties.getPush().getRegionId()
                : "cn-hangzhou";

        if (!isConfigured(appKey, accessKeyId, accessKeySecret)) {
            log.warn("阿里云推送配置不完整，降级为仅站内通知: accountId={}, title={}", accountId, title);
            customMetrics.recordPushSent(false);
            return false;
        }

        try {
            IAcsClient client = createClient(regionId, accessKeyId, accessKeySecret);
            CommonRequest request = new CommonRequest();
            request.setSysMethod(MethodType.POST);
            request.setSysDomain("cloudpush.aliyuncs.com");
            request.setSysVersion("2016-08-01");
            request.setSysAction("Push");

            request.putQueryParameter("AppKey", appKey);
            request.putQueryParameter("Target", "ACCOUNT");
            request.putQueryParameter("TargetValue", String.valueOf(accountId));
            request.putQueryParameter("DeviceType", "ALL");
            request.putQueryParameter("PushType", "NOTICE");
            request.putQueryParameter("Title", title);
            request.putQueryParameter("Body", body);
            request.putQueryParameter("StoreOffline", "true");
            request.putQueryParameter("ExpireTime", "72");

            String extJson = toJson(extData == null ? Collections.emptyMap() : extData);
            if (StringUtils.hasText(extJson)) {
                request.putQueryParameter("ExtParameters", extJson);
            }

            CommonResponse response = client.getCommonResponse(request);
            boolean success = response != null && response.getHttpStatus() == 200;
            customMetrics.recordPushSent(success);

            if (success) {
                log.info("阿里云推送发送成功: accountId={}, title={}", accountId, title);
                return true;
            }

            String bodyText = response == null ? "null" : response.getData();
            log.warn("阿里云推送发送失败: accountId={}, title={}, response={}", accountId, title, bodyText);
            return false;
        } catch (Exception e) {
            customMetrics.recordPushSent(false);
            log.error("阿里云推送发送异常: accountId={}, title={}", accountId, title, e);
            return false;
        }
    }

    /**
     * 订单派单给护士的推送
     */
    public boolean pushNewOrderToNurse(Long nurseUserId, Long orderId, String orderNo, String content) {
        Map<String, Object> ext = new LinkedHashMap<>();
        ext.put("type", "new_order");
        ext.put("orderId", orderId == null ? "" : String.valueOf(orderId));
        ext.put("orderNo", orderNo == null ? "" : orderNo);
        return pushNoticeToAccount(nurseUserId, "新订单待接单", content, ext);
    }

    /**
     * 订单状态更新给用户的推送
     */
    public boolean pushOrderStatusToUser(Long userId, Long orderId, String orderNo, String statusText) {
        Map<String, Object> ext = new LinkedHashMap<>();
        ext.put("type", "order_status");
        ext.put("orderId", orderId == null ? "" : String.valueOf(orderId));
        ext.put("orderNo", orderNo == null ? "" : orderNo);
        return pushNoticeToAccount(userId, "订单状态更新", statusText, ext);
    }

    private IAcsClient createClient(String regionId, String accessKeyId, String accessKeySecret) {
        DefaultProfile profile = DefaultProfile.getProfile(regionId, accessKeyId, accessKeySecret);
        return new DefaultAcsClient(profile);
    }

    private String getPushConfig(String fallback, String... keys) {
        for (String key : keys) {
            try {
                String value = sysConfigMapper.getValueByKey(key);
                if (StringUtils.hasText(value)) {
                    return value;
                }
            } catch (Exception ignored) {
            }
        }
        return StringUtils.hasText(fallback) ? fallback : "";
    }

    private boolean isConfigured(String... values) {
        for (String value : values) {
            if (!StringUtils.hasText(value)) {
                return false;
            }
        }
        return true;
    }

    private String toJson(Map<String, Object> extData) {
        try {
            return objectMapper.writeValueAsString(extData);
        } catch (JsonProcessingException e) {
            log.warn("推送扩展参数序列化失败，忽略ExtParameters", e);
            return "";
        }
    }
}
