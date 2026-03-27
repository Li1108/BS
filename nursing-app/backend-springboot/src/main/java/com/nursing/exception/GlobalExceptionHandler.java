package com.nursing.exception;

import com.nursing.common.Result;
import io.jsonwebtoken.ExpiredJwtException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.validation.BindException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpMediaTypeNotSupportedException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.servlet.NoHandlerFoundException;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 全局异常处理器
 */
@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    /**
     * 处理参数校验异常
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Result<Void> handleValidationException(MethodArgumentNotValidException e) {
        List<FieldError> fieldErrors = e.getBindingResult().getFieldErrors();
        String message = fieldErrors.stream()
                .map(error -> error.getField() + ": " + error.getDefaultMessage())
                .collect(Collectors.joining("; "));
        log.warn("参数校验失败: {}", message);
        return Result.badRequest(message);
    }

    /**
     * 处理绑定异常
     */
    @ExceptionHandler(BindException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Result<Void> handleBindException(BindException e) {
        List<FieldError> fieldErrors = e.getBindingResult().getFieldErrors();
        String message = fieldErrors.stream()
                .map(error -> error.getField() + ": " + error.getDefaultMessage())
                .collect(Collectors.joining("; "));
        log.warn("参数绑定失败: {}", message);
        return Result.badRequest(message);
    }

    /**
     * 处理缺少请求参数异常
     */
    @ExceptionHandler(MissingServletRequestParameterException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Result<Void> handleMissingParameterException(MissingServletRequestParameterException e) {
        log.warn("缺少请求参数: {}", e.getParameterName());
        return Result.badRequest("缺少必要参数: " + e.getParameterName());
    }

    /**
     * 处理请求体解析异常
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Result<Void> handleMessageNotReadableException(HttpMessageNotReadableException e) {
        log.warn("请求体解析失败: {}", e.getMessage());
        return Result.badRequest("请求体格式错误");
    }

    /**
     * 处理请求方法不支持异常
     */
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    @ResponseStatus(HttpStatus.METHOD_NOT_ALLOWED)
    public Result<Void> handleMethodNotSupportedException(HttpRequestMethodNotSupportedException e) {
        log.warn("请求方法不支持: {}", e.getMethod());
        return Result.error(405, "不支持的请求方法: " + e.getMethod());
    }

    /**
     * 处理媒体类型不支持异常
     */
    @ExceptionHandler(HttpMediaTypeNotSupportedException.class)
    @ResponseStatus(HttpStatus.UNSUPPORTED_MEDIA_TYPE)
    public Result<Void> handleMediaTypeNotSupportedException(HttpMediaTypeNotSupportedException e) {
        log.warn("媒体类型不支持: {}", e.getContentType());
        return Result.error(415, "不支持的媒体类型");
    }

    /**
     * 处理404异常
     */
    @ExceptionHandler(NoHandlerFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public Result<Void> handleNoHandlerFoundException(NoHandlerFoundException e) {
        log.warn("接口不存在: {} {}", e.getHttpMethod(), e.getRequestURL());
        return Result.notFound("接口不存在");
    }

    /**
     * 处理文件上传大小超限异常
     */
    @ExceptionHandler(MaxUploadSizeExceededException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Result<Void> handleMaxUploadSizeExceededException(MaxUploadSizeExceededException e) {
        log.warn("文件大小超限: {}", e.getMessage());
        return Result.badRequest("文件大小超过限制");
    }

    /**
     * 处理JWT过期异常
     */
    @ExceptionHandler(ExpiredJwtException.class)
    @ResponseStatus(HttpStatus.UNAUTHORIZED)
    public Result<Void> handleExpiredJwtException(ExpiredJwtException e) {
        log.warn("Token已过期");
        return Result.unauthorized("登录已过期，请重新登录");
    }

    /**
     * 处理访问拒绝异常（权限不足）
     */
    @ExceptionHandler(AccessDeniedException.class)
    @ResponseStatus(HttpStatus.FORBIDDEN)
    public Result<Void> handleAccessDeniedException(AccessDeniedException e) {
        log.warn("访问被拒绝: {}", e.getMessage());
        return Result.forbidden("没有权限执行此操作");
    }

    /**
     * 处理支付异常
     */
    @ExceptionHandler(PaymentException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Result<Map<String, Object>> handlePaymentException(PaymentException e) {
        log.error("支付异常: orderNo={}, errorType={}, message={}",
                e.getOrderNo(), e.getErrorType(), e.getMessage());
        
        Map<String, Object> data = new HashMap<>();
        data.put("orderNo", e.getOrderNo());
        data.put("errorType", e.getErrorType().name());
        
        return Result.<Map<String, Object>>builder()
                .code(e.getCode())
            .msg(e.getMessage())
                .data(data)
                .build();
    }

    /**
     * 处理订单异常
     */
    @ExceptionHandler(OrderException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Result<Map<String, Object>> handleOrderException(OrderException e) {
        log.warn("订单异常: orderId={}, errorType={}, message={}",
                e.getOrderId(), e.getErrorType(), e.getMessage());
        
        Map<String, Object> data = new HashMap<>();
        data.put("orderId", e.getOrderId());
        data.put("errorType", e.getErrorType().name());
        
        return Result.<Map<String, Object>>builder()
                .code(e.getCode())
            .msg(e.getMessage())
                .data(data)
                .build();
    }

    /**
     * 处理业务异常
     */
    @ExceptionHandler(BusinessException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public Result<Void> handleBusinessException(BusinessException e) {
        log.warn("业务异常: code={}, message={}", e.getCode(), e.getMessage());
        return Result.error(e.getCode(), e.getMessage());
    }

    /**
     * 处理运行时异常
     */
    @ExceptionHandler(RuntimeException.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public Result<Void> handleRuntimeException(RuntimeException e) {
        log.error("业务异常: {}", e.getMessage(), e);
        return Result.error(e.getMessage());
    }

    /**
     * 处理未知异常
     */
    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public Result<Void> handleException(Exception e) {
        log.error("系统异常: {}", e.getMessage(), e);
        return Result.error("系统繁忙，请稍后重试");
    }
}
