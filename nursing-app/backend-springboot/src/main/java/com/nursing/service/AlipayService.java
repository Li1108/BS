package com.nursing.service;

import com.alipay.api.AlipayApiException;
import com.alipay.api.AlipayClient;
import com.alipay.api.AlipayConfig;
import com.alipay.api.DefaultAlipayClient;
import com.alipay.api.domain.AlipayTradeAppPayModel;
import com.alipay.api.domain.AlipayTradeRefundModel;
import com.alipay.api.domain.AlipayTradeQueryModel;
import com.alipay.api.internal.util.AlipaySignature;
import com.alipay.api.request.AlipayTradeAppPayRequest;
import com.alipay.api.request.AlipayTradeQueryRequest;
import com.alipay.api.request.AlipayTradeRefundRequest;
import com.alipay.api.response.AlipayTradeAppPayResponse;
import com.alipay.api.response.AlipayTradeQueryResponse;
import com.alipay.api.response.AlipayTradeRefundResponse;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 支付宝支付服务（沙箱环境）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AlipayService {

    @Value("${alipay.gateway-url:https://openapi-sandbox.dl.alipaydev.com/gateway.do}")
    private String gatewayUrl;

    @Value("${alipay.app-id:}")
    private String appId;

    @Value("${alipay.private-key:}")
    private String privateKey;

    @Value("${alipay.alipay-public-key:}")
    private String alipayPublicKey;

    @Value("${alipay.notify-url:}")
    private String notifyUrl;

    @Value("${alipay.return-url:}")
    private String returnUrl;

    @Value("${alipay.charset:utf-8}")
    private String charset;

    @Value("${alipay.sign-type:RSA2}")
    private String signType;

    @Value("${alipay.format:json}")
    private String format;

    private AlipayClient alipayClient;

    @PostConstruct
    public void init() {
        try {
            if (appId != null && !appId.isEmpty() && privateKey != null && !privateKey.isEmpty()) {
                AlipayConfig alipayConfig = new AlipayConfig();
                alipayConfig.setServerUrl(gatewayUrl);
                alipayConfig.setAppId(appId);
                alipayConfig.setPrivateKey(privateKey);
                alipayConfig.setFormat(format);
                alipayConfig.setCharset(charset);
                alipayConfig.setAlipayPublicKey(alipayPublicKey);
                alipayConfig.setSignType(signType);
                
                alipayClient = new DefaultAlipayClient(alipayConfig);
                log.info("支付宝客户端初始化成功");
            } else {
                log.warn("支付宝配置不完整，支付功能将不可用");
            }
        } catch (Exception e) {
            log.error("支付宝客户端初始化失败", e);
        }
    }

    /**
     * 创建App支付订单
     *
     * @param orderNo     订单号
     * @param amount      金额
     * @param subject     订单标题
     * @param description 订单描述
     * @return 支付表单字符串（用于App调起支付）
     */
    public String createAppPayOrder(String orderNo, BigDecimal amount, String subject, String description) {
        if (alipayClient == null) {
            log.warn("支付宝客户端未初始化，返回模拟支付表单");
            return "MOCK_PAY_FORM_" + orderNo;
        }

        try {
            AlipayTradeAppPayRequest request = new AlipayTradeAppPayRequest();
            if (StringUtils.hasText(notifyUrl)
                    && notifyUrl.startsWith("http")
                    && !notifyUrl.contains("localhost")
                    && !notifyUrl.contains("127.0.0.1")) {
                request.setNotifyUrl(notifyUrl);
            }
            if (StringUtils.hasText(returnUrl)
                    && returnUrl.startsWith("http")
                    && !returnUrl.contains("localhost")
                    && !returnUrl.contains("127.0.0.1")) {
                request.setReturnUrl(returnUrl);
            }

            AlipayTradeAppPayModel model = new AlipayTradeAppPayModel();
            model.setOutTradeNo(orderNo);
            model.setTotalAmount(amount.setScale(2).toString());
            model.setSubject(subject);
            model.setBody(description);
            model.setProductCode("QUICK_MSECURITY_PAY");
            model.setTimeoutExpress("30m");

            request.setBizModel(model);

            AlipayTradeAppPayResponse response = alipayClient.sdkExecute(request);
            if (response.isSuccess()) {
                final String orderString = response.getBody();
                if (!StringUtils.hasText(orderString) || !orderString.contains("app_id=")) {
                    throw new RuntimeException("生成支付参数失败，请检查支付宝配置");
                }
                log.info("创建支付订单成功: orderNo={}", orderNo);
                return orderString;
            } else {
                log.error("创建支付订单失败: orderNo={}, code={}, msg={}",
                        orderNo, response.getCode(), response.getMsg());
                throw new RuntimeException("创建支付订单失败: " + response.getMsg());
            }
        } catch (AlipayApiException e) {
            log.error("支付宝API调用异常: orderNo={}", orderNo, e);
            throw new RuntimeException("支付创建失败，请稍后重试");
        }
    }

    /**
     * 查询订单支付状态
     *
     * @param orderNo 订单号
     * @return 交易状态：WAIT_BUYER_PAY-等待支付, TRADE_SUCCESS-支付成功, TRADE_CLOSED-交易关闭
     */
    public String queryPayStatus(String orderNo) {
        if (alipayClient == null) {
            log.warn("支付宝客户端未初始化，返回模拟状态");
            return "TRADE_SUCCESS";
        }

        try {
            AlipayTradeQueryRequest request = new AlipayTradeQueryRequest();
            AlipayTradeQueryModel model = new AlipayTradeQueryModel();
            model.setOutTradeNo(orderNo);
            request.setBizModel(model);

            AlipayTradeQueryResponse response = alipayClient.execute(request);
            if (response.isSuccess()) {
                return response.getTradeStatus();
            } else {
                log.warn("查询支付状态失败: orderNo={}, code={}, msg={}",
                        orderNo, response.getCode(), response.getMsg());
                return null;
            }
        } catch (AlipayApiException e) {
            log.error("查询支付状态异常: orderNo={}", orderNo, e);
            return null;
        }
    }

    /**
     * 申请退款
     *
     * @param orderNo      订单号
     * @param refundNo     退款单号
     * @param refundAmount 退款金额
     * @param refundReason 退款原因
     * @return 是否成功
     */
    public boolean refund(String orderNo, String refundNo, BigDecimal refundAmount, String refundReason) {
        if (alipayClient == null) {
            log.warn("支付宝客户端未初始化，模拟退款成功");
            return true;
        }

        try {
            AlipayTradeRefundRequest request = new AlipayTradeRefundRequest();
            AlipayTradeRefundModel model = new AlipayTradeRefundModel();
            model.setOutTradeNo(orderNo);
            model.setOutRequestNo(refundNo);
            model.setRefundAmount(refundAmount.setScale(2).toString());
            model.setRefundReason(refundReason);
            request.setBizModel(model);

            AlipayTradeRefundResponse response = alipayClient.execute(request);
            if (response.isSuccess()) {
                log.info("退款成功: orderNo={}, refundNo={}, amount={}",
                        orderNo, refundNo, refundAmount);
                return true;
            } else {
                log.error("退款失败: orderNo={}, code={}, msg={}",
                        orderNo, response.getCode(), response.getMsg());
                return false;
            }
        } catch (AlipayApiException e) {
            log.error("退款异常: orderNo={}", orderNo, e);
            return false;
        }
    }

    /**
     * 验证支付宝异步通知签名
     *
     * @param params 回调参数
     * @return 是否验签成功
     */
    public boolean verifyNotifySign(Map<String, String> params) {
        try {
            return AlipaySignature.rsaCheckV1(params, alipayPublicKey, charset, signType);
        } catch (AlipayApiException e) {
            log.error("验签异常", e);
            return false;
        }
    }

    /**
     * 判断是否已配置支付
     */
    public boolean isConfigured() {
        return alipayClient != null;
    }

    /**
     * 支付配置体检信息（调试用，不返回敏感明文）
     */
    public Map<String, Object> getConfigCheckInfo() {
        Map<String, Object> data = new LinkedHashMap<>();

        String trimmedAppId = appId == null ? "" : appId.trim();
        String maskedAppId;
        if (!StringUtils.hasText(trimmedAppId)) {
            maskedAppId = "";
        } else if (trimmedAppId.length() <= 6) {
            maskedAppId = "***";
        } else {
            maskedAppId = trimmedAppId.substring(0, 3)
                    + "***"
                    + trimmedAppId.substring(trimmedAppId.length() - 3);
        }

        boolean privateKeyPresent = StringUtils.hasText(privateKey);
        boolean publicKeyPresent = StringUtils.hasText(alipayPublicKey);
        boolean appIdPresent = StringUtils.hasText(trimmedAppId);
        boolean notifyUrlValid = StringUtils.hasText(notifyUrl) && notifyUrl.startsWith("http");
        boolean returnUrlValid = StringUtils.hasText(returnUrl) && returnUrl.startsWith("http");
        boolean sandboxGateway = StringUtils.hasText(gatewayUrl)
                && gatewayUrl.contains("openapi-sandbox.dl.alipaydev.com");

        data.put("configured", isConfigured());
        data.put("sandboxMode", sandboxGateway);
        data.put("gatewayUrl", gatewayUrl);
        data.put("appId", maskedAppId);
        data.put("appIdPresent", appIdPresent);
        data.put("privateKeyPresent", privateKeyPresent);
        data.put("alipayPublicKeyPresent", publicKeyPresent);
        data.put("notifyUrl", notifyUrl);
        data.put("notifyUrlValid", notifyUrlValid);
        data.put("returnUrl", returnUrl);
        data.put("returnUrlValid", returnUrlValid);
        data.put("signType", signType);
        data.put("charset", charset);

        boolean configComplete = appIdPresent && privateKeyPresent && publicKeyPresent;
        data.put("configComplete", configComplete);
        data.put("message", configComplete
                ? "支付宝基础配置完整"
                : "支付宝基础配置不完整，请检查 appId/私钥/支付宝公钥");

        return data;
    }
}
