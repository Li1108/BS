package com.nursing.common;

import com.fasterxml.jackson.annotation.JsonGetter;
import com.fasterxml.jackson.annotation.JsonSetter;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 统一响应结果
 * 成功: {"code": 0, "msg": "success", "data": {...}}
 * 错误: {"code": 40001, "msg": "参数错误", "data": null}
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Result<T> {

    /** 响应码 0=成功 */
    private Integer code;
    /** 响应消息 */
    private String msg;
    /** 响应数据 */
    private T data;

    @JsonGetter("message")
    public String getMessage() {
        return msg;
    }

    @JsonSetter("message")
    public void setMessage(String message) {
        this.msg = message;
    }

    // ==================== 成功响应 ====================

    public static <T> Result<T> success() {
        return Result.<T>builder()
                .code(0)
                .msg("success")
                .build();
    }

    public static <T> Result<T> success(T data) {
        return Result.<T>builder()
                .code(0)
                .msg("success")
                .data(data)
                .build();
    }

    public static <T> Result<T> success(String message, T data) {
        return Result.<T>builder()
                .code(0)
                .msg(message)
                .data(data)
                .build();
    }

    // ==================== 错误响应 ====================

    public static <T> Result<T> error(String message) {
        return Result.<T>builder()
                .code(500)
                .msg(message)
                .build();
    }

    public static <T> Result<T> error(Integer code, String message) {
        return Result.<T>builder()
                .code(code)
                .msg(message)
                .build();
    }

    public static <T> Result<T> badRequest(String message) {
        return Result.<T>builder()
                .code(400)
                .msg(message)
                .build();
    }

    public static <T> Result<T> unauthorized(String message) {
        return Result.<T>builder()
                .code(401)
                .msg(message)
                .build();
    }

    public static <T> Result<T> forbidden(String message) {
        return Result.<T>builder()
                .code(403)
                .msg(message)
                .build();
    }

    public static <T> Result<T> notFound(String message) {
        return Result.<T>builder()
                .code(404)
                .msg(message)
                .build();
    }
}
