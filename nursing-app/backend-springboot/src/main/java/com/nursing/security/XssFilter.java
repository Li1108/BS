package com.nursing.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.lang.NonNull;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.regex.Pattern;

/**
 * XSS 过滤器
 * 防止跨站脚本攻击
 */
@Slf4j
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 1)
public class XssFilter extends OncePerRequestFilter {

    /**
     * XSS攻击模式匹配
     */
    private static final Pattern[] XSS_PATTERNS = {
            // Script tags
            Pattern.compile("<script>(.*?)</script>", Pattern.CASE_INSENSITIVE),
            Pattern.compile("src[\r\n]*=[\r\n]*'(.*?)'", Pattern.CASE_INSENSITIVE | Pattern.MULTILINE | Pattern.DOTALL),
            Pattern.compile("src[\r\n]*=[\r\n]*\"(.*?)\"", Pattern.CASE_INSENSITIVE | Pattern.MULTILINE | Pattern.DOTALL),
            // Standalone script tags
            Pattern.compile("</script>", Pattern.CASE_INSENSITIVE),
            Pattern.compile("<script(.*?)>", Pattern.CASE_INSENSITIVE | Pattern.MULTILINE | Pattern.DOTALL),
            // eval(...)
            Pattern.compile("eval\\((.*?)\\)", Pattern.CASE_INSENSITIVE | Pattern.MULTILINE | Pattern.DOTALL),
            // expression(...)
            Pattern.compile("expression\\((.*?)\\)", Pattern.CASE_INSENSITIVE | Pattern.MULTILINE | Pattern.DOTALL),
            // javascript:
            Pattern.compile("javascript:", Pattern.CASE_INSENSITIVE),
            // vbscript:
            Pattern.compile("vbscript:", Pattern.CASE_INSENSITIVE),
            // onload, onerror, onclick等事件
            Pattern.compile("on\\w+\\s*=", Pattern.CASE_INSENSITIVE | Pattern.MULTILINE | Pattern.DOTALL),
            // iframe
            Pattern.compile("<iframe(.*?)>", Pattern.CASE_INSENSITIVE | Pattern.MULTILINE | Pattern.DOTALL),
    };

    @Override
    protected void doFilterInternal(@NonNull HttpServletRequest request,
                                    @NonNull HttpServletResponse response,
                                    @NonNull FilterChain filterChain) throws ServletException, IOException {
        // 包装请求，过滤XSS
        XssHttpServletRequestWrapper xssRequest = new XssHttpServletRequestWrapper(request);
        filterChain.doFilter(xssRequest, response);
    }

    /**
     * XSS请求包装器
     */
    public static class XssHttpServletRequestWrapper extends HttpServletRequestWrapper {

        public XssHttpServletRequestWrapper(HttpServletRequest request) {
            super(request);
        }

        @Override
        public String[] getParameterValues(String parameter) {
            String[] values = super.getParameterValues(parameter);
            if (values == null) {
                return null;
            }
            
            int count = values.length;
            String[] cleanValues = new String[count];
            for (int i = 0; i < count; i++) {
                cleanValues[i] = cleanXss(values[i]);
            }
            return cleanValues;
        }

        @Override
        public String getParameter(String parameter) {
            String value = super.getParameter(parameter);
            return cleanXss(value);
        }

        @Override
        public String getHeader(String name) {
            String value = super.getHeader(name);
            return cleanXss(value);
        }

        /**
         * 清理XSS内容
         */
        private String cleanXss(String value) {
            if (!StringUtils.hasText(value)) {
                return value;
            }
            
            String cleanValue = value;
            for (Pattern pattern : XSS_PATTERNS) {
                cleanValue = pattern.matcher(cleanValue).replaceAll("");
            }
            
            // HTML实体编码
            cleanValue = cleanValue
                    .replace("<", "&lt;")
                    .replace(">", "&gt;")
                    .replace("\"", "&quot;")
                    .replace("'", "&#x27;");
            
            return cleanValue;
        }
    }
}
