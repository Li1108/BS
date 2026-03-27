package com.nursing.service;

import com.aliyun.dysmsapi20170525.Client;
import com.aliyun.dysmsapi20170525.models.SendSmsRequest;
import com.aliyun.dysmsapi20170525.models.SendSmsResponse;
import com.aliyun.teaopenapi.models.Config;
import com.nursing.entity.SmsCode;
import com.nursing.mapper.SmsCodeMapper;
import com.nursing.mapper.SysConfigMapper;
import com.nursing.properties.AliyunProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDateTime;
import java.util.Random;

/**
 * 认证服务
 * 负责验证码发送（写入 sms_code 表，无Redis）
 * 登录逻辑已移至 AuthController 直接处理
 * <p>
 * 短信发送策略：
 * 1. 优先从 sys_config 表读取阿里云短信配置
 * 2. 若 sys_config 未配置则读取 application.yml 中的配置
 * 3. 若阿里云短信未配置（accessKeyId 或 accessKeySecret 为空），自动使用默认验证码 123456
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AuthService {

    private final SmsCodeMapper smsCodeMapper;
    private final SysConfigMapper sysConfigMapper;
    private final AliyunProperties aliyunProperties;

    /** 默认验证码（阿里云短信未配置时使用） */
    private static final String DEFAULT_CODE = "123456";

    @Value("${app.sms.fixed-code-enabled:false}")
    private boolean fixedCodeEnabled;

    @Value("${app.sms.fixed-code:123456}")
    private String fixedCode;

    /**
     * 获取有效的短信配置值：优先从 sys_config 表读取，再兜底 properties
     */
    private String getSmsConfig(String fallback, String... dbKeys) {
        for (String dbKey : dbKeys) {
            try {
                String val = sysConfigMapper.getValueByKey(dbKey);
                if (StringUtils.hasText(val)) {
                    return val;
                }
            } catch (Exception ignored) {
            }
        }
        return StringUtils.hasText(fallback) ? fallback : "";
    }

    /**
     * 判断阿里云短信是否已完整配置
     */
    private boolean isAliyunSmsConfigured() {
        String keyId = getSmsConfig(
            aliyunProperties.getSms().getAccessKeyId(),
            "aliyun_sms_access_key_id",
            "aliyun_sms_access_key"
        );
        String keySecret = getSmsConfig(
            aliyunProperties.getSms().getAccessKeySecret(),
            "aliyun_sms_access_key_secret",
            "aliyun_sms_secret"
        );
        String signName = getSmsConfig(
            aliyunProperties.getSms().getSignName(),
            "aliyun_sms_sign_name"
        );
        String templateCode = getSmsConfig(
            aliyunProperties.getSms().getTemplateCode(),
            "aliyun_sms_template_code"
        );
        return StringUtils.hasText(keyId)
                && StringUtils.hasText(keySecret)
                && StringUtils.hasText(signName)
                && StringUtils.hasText(templateCode);
    }

    /**
     * 通过阿里云短信 SDK 发送验证码
     *
     * @param phone 手机号
     * @param code  验证码
     * @return 是否发送成功
     */
    private boolean sendAliyunSms(String phone, String code) {
        String keyId = getSmsConfig(
            aliyunProperties.getSms().getAccessKeyId(),
            "aliyun_sms_access_key_id",
            "aliyun_sms_access_key"
        );
        String keySecret = getSmsConfig(
            aliyunProperties.getSms().getAccessKeySecret(),
            "aliyun_sms_access_key_secret",
            "aliyun_sms_secret"
        );
        String signName = getSmsConfig(
            aliyunProperties.getSms().getSignName(),
            "aliyun_sms_sign_name"
        );
        String templateCode = getSmsConfig(
            aliyunProperties.getSms().getTemplateCode(),
            "aliyun_sms_template_code"
        );
        String endpoint = aliyunProperties.getSms().getEndpoint();

        try {
            Config config = new Config()
                    .setAccessKeyId(keyId)
                    .setAccessKeySecret(keySecret)
                    .setEndpoint(endpoint);
            Client client = new Client(config);

            SendSmsRequest request = new SendSmsRequest()
                    .setPhoneNumbers(phone)
                    .setSignName(signName)
                    .setTemplateCode(templateCode)
                    .setTemplateParam("{\"code\":\"" + code + "\"}");

            SendSmsResponse response = client.sendSms(request);
            String respCode = response.getBody().getCode();
            if ("OK".equalsIgnoreCase(respCode)) {
                log.info("阿里云短信发送成功: phone={}", phone);
                return true;
            } else {
                log.warn("阿里云短信发送失败: phone={}, code={}, message={}",
                        phone, respCode, response.getBody().getMessage());
                return false;
            }
        } catch (Exception e) {
            log.error("阿里云短信发送异常: phone={}", phone, e);
            return false;
        }
    }

    /**
     * 发送验证码
     * <p>
     * 策略：
     * - 若 fixedCodeEnabled=true，直接使用配置的固定验证码（测试/开发模式）
     * - 否则判断阿里云短信是否配置：
     *   - 已配置 → 生成随机验证码并通过阿里云 SMS 发送
     *   - 未配置 → 使用默认验证码 123456（开发/演示模式）
     * 验证码写入 sms_code 表（5分钟有效）
     */
    @Transactional
    public boolean sendVerificationCode(@NonNull String phone) {
        try {
            String code;

            if (fixedCodeEnabled) {
                // 明确开启固定验证码模式（纯测试用）
                code = fixedCode;
                log.info("固定验证码模式: phone={}, code={}", phone, code);
            } else if (isAliyunSmsConfigured()) {
                // 阿里云短信已配置，生成随机验证码并发送
                code = String.format("%06d", new Random().nextInt(999999));
                boolean sent = sendAliyunSms(phone, code);
                if (!sent) {
                    // 发送失败时回退到默认验证码，保证登录流程可用
                    log.warn("阿里云短信发送失败，回退使用默认验证码: phone={}", phone);
                    code = DEFAULT_CODE;
                }
            } else {
                // 阿里云短信未配置，使用默认验证码
                code = DEFAULT_CODE;
                log.info("阿里云短信未配置，使用默认验证码: phone={}, code={}", phone, code);
            }

            // 写入 sms_code 表（5分钟有效）
            SmsCode smsCode = SmsCode.builder()
                    .phone(phone)
                    .code(code)
                    .expireTime(LocalDateTime.now().plusMinutes(5))
                    .usedFlag(0)
                    .createTime(LocalDateTime.now())
                    .build();
            smsCodeMapper.insert(smsCode);

            return true;
        } catch (Exception e) {
            log.error("发送验证码失败: phone={}", phone, e);
            return false;
        }
    }
}
