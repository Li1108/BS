# Vitest 集成测试指南

## 测试概述

项目使用 **Vitest** 作为测试框架，提供快速的单元测试和集成测试。

### 测试工具栈
- **Vitest**: 测试框架
- **@vue/test-utils**: Vue组件测试工具
- **axios-mock-adapter**: Axios请求模拟
- **happy-dom**: 轻量级DOM环境

## 运行测试

```bash
# 运行所有测试
npm run test

# 运行测试UI界面
npm run test:ui

# 生成测试覆盖率报告
npm run test:coverage

# 监听模式（文件变化时自动重新运行）
npm run test -- --watch
```

## 测试目录结构

```
src/tests/
├── setup.js                    # 全局测试配置
├── api/
│   └── integration.test.js     # API集成测试
├── composables/
│   └── useResponsive.test.js   # Composable测试
├── stores/
│   └── stores.test.js          # Pinia Store测试
└── utils/
    └── request.test.js         # 工具函数测试
```

## 测试类型

### 1. 单元测试 (Unit Tests)

测试独立的函数、工具类和composables。

**示例**: `src/tests/composables/useResponsive.test.js`

```javascript
import { describe, it, expect } from 'vitest'
import { useResponsive } from '@/composables/useResponsive'

describe('useResponsive Composable', () => {
  it('应该返回所有响应式属性', () => {
    const { isMobile, isTablet, isDesktop } = useResponsive()
    
    expect(isMobile).toBeDefined()
    expect(isTablet).toBeDefined()
    expect(isDesktop).toBeDefined()
  })
})
```

### 2. Store测试

测试Pinia状态管理。

**示例**: `src/tests/stores/stores.test.js`

```javascript
import { setActivePinia, createPinia } from 'pinia'
import { useUserStore } from '@/stores/user'

describe('User Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
  })

  it('应该正确设置token', () => {
    const userStore = useUserStore()
    userStore.setToken('test-token')
    
    expect(userStore.token).toBe('test-token')
    expect(userStore.isLoggedIn).toBe(true)
  })
})
```

### 3. API测试

测试Axios请求（使用Mock Adapter）。

**示例**: `src/tests/utils/request.test.js`

```javascript
import axios from 'axios'
import MockAdapter from 'axios-mock-adapter'

describe('Request Utils', () => {
  let mock

  beforeEach(() => {
    mock = new MockAdapter(axios)
  })

  it('应该发送带token的请求', async () => {
    localStorage.setItem('token', 'test-token')
    
    mock.onGet('/api/test').reply(config => {
      expect(config.headers.Authorization).toBe('Bearer test-token')
      return [200, { code: 200, data: {} }]
    })

    await axios.get('/api/test')
  })
})
```

### 4. 集成测试

测试实际的API调用（需要后端服务运行）。

**示例**: `src/tests/api/integration.test.js`

```javascript
// 使用 describe.skip 跳过（需要后端运行）
describe.skip('Order API Integration Tests', () => {
  it('应该获取订单列表', async () => {
    const response = await getOrderList({ page: 1, pageSize: 10 })
    
    expect(response.code).toBe(200)
    expect(response.data).toHaveProperty('records')
  })
})
```

## 全局配置 (setup.js)

测试环境的全局配置包括：

- **Element Plus**: 自动注册组件
- **localStorage/sessionStorage**: Mock实现
- **window.matchMedia**: 响应式设计支持
- **IntersectionObserver/ResizeObserver**: 观察者API Mock
- **环境变量**: 测试专用的API_BASE_URL

## 编写测试最佳实践

### 1. 测试命名
```javascript
describe('功能模块名称', () => {
  it('应该...（期望行为）', () => {
    // 测试代码
  })
})
```

### 2. AAA模式
```javascript
it('测试用例', () => {
  // Arrange - 准备
  const input = 'test'
  
  // Act - 执行
  const result = someFunction(input)
  
  // Assert - 断言
  expect(result).toBe('expected')
})
```

### 3. 清理副作用
```javascript
beforeEach(() => {
  localStorage.clear()
  vi.clearAllMocks()
})

afterEach(() => {
  mock.restore()
})
```

### 4. Mock外部依赖
```javascript
vi.mock('@/stores/user', () => ({
  useUserStore: () => ({
    logout: vi.fn()
  })
}))
```

## 测试覆盖率

运行 `npm run test:coverage` 后，会生成 `coverage/` 目录：

- `coverage/index.html` - HTML覆盖率报告
- `coverage/lcov.info` - LCOV格式报告

目标覆盖率：
- **语句覆盖率**: > 80%
- **分支覆盖率**: > 75%
- **函数覆盖率**: > 80%
- **行覆盖率**: > 80%

## CI/CD集成

在CI/CD管道中运行测试：

```yaml
# GitHub Actions 示例
- name: Run Tests
  run: npm run test:coverage

- name: Upload Coverage
  uses: codecov/codecov-action@v3
  with:
    files: ./coverage/lcov.info
```

## 常见问题

### 1. localStorage未定义
已在 `setup.js` 中Mock，确保测试导入了setup文件。

### 2. Element Plus组件找不到
已在 `setup.js` 中全局注册，组件测试会自动可用。

### 3. Axios请求超时
集成测试需要后端服务运行，或使用 `describe.skip` 跳过。

### 4. 测试运行慢
- 使用 `--reporter=dot` 简化输出
- 减少并发测试数量 `--threads=false`
- 使用 `--run` 单次运行而非watch模式

## 下一步

1. 添加组件测试（如 LoginForm.vue, OrderTable.vue）
2. 增加E2E测试（使用Cypress或Playwright）
3. 配置CI/CD自动化测试
4. 提高测试覆盖率到80%以上
