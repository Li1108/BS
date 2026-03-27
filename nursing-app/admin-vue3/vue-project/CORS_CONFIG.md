# 后端CORS配置指南

## 问题背景

Vue前端（`http://localhost:3000`）和Spring Boot后端（`http://localhost:8081`）运行在不同端口，会遇到跨域资源共享（CORS）限制。

## 前端配置（已完成）

### 1. Vite代理配置

`vite.config.js` 已配置开发代理：

```javascript
export default defineConfig({
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: process.env.VITE_API_TARGET || 'http://localhost:8081',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
        configure: (proxy) => {
          proxy.on('error', (err) => {
            console.log('Proxy Error:', err)
          })
          proxy.on('proxyReq', (proxyReq, req) => {
            console.log('Sending Request:', req.method, req.url)
          })
          proxy.on('proxyRes', (proxyRes, req) => {
            console.log('Received Response:', proxyRes.statusCode, req.url)
          })
        }
      }
    }
  }
})
```

**工作原理**:
- 前端请求 `/api/orders` → 代理转发到 `http://localhost:8081/orders`
- `changeOrigin: true` 修改请求头的Origin
- 开发环境下避免CORS问题

### 2. Axios配置

`src/utils/request.js` 已配置：

```javascript
const request = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/api',
  timeout: 10000
})

// 请求拦截器添加Token
request.interceptors.request.use(config => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})
```

## 后端配置（需要配置）

### 方案1: 全局CORS配置（推荐）

在Spring Boot主配置类添加CORS配置：

```java
package com.nursing.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.CorsFilter;

@Configuration
public class CorsConfig {

    @Bean
    public CorsFilter corsFilter() {
        CorsConfiguration config = new CorsConfiguration();
        
        // 允许的源（开发环境）
        config.addAllowedOrigin("http://localhost:3000");
        config.addAllowedOrigin("http://127.0.0.1:3000");
        
        // 允许所有HTTP方法
        config.addAllowedMethod("*");
        
        // 允许所有请求头
        config.addAllowedHeader("*");
        
        // 允许发送Cookie
        config.setAllowCredentials(true);
        
        // 预检请求缓存时间（秒）
        config.setMaxAge(3600L);
        
        // 暴露的响应头
        config.addExposedHeader("Authorization");
        config.addExposedHeader("Content-Disposition");
        
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        
        return new CorsFilter(source);
    }
}
```

### 方案2: WebMvcConfigurer配置

```java
package com.nursing.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOrigins("http://localhost:3000", "http://127.0.0.1:3000")
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(true)
                .maxAge(3600);
    }
}
```

### 方案3: 控制器注解（不推荐）

在单个Controller上添加：

```java
@RestController
@RequestMapping("/orders")
@CrossOrigin(origins = "http://localhost:3000", allowCredentials = "true")
public class OrderController {
    // ...
}
```

**缺点**: 需要在每个Controller上添加，不够灵活。

## 生产环境配置

### 1. 前端环境变量

`.env.production`:
```properties
VITE_API_BASE_URL=https://api.yourdomain.com
```

### 2. 后端CORS配置

```java
@Configuration
public class CorsConfig {

    @Value("${app.cors.allowed-origins}")
    private String[] allowedOrigins;

    @Bean
    public CorsFilter corsFilter() {
        CorsConfiguration config = new CorsConfiguration();
        
        // 从配置文件读取允许的源
        for (String origin : allowedOrigins) {
            config.addAllowedOrigin(origin);
        }
        
        config.addAllowedMethod("*");
        config.addAllowedHeader("*");
        config.setAllowCredentials(true);
        config.setMaxAge(3600L);
        
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        
        return new CorsFilter(source);
    }
}
```

`application-prod.yml`:
```yaml
app:
  cors:
    allowed-origins:
      - https://admin.yourdomain.com
      - https://yourdomain.com
```

## 安全考虑

### 1. 不要使用通配符

❌ **错误**:
```java
config.addAllowedOrigin("*");  // 不安全！
config.setAllowCredentials(true); // 与*冲突
```

✅ **正确**:
```java
config.addAllowedOrigin("http://localhost:3000");
config.addAllowedOrigin("https://yourdomain.com");
config.setAllowCredentials(true);
```

### 2. 限制HTTP方法

```java
config.addAllowedMethod("GET");
config.addAllowedMethod("POST");
config.addAllowedMethod("PUT");
config.addAllowedMethod("DELETE");
// 不允许TRACE, CONNECT等
```

### 3. 限制请求头

```java
config.addAllowedHeader("Content-Type");
config.addAllowedHeader("Authorization");
config.addAllowedHeader("X-Requested-With");
```

## 调试CORS问题

### 1. 浏览器开发者工具

检查Network面板：
- **预检请求**: OPTIONS方法，状态码应为200或204
- **实际请求**: 检查响应头 `Access-Control-Allow-Origin`

### 2. 后端日志

添加日志拦截器：

```java
@Component
public class CorsLoggingFilter implements Filter {
    
    private static final Logger logger = LoggerFactory.getLogger(CorsLoggingFilter.class);
    
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain) 
            throws IOException, ServletException {
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        
        logger.info("CORS Request - Method: {}, Origin: {}, URI: {}", 
            httpRequest.getMethod(),
            httpRequest.getHeader("Origin"),
            httpRequest.getRequestURI()
        );
        
        chain.doFilter(request, response);
        
        HttpServletResponse httpResponse = (HttpServletResponse) response;
        logger.info("CORS Response - Allow-Origin: {}", 
            httpResponse.getHeader("Access-Control-Allow-Origin")
        );
    }
}
```

### 3. 前端Vite代理日志

Vite配置已包含代理日志，启动dev server时会输出：

```
Sending Request: GET /api/orders
Received Response: 200 /api/orders
```

## 常见错误

### 1. CORS错误: "No 'Access-Control-Allow-Origin' header"

**原因**: 后端未配置CORS  
**解决**: 按上述方案配置后端

### 2. CORS错误: "Credentials flag is 'true', but origin is '*'"

**原因**: `allowCredentials=true` 和 `allowedOrigin="*"` 冲突  
**解决**: 指定具体的Origin而不是通配符

### 3. OPTIONS预检请求失败

**原因**: 后端未处理OPTIONS方法  
**解决**: Spring Boot的CORS过滤器会自动处理，确保过滤器已配置

### 4. Token未传递

**原因**: `allowCredentials` 未设置  
**解决**: 
```java
config.setAllowCredentials(true);  // 后端
```

```javascript
// 前端Axios（已配置）
request.interceptors.request.use(config => {
  const token = localStorage.getItem('token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})
```

## 验证配置

### 1. 测试预检请求

```bash
curl -X OPTIONS http://localhost:8081/orders \
  -H "Origin: http://localhost:3000" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type,Authorization" \
  -v
```

期望响应头：
```
Access-Control-Allow-Origin: http://localhost:3000
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
Access-Control-Allow-Credentials: true
```

### 2. 前端测试

运行前端项目：
```bash
npm run dev
```

打开浏览器开发者工具，查看Network面板，检查：
- ✅ 没有CORS错误
- ✅ OPTIONS预检请求返回200
- ✅ 实际请求返回数据

## 总结

1. **开发环境**: 使用Vite代理 + 后端CORS配置
2. **生产环境**: 前端直接请求后端域名 + 后端CORS白名单
3. **安全第一**: 不使用通配符，指定具体源和方法
4. **调试工具**: 浏览器Network面板 + 后端日志

完成后端CORS配置后，前端应该能正常调用所有API。
