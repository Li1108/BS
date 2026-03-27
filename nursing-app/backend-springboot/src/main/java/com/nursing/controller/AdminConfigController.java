package com.nursing.controller;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.nursing.common.Result;
import com.nursing.entity.OperationLog;
import com.nursing.entity.SysConfig;
import com.nursing.mapper.OperationLogMapper;
import com.nursing.mapper.SysConfigMapper;
import com.nursing.properties.AliyunProperties;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 管理员 - 系统配置管理
 */
@Slf4j
@RestController
@RequestMapping("/admin/config")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN_SUPER')")
public class AdminConfigController {

    private final SysConfigMapper sysConfigMapper;
    private final OperationLogMapper operationLogMapper;
    private final AliyunProperties aliyunProperties;

    @Value("${app.sms.fixed-code-enabled:false}")
    private boolean smsFixedCodeEnabled;

    @Value("${app.push.enabled:false}")
    private boolean pushEnabled;

    /**
     * 配置列表
     */
    @GetMapping("/list")
    public Result<?> list() {
        List<SysConfig> configs = sysConfigMapper.selectList(
                new LambdaQueryWrapper<SysConfig>().orderByAsc(SysConfig::getId));
        return Result.success(configs);
    }

        /**
         * 阿里云短信/推送健康检查（仅管理员）
         * 用于确认：是否“已完整配置但未启用”
         */
        @GetMapping("/aliyun-health")
        public Result<?> aliyunHealth() {
        String smsKeyId = resolveConfig(
            aliyunProperties.getSms().getAccessKeyId(),
            "aliyun_sms_access_key_id",
            "aliyun_sms_access_key"
        );
        String smsKeySecret = resolveConfig(
            aliyunProperties.getSms().getAccessKeySecret(),
            "aliyun_sms_access_key_secret",
            "aliyun_sms_secret"
        );
        String smsSignName = resolveConfig(
            aliyunProperties.getSms().getSignName(),
            "aliyun_sms_sign_name"
        );
        String smsTemplateCode = resolveConfig(
            aliyunProperties.getSms().getTemplateCode(),
            "aliyun_sms_template_code"
        );

        boolean smsConfigured = allHasText(smsKeyId, smsKeySecret, smsSignName, smsTemplateCode);
        boolean smsRealSendEnabled = smsConfigured && !smsFixedCodeEnabled;
        boolean smsConfiguredButNotEnabled = smsConfigured && smsFixedCodeEnabled;

        String pushAppKey = resolveConfig(
            aliyunProperties.getPush().getAppKey(),
            "aliyun_push_app_key"
        );
        String pushKeyId = resolveConfig(
            aliyunProperties.getPush().getAccessKeyId(),
            "aliyun_push_access_key_id",
            "aliyun_sms_access_key"
        );
        String pushKeySecret = resolveConfig(
            aliyunProperties.getPush().getAccessKeySecret(),
            "aliyun_push_access_key_secret",
            "aliyun_push_app_secret",
            "aliyun_sms_secret"
        );

        boolean pushConfigured = allHasText(pushAppKey, pushKeyId, pushKeySecret);
        boolean pushRealSendEnabled = pushConfigured && pushEnabled;
        boolean pushConfiguredButNotEnabled = pushConfigured && !pushEnabled;

        Map<String, Object> sms = new LinkedHashMap<>();
        sms.put("configured", smsConfigured);
        sms.put("fixedCodeEnabled", smsFixedCodeEnabled);
        sms.put("realSendEnabled", smsRealSendEnabled);
        sms.put("configuredButNotEnabled", smsConfiguredButNotEnabled);
        sms.put("missing", Map.of(
            "accessKeyId", !StringUtils.hasText(smsKeyId),
            "accessKeySecret", !StringUtils.hasText(smsKeySecret),
            "signName", !StringUtils.hasText(smsSignName),
            "templateCode", !StringUtils.hasText(smsTemplateCode)
        ));

        Map<String, Object> push = new LinkedHashMap<>();
        push.put("configured", pushConfigured);
        push.put("pushEnabled", pushEnabled);
        push.put("realSendEnabled", pushRealSendEnabled);
        push.put("configuredButNotEnabled", pushConfiguredButNotEnabled);
        push.put("missing", Map.of(
            "appKey", !StringUtils.hasText(pushAppKey),
            "accessKeyId", !StringUtils.hasText(pushKeyId),
            "accessKeySecret", !StringUtils.hasText(pushKeySecret)
        ));

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("summary", Map.of(
            "smsConfiguredButNotEnabled", smsConfiguredButNotEnabled,
            "pushConfiguredButNotEnabled", pushConfiguredButNotEnabled
        ));
        data.put("sms", sms);
        data.put("push", push);

        return Result.success(data);
        }

        private String resolveConfig(String fallback, String... keys) {
        for (String key : keys) {
            try {
            String dbValue = sysConfigMapper.getValueByKey(key);
            if (StringUtils.hasText(dbValue)) {
                return dbValue;
            }
            } catch (Exception ignored) {
            }
        }
        return StringUtils.hasText(fallback) ? fallback : "";
        }

        private boolean allHasText(String... values) {
        for (String value : values) {
            if (!StringUtils.hasText(value)) {
            return false;
            }
        }
        return true;
        }

    /**
     * 配置详情
     */
    @GetMapping("/detail/{configKey}")
    public Result<?> detail(@PathVariable String configKey) {
        LambdaQueryWrapper<SysConfig> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(SysConfig::getConfigKey, configKey);
        SysConfig config = sysConfigMapper.selectOne(wrapper);
        if (config == null) {
            return Result.notFound("配置项不存在");
        }
        return Result.success(config);
    }

    /**
     * 添加配置
     */
    @PostMapping("/add")
    public Result<?> add(@RequestBody Map<String, String> body, HttpServletRequest request) {
        String configKey = body.get("configKey");
        String configValue = body.get("configValue");
        String remark = body.get("remark");

        // 检查是否已存在
        LambdaQueryWrapper<SysConfig> checkWrapper = new LambdaQueryWrapper<>();
        checkWrapper.eq(SysConfig::getConfigKey, configKey);
        if (sysConfigMapper.selectCount(checkWrapper) > 0) {
            return Result.badRequest("配置键已存在");
        }

        SysConfig config = SysConfig.builder()
                .configKey(configKey)
                .configValue(configValue)
                .remark(remark)
                .createTime(LocalDateTime.now())
                .updateTime(LocalDateTime.now())
                .build();
        sysConfigMapper.insert(config);

        // 写操作日志
        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("ADD_CONFIG")
                .actionDesc("添加配置，configKey=" + configKey)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("configKey=" + configKey + ", configValue=" + configValue)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]添加配置[{}]", adminUserId, configKey);
        return Result.success(config);
    }

    /**
     * 更新配置（不存在时自动创建，即 upsert）
     */
    @PostMapping("/update")
    public Result<?> update(@RequestBody Map<String, String> body, HttpServletRequest request) {
        String configKey = body.get("configKey");
        String configValue = body.get("configValue");
        String remark = body.get("remark");

        if (configKey == null || configKey.isBlank()) {
            return Result.badRequest("configKey 不能为空");
        }

        LambdaQueryWrapper<SysConfig> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(SysConfig::getConfigKey, configKey);
        SysConfig config = sysConfigMapper.selectOne(wrapper);

        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();

        if (config == null) {
            // 配置不存在，自动创建
            config = SysConfig.builder()
                    .configKey(configKey)
                    .configValue(configValue)
                    .remark(remark != null ? remark : "")
                    .createTime(LocalDateTime.now())
                    .updateTime(LocalDateTime.now())
                    .build();
            sysConfigMapper.insert(config);
            log.info("管理员[{}]新增配置[{}]", adminUserId, configKey);
        } else {
            // 配置已存在，更新
            config.setConfigValue(configValue);
            if (remark != null) {
                config.setRemark(remark);
            }
            config.setUpdateTime(LocalDateTime.now());
            sysConfigMapper.updateById(config);
            log.info("管理员[{}]更新配置[{}]", adminUserId, configKey);
        }

        // 写操作日志
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("UPDATE_CONFIG")
                .actionDesc("保存配置，configKey=" + configKey)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("configKey=" + configKey + ", configValue=" + configValue)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        return Result.success(config);
    }

    /**
     * 批量保存配置（upsert，前端批量提交时使用）
     */
    @PostMapping("/batch-update")
    public Result<?> batchUpdate(@RequestBody List<Map<String, String>> items, HttpServletRequest request) {
        if (items == null || items.isEmpty()) {
            return Result.badRequest("配置项列表不能为空");
        }
        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        int saved = 0;
        for (Map<String, String> body : items) {
            String configKey = body.get("configKey");
            String configValue = body.get("configValue");
            String remark = body.get("remark");
            if (configKey == null || configKey.isBlank()) continue;

            LambdaQueryWrapper<SysConfig> wrapper = new LambdaQueryWrapper<>();
            wrapper.eq(SysConfig::getConfigKey, configKey);
            SysConfig config = sysConfigMapper.selectOne(wrapper);
            if (config == null) {
                config = SysConfig.builder()
                        .configKey(configKey)
                        .configValue(configValue)
                        .remark(remark != null ? remark : "")
                        .createTime(LocalDateTime.now())
                        .updateTime(LocalDateTime.now())
                        .build();
                sysConfigMapper.insert(config);
            } else {
                config.setConfigValue(configValue);
                if (remark != null) config.setRemark(remark);
                config.setUpdateTime(LocalDateTime.now());
                sysConfigMapper.updateById(config);
            }
            saved++;
        }

        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("BATCH_UPDATE_CONFIG")
                .actionDesc("批量保存配置，共" + saved + "项")
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("count=" + saved)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]批量保存配置，共{}项", adminUserId, saved);
        return Result.success(true);
    }

    /**
     * 删除配置
     */
    @DeleteMapping("/delete/{configKey}")
    public Result<?> delete(@PathVariable String configKey, HttpServletRequest request) {
        LambdaQueryWrapper<SysConfig> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(SysConfig::getConfigKey, configKey);
        SysConfig config = sysConfigMapper.selectOne(wrapper);
        if (config == null) {
            return Result.notFound("配置项不存在");
        }

        sysConfigMapper.deleteById(config.getId());

        // 写操作日志
        Long adminUserId = (Long) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        operationLogMapper.insert(OperationLog.builder()
                .adminUserId(adminUserId)
                .actionType("DELETE_CONFIG")
                .actionDesc("删除配置，configKey=" + configKey)
                .requestPath(request.getRequestURI())
                .requestMethod(request.getMethod())
                .requestParams("configKey=" + configKey)
                .ip(request.getRemoteAddr())
                .createTime(LocalDateTime.now())
                .build());

        log.info("管理员[{}]删除配置[{}]", adminUserId, configKey);
        return Result.success("配置已删除");
    }
}
