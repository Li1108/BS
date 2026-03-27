# 护理服务管理后台

基于 Vue3 + Element Plus 的互联网+护理服务管理系统。

## 技术栈

- **Vue 3** - 渐进式JavaScript框架
- **Element Plus** - Vue 3 UI组件库
- **Pinia** - Vue状态管理
- **Vue Router** - 路由管理
- **Axios** - HTTP客户端
- **Vite** - 构建工具
- **Vitest** - 单元测试框架
- **VueUse** - Vue组合式函数库（响应式设计）
- **高德地图** - 地图服务集成

## 功能特性

### 核心功能
- ✅ 用户管理 - 用户列表、添加/编辑用户
- ✅ 订单管理 - 订单列表、统计、详情、状态管理
- ✅ 护士审核 - 护士资质审核、证书查看
- ✅ 评价管理 - 用户评价列表、回复管理
- ✅ 提现管理 - 护士提现申请审核
- ✅ 服务管理 - 护理服务项目配置
- ✅ 通知管理 - 系统通知发送
- ✅ 操作日志 - 系统操作记录
- ✅ 地图视图 - 护士/订单实时位置展示
- ✅ 系统配置 - 参数配置管理

### 技术特性
- 📱 **响应式设计** - 支持桌面端、平板、手机端
- 🔐 **JWT认证** - Bearer Token身份验证
- 🎨 **主题切换** - 亮色/暗色模式
- 📊 **数据可视化** - 统计图表展示
- 🗺️ **地图集成** - 高德地图实时位置
- 🧪 **单元测试** - Vitest测试覆盖

## 项目设置

### 安装依赖

```sh
npm install
```

### 开发环境运行

```sh
npm run dev
```

访问 `http://localhost:3000`

### 生产构建

```sh
npm run build
```

### 运行测试

```sh
# 运行所有测试
npm run test

# 测试UI界面
npm run test:ui

# 生成覆盖率报告
npm run test:coverage
```

## 环境配置

### 开发环境 (.env.development)

```properties
VITE_API_BASE_URL=/api
VITE_API_TARGET=http://localhost:8081
VITE_AMAP_KEY=your_amap_key_here
VITE_AMAP_SECURITY_JS_CODE=your_amap_security_js_code
```

### 生产环境 (.env.production)

```properties
VITE_API_BASE_URL=https://api.yourdomain.com
VITE_AMAP_KEY=your_amap_key_here
VITE_AMAP_SECURITY_JS_CODE=your_amap_security_js_code
```

## 后端配置

### 启动Spring Boot后端

确保后端服务运行在 `http://localhost:8081`

### CORS配置

查看 [CORS_CONFIG.md](CORS_CONFIG.md) 了解如何配置后端跨域支持。

## 测试指南

查看 [TESTING.md](TESTING.md) 了解详细的测试文档。

## 项目结构

```
src/
├── api/              # API接口定义
├── assets/           # 静态资源
├── components/       # 公共组件
├── composables/      # 组合式函数
│   └── useResponsive.js  # 响应式设计工具
├── layouts/          # 布局组件
├── router/           # 路由配置
├── stores/           # Pinia状态管理
├── tests/            # 测试文件
│   ├── api/          # API测试
│   ├── composables/  # Composable测试
│   ├── stores/       # Store测试
│   └── utils/        # 工具函数测试
├── utils/            # 工具函数
│   └── request.js    # Axios封装
├── views/            # 页面组件
│   ├── auth/         # 登录页
│   ├── dashboard/    # 仪表板
│   ├── orders/       # 订单管理
│   ├── users/        # 用户管理
│   ├── nurse/        # 护士审核
│   ├── evaluations/  # 评价管理
│   ├── withdrawals/  # 提现管理
│   ├── services/     # 服务管理
│   ├── notifications/# 通知管理
│   ├── map/          # 地图视图
│   └── system/       # 系统管理
├── App.vue           # 根组件
└── main.js           # 入口文件
```

## 开发指南

### 响应式设计

使用 `useResponsive` composable：

```javascript
import { useResponsive } from '@/composables/useResponsive'

const { 
  isMobile, 
  tableConfig, 
  dialogWidth,
  gutter,
  cardColSpan 
} = useResponsive()
```

### API调用

```javascript
import request from '@/utils/request'

// GET请求
const getOrders = (params) => request.get('/orders', { params })

// POST请求
const createOrder = (data) => request.post('/orders', data)

// PUT请求
const updateOrder = (id, data) => request.put(`/orders/${id}`, data)

// DELETE请求
const deleteOrder = (id) => request.delete(`/orders/${id}`)
```

### 状态管理

```javascript
import { useUserStore } from '@/stores/user'

const userStore = useUserStore()

// 读取状态
console.log(userStore.token, userStore.userInfo)

// 修改状态
userStore.setToken('new-token')
userStore.setUserInfo({ name: 'Admin' })

// 登出
userStore.logout()
```

## 常见问题

### 1. 跨域问题

开发环境使用Vite代理解决，生产环境需要配置后端CORS。详见 [CORS_CONFIG.md](CORS_CONFIG.md)

### 2. 高德地图加载失败

检查 `.env` 文件中的 `VITE_AMAP_KEY` 是否正确。

### 3. Token过期

系统会自动检测401响应并跳转到登录页。

### 4. 测试失败

确保已安装所有测试依赖：`npm install`

## 推荐IDE配置

- [VS Code](https://code.visualstudio.com/)
- [Vue (Official)](https://marketplace.visualstudio.com/items?itemName=Vue.volar) 扩展
- [ESLint](https://marketplace.visualstudio.com/items?itemName=dbaeumer.vscode-eslint) 扩展

## 浏览器DevTools

- Chrome/Edge: [Vue.js devtools](https://chromewebstore.google.com/detail/vuejs-devtools/nhdogjmejiglipccpnnnanhbledajbpd)
- Firefox: [Vue.js devtools](https://addons.mozilla.org/en-US/firefox/addon/vue-js-devtools/)

## License

MIT
