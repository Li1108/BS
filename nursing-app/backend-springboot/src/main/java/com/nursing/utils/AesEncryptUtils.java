package com.nursing.utils;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * AES加密工具类
 * 用于加密敏感数据（身份证号、手机号等）
 * 使用AES-256-GCM模式，提供认证加密
 */
@Slf4j
@Component
public class AesEncryptUtils {

    /**
     * AES密钥（32字节=256位）
     */
    @Value("${security.aes.secret-key:NursingServiceAES256SecretKey32B}")
    private String secretKey;

    private static final String ALGORITHM = "AES";
    private static final String TRANSFORMATION = "AES/GCM/NoPadding";
    private static final int GCM_TAG_LENGTH = 128;
    private static final int GCM_IV_LENGTH = 12;

    /**
     * 加密字符串
     *
     * @param plainText 明文
     * @return Base64编码的密文（包含IV）
     */
    public String encrypt(String plainText) {
        if (plainText == null || plainText.isEmpty()) {
            return plainText;
        }
        
        try {
            // 生成随机IV
            byte[] iv = new byte[GCM_IV_LENGTH];
            SecureRandom random = new SecureRandom();
            random.nextBytes(iv);
            
            // 创建密钥
            SecretKeySpec keySpec = new SecretKeySpec(
                    padKey(secretKey).getBytes(StandardCharsets.UTF_8), ALGORITHM);
            
            // 初始化加密器
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            GCMParameterSpec gcmSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
            cipher.init(Cipher.ENCRYPT_MODE, keySpec, gcmSpec);
            
            // 加密
            byte[] encrypted = cipher.doFinal(plainText.getBytes(StandardCharsets.UTF_8));
            
            // 组合IV和密文
            byte[] combined = new byte[iv.length + encrypted.length];
            System.arraycopy(iv, 0, combined, 0, iv.length);
            System.arraycopy(encrypted, 0, combined, iv.length, encrypted.length);
            
            return Base64.getEncoder().encodeToString(combined);
        } catch (Exception e) {
            log.error("AES加密失败: {}", e.getMessage());
            throw new RuntimeException("加密失败", e);
        }
    }

    /**
     * 解密字符串
     *
     * @param encryptedText Base64编码的密文
     * @return 明文
     */
    public String decrypt(String encryptedText) {
        if (encryptedText == null || encryptedText.isEmpty()) {
            return encryptedText;
        }
        
        try {
            // 解码Base64
            byte[] combined = Base64.getDecoder().decode(encryptedText);
            
            // 提取IV和密文
            byte[] iv = new byte[GCM_IV_LENGTH];
            byte[] encrypted = new byte[combined.length - GCM_IV_LENGTH];
            System.arraycopy(combined, 0, iv, 0, iv.length);
            System.arraycopy(combined, iv.length, encrypted, 0, encrypted.length);
            
            // 创建密钥
            SecretKeySpec keySpec = new SecretKeySpec(
                    padKey(secretKey).getBytes(StandardCharsets.UTF_8), ALGORITHM);
            
            // 初始化解密器
            Cipher cipher = Cipher.getInstance(TRANSFORMATION);
            GCMParameterSpec gcmSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
            cipher.init(Cipher.DECRYPT_MODE, keySpec, gcmSpec);
            
            // 解密
            byte[] decrypted = cipher.doFinal(encrypted);
            
            return new String(decrypted, StandardCharsets.UTF_8);
        } catch (Exception e) {
            log.error("AES解密失败: {}", e.getMessage());
            throw new RuntimeException("解密失败", e);
        }
    }

    /**
     * 加密身份证号（仅加密，用于存储）
     */
    public String encryptIdCard(String idCard) {
        return encrypt(idCard);
    }

    /**
     * 解密身份证号
     */
    public String decryptIdCard(String encryptedIdCard) {
        return decrypt(encryptedIdCard);
    }

    /**
     * 脱敏身份证号（用于显示）
     * 保留前6位和后4位，中间用*替代
     */
    public String maskIdCard(String idCard) {
        if (idCard == null || idCard.length() < 15) {
            return idCard;
        }
        return idCard.substring(0, 6) + "********" + idCard.substring(idCard.length() - 4);
    }

    /**
     * 脱敏手机号（用于显示）
     * 保留前3位和后4位，中间用*替代
     */
    public String maskPhone(String phone) {
        if (phone == null || phone.length() < 11) {
            return phone;
        }
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 4);
    }

    /**
     * 脱敏银行卡号/支付宝账号
     */
    public String maskAccount(String account) {
        if (account == null || account.length() < 8) {
            return account;
        }
        int showLength = 4;
        return account.substring(0, showLength) + "****" + account.substring(account.length() - showLength);
    }

    /**
     * 确保密钥长度为32字节
     */
    private String padKey(String key) {
        if (key.length() >= 32) {
            return key.substring(0, 32);
        }
        StringBuilder sb = new StringBuilder(key);
        while (sb.length() < 32) {
            sb.append("0");
        }
        return sb.toString();
    }

    /**
     * 生成随机AES密钥
     */
    public static String generateKey() {
        try {
            KeyGenerator keyGen = KeyGenerator.getInstance(ALGORITHM);
            keyGen.init(256, new SecureRandom());
            SecretKey secretKey = keyGen.generateKey();
            return Base64.getEncoder().encodeToString(secretKey.getEncoded());
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("生成密钥失败", e);
        }
    }
}
