# 集成测试说明

## 概述

本项目包含完整的 Flutter 集成测试，覆盖以下核心流程：
- 登录流程（手机号+验证码）
- 下单流程（选择服务→填写信息→支付）
- 推送通知流程（接收、点击、跳转）
- 护士端流程（注册、接单、服务、收入）

## 测试文件结构

```
integration_test/
├── app_test.dart              # 应用启动测试
├── login_flow_test.dart       # 登录流程测试
├── order_flow_test.dart       # 下单流程测试
├── push_notification_test.dart # 推送通知测试
├── nurse_flow_test.dart       # 护士端流程测试
└── helpers/
    ├── test_helpers.dart      # 测试辅助工具
    └── mock_push_service.dart # Mock推送服务
```

## 运行测试

### 1. 运行所有集成测试

```bash
# 在真机或模拟器上运行
flutter test integration_test

# 指定设备运行
flutter test integration_test -d <device_id>
```

### 2. 运行单个测试文件

```bash
# 登录流程测试
flutter test integration_test/login_flow_test.dart

# 下单流程测试
flutter test integration_test/order_flow_test.dart

# 推送通知测试
flutter test integration_test/push_notification_test.dart

# 护士端流程测试
flutter test integration_test/nurse_flow_test.dart
```

### 3. 生成测试报告

```bash
# 运行测试并生成报告
flutter test integration_test --coverage

# 查看覆盖率报告
genhtml coverage/lcov.info -o coverage/html
```

## 测试用例清单

### 登录流程 (T001-T005)
| 编号 | 测试用例 | 说明 |
|------|----------|------|
| T001 | 登录页面UI验证 | 验证页面元素完整性 |
| T002 | 手机号格式验证 | 测试无效手机号输入 |
| T003 | 验证码倒计时 | 验证60秒倒计时功能 |
| T004 | 角色跳转 | USER/NURSE跳转不同首页 |
| T005 | 禁用账户 | status=0无法登录 |

### 下单流程 (T101-T110)
| 编号 | 测试用例 | 说明 |
|------|----------|------|
| T101 | 服务列表加载 | 验证服务列表显示 |
| T102 | 分类筛选 | 测试服务分类筛选 |
| T103 | 服务详情 | 查看服务详情 |
| T104 | 订单填写 | 验证必填项 |
| T105 | 地址选择 | 高德地图集成 |
| T106 | 提交验证 | 表单验证 |
| T107 | 支付流程 | 支付宝沙箱 |
| T108 | 取消退款 | 30分钟内取消 |
| T109 | 状态筛选 | 订单状态Tab |
| T110 | 订单评价 | 5星评价功能 |

### 推送通知 (T201-T210)
| 编号 | 测试用例 | 说明 |
|------|----------|------|
| T201 | 服务初始化 | 推送SDK初始化 |
| T202 | 设备注册 | 获取设备ID |
| T203 | 账号绑定 | 登录后绑定 |
| T204 | 标签绑定 | 护士标签 |
| T205 | 消息接收 | 通知回调 |
| T206 | 点击跳转 | 通知点击处理 |
| T207 | 状态推送 | 订单状态通知 |
| T208 | 新订单推送 | 护士新订单 |
| T209 | 账号解绑 | 退出登录 |
| T210 | 权限检查 | 推送权限 |

### 护士端流程 (T301-T313)
| 编号 | 测试用例 | 说明 |
|------|----------|------|
| T301 | 护士注册 | 资质信息填写 |
| T302 | 证件上传 | 照片压缩上传 |
| T303 | 工作模式 | 开启/休息切换 |
| T304 | 位置上报 | 5分钟定时上报 |
| T305 | 任务列表 | 今日任务显示 |
| T306 | 任务详情 | 用户信息查看 |
| T307 | 导航功能 | 高德地图导航 |
| T308 | 到达打卡 | 到达现场照片 |
| T309 | 开始服务 | 服务前照片 |
| T310 | 完成服务 | 服务后照片 |
| T311 | 收入列表 | 余额与明细 |
| T312 | 申请提现 | 提现表单 |
| T313 | 提现记录 | 历史记录查看 |

## Mock服务说明

### MockPushService

用于在集成测试中模拟阿里云推送SDK行为：

```dart
// 模拟新订单推送
MockPushService.instance.simulateNewOrderNotification(
  orderId: '123456',
  serviceName: '静脉采血',
  distance: 1.2,
  address: '杭州市西湖区xxx路xxx号',
);

// 模拟订单状态更新
MockPushService.instance.simulateOrderStatusNotification(
  orderId: '123456',
  status: 3, // 已到达
  message: '护士已到达服务地点',
);
```

## 注意事项

1. **真机测试**：部分功能（相机、地图、支付）需要在真机上测试
2. **网络Mock**：生产环境API需要Mock，避免影响真实数据
3. **权限处理**：首次运行需要授予相关权限（位置、相机、通知）
4. **测试账号**：使用专用测试账号，避免使用生产账号
