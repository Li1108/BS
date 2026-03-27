# 快速开始指南

## 一、环境准备

### 1. 安装Node.js

确保已安装 Node.js 16+ 和 npm：

```bash
node -v  # 应显示 v16.0.0 或更高
npm -v   # 应显示 8.0.0 或更高
```

### 2. 克隆项目

```bash
git clone <repository-url>
cd nursing-app/admin-vue3/vue-project
```

### 3. 安装依赖

```bash
npm install
```

## 二、配置环境变量

### 创建 .env.development 文件

```properties
# API基础URL - 开发环境使用代理
VITE_API_BASE_URL=/api

# 后端服务地址
VITE_API_TARGET=http://localhost:8081

# 高德地图API Key（需要申请）
VITE_AMAP_KEY=your_amap_key_here

# 应用端口
VITE_PORT=3000
```

### 申请高德地图Key

1. 访问 [高德开放平台](https://lbs.amap.com/)
2. 注册并登录
3. 进入"应用管理" -> "我的应用"
4. 创建新应用，选择"Web端（JS API）"
5. 复制Key并填入 `.env.development`

## 三、启动后端服务

### 确保Spring Boot后端正在运行

```bash
# 进入后端目录
cd backend-springboot

# 启动后端（确保MySQL已运行）
mvn spring-boot:run

# 或使用IDE运行主类
```

**后端应运行在**: `http://localhost:8081`

### 验证后端

访问 `http://localhost:8081/actuator/health` 应返回：

```json
{
  "status": "UP"
}
```

## 四、配置后端CORS

在Spring Boot后端添加CORS配置（详见 [CORS_CONFIG.md](CORS_CONFIG.md)）：

```java
@Configuration
public class CorsConfig {
    @Bean
    public CorsFilter corsFilter() {
        CorsConfiguration config = new CorsConfiguration();
        config.addAllowedOrigin("http://localhost:3000");
        config.addAllowedMethod("*");
        config.addAllowedHeader("*");
        config.setAllowCredentials(true);
        
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        
        return new CorsFilter(source);
    }
}
```

## 五、启动前端

```bash
npm run dev
```

访问 `http://localhost:3000`

## 六、登录系统

### 默认管理员账号

- **手机号**: `13800000000`
- **登录方式**: 验证码登录（点击“获取验证码”，输入短信验证码）

说明：

- 管理后台仅允许 `ADMIN` 角色登录
- 开发环境如未接入短信网关，可在后端日志中查看验证码或使用测试短信实现

## 七、验证功能

### 1. 登录成功

- 输入账号密码
- 点击登录
- 成功后跳转到仪表板

### 2. 查看订单列表

- 左侧菜单点击"订单管理"
- 应显示订单列表和统计卡片

### 3. 测试响应式

- 打开浏览器开发者工具
- 切换到移动设备视图（F12 -> 设备工具栏）
- 查看移动端布局

### 4. 查看地图

- 点击"地图视图"
- 应显示高德地图和护士/订单位置标记

## 八、运行测试

```bash
# 运行所有测试
npm run test

# 打开测试UI
npm run test:ui

# 生成覆盖率报告
npm run test:coverage
```

## 九、常见问题排查

### 问题1: 无法连接后端

**症状**: 页面显示"Network Error"或"接口请求失败"

**检查**:
1. 后端是否运行在8081端口？
2. MySQL数据库是否启动？
3. 浏览器控制台是否有CORS错误？

**解决**:
```bash
# 检查后端端口
netstat -ano | findstr 8081

# 检查Vite代理日志
# 应在终端看到: Sending Request: GET /api/orders
```

### 问题2: 登录失败

**症状**: 提示"账号或密码错误"

**检查**:
1. 数据库中是否有测试账号？
2. 密码是否加密存储（BCrypt）？

**解决**:
```sql
-- 查询数据库中的用户
SELECT * FROM sys_user WHERE phone = '13800000000';

-- 重置密码（使用BCrypt加密后的admin123）
UPDATE sys_user 
SET password = '$2a$10$...' 
WHERE phone = '13800000000';
```

### 问题3: 地图不显示

**症状**: 地图区域空白或显示错误

**检查**:
1. 高德地图Key是否配置？
2. 浏览器控制台是否有JS错误？

**解决**:
```javascript
// 检查环境变量
console.log(import.meta.env.VITE_AMAP_KEY)

// 应输出你的Key，而不是 undefined
```

### 问题4: Token过期

**症状**: 操作时突然跳转到登录页

**说明**: 这是正常的，Token有效期可能较短（如2小时）

**解决**: 重新登录即可

### 问题5: 测试失败

**症状**: `npm run test` 报错

**解决**:
```bash
# 清理依赖重新安装
rm -rf node_modules package-lock.json
npm install

# 清理测试缓存
npm run test -- --clearCache
```

## 十、开发建议

### 1. 推荐VSCode扩展

- Vue (Official)
- ESLint
- Prettier
- GitLens

### 2. 浏览器DevTools

安装 Vue.js devtools 扩展，方便调试Vue组件和Pinia状态。

### 3. 代码规范

- 使用 `<script setup>` 语法
- 组合式API优于选项式API
- 组件名使用大驼峰命名
- 使用 `composables/` 提取可复用逻辑

### 4. Git提交规范

```bash
feat: 新功能
fix: 修复bug
docs: 文档更新
style: 代码格式调整
refactor: 重构代码
test: 测试相关
chore: 构建/工具配置
```

## 十一、下一步

- 📖 阅读 [README.md](README.md) 了解完整功能
- 🧪 阅读 [TESTING.md](TESTING.md) 了解测试规范
- 🔧 阅读 [CORS_CONFIG.md](CORS_CONFIG.md) 配置后端CORS
- 🎨 自定义主题和样式
- 📱 测试移动端响应式布局
- 🚀 部署到生产环境

## 十二、技术支持

遇到问题？

1. 查看控制台错误信息
2. 检查Network面板的API请求
3. 查看Vue DevTools的组件状态
4. 搜索GitHub Issues
5. 联系项目维护者

---

**祝开发顺利！** 🎉
