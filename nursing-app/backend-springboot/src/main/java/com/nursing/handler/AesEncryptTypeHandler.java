package com.nursing.handler;

import com.nursing.utils.AesEncryptUtils;
import lombok.extern.slf4j.Slf4j;
import org.apache.ibatis.type.BaseTypeHandler;
import org.apache.ibatis.type.JdbcType;
import org.apache.ibatis.type.MappedJdbcTypes;
import org.apache.ibatis.type.MappedTypes;
import org.springframework.beans.factory.annotation.Autowired;

import java.sql.CallableStatement;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

/**
 * AES加密字段类型处理器
 * 用于自动加解密数据库中的敏感字段（如身份证号）
 * 
 * 使用方式：在Entity字段上添加 @TableField(typeHandler = AesEncryptTypeHandler.class)
 */
@Slf4j
@MappedTypes(String.class)
@MappedJdbcTypes(JdbcType.VARCHAR)
public class AesEncryptTypeHandler extends BaseTypeHandler<String> {

    private static AesEncryptUtils aesEncryptUtils;

    @Autowired
    public void setAesEncryptUtils(AesEncryptUtils aesEncryptUtils) {
        AesEncryptTypeHandler.aesEncryptUtils = aesEncryptUtils;
    }

    @Override
    public void setNonNullParameter(PreparedStatement ps, int i, String parameter, JdbcType jdbcType) throws SQLException {
        // 插入/更新时加密
        if (parameter != null && !parameter.isEmpty()) {
            try {
                ps.setString(i, aesEncryptUtils.encrypt(parameter));
            } catch (Exception e) {
                log.error("加密失败: {}", e.getMessage());
                ps.setString(i, parameter);
            }
        } else {
            ps.setString(i, parameter);
        }
    }

    @Override
    public String getNullableResult(ResultSet rs, String columnName) throws SQLException {
        // 查询时解密
        String value = rs.getString(columnName);
        return decrypt(value);
    }

    @Override
    public String getNullableResult(ResultSet rs, int columnIndex) throws SQLException {
        String value = rs.getString(columnIndex);
        return decrypt(value);
    }

    @Override
    public String getNullableResult(CallableStatement cs, int columnIndex) throws SQLException {
        String value = cs.getString(columnIndex);
        return decrypt(value);
    }

    private String decrypt(String value) {
        if (value == null || value.isEmpty()) {
            return value;
        }
        try {
            return aesEncryptUtils.decrypt(value);
        } catch (Exception e) {
            log.warn("解密失败，返回原值: {}", e.getMessage());
            return value;
        }
    }
}
