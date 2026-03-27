# nursing_app

互联网+护理服务 APP（Flutter）

## Getting Started

### 1) 启动后端

后端默认地址：`http://localhost:8081/api/v1`

### 2) 配置 API_BASE_URL

本项目通过 `--dart-define` 配置后端地址：

- Android 模拟器：`http://10.0.2.2:8081/api/v1`
- iOS 模拟器：`http://localhost:8081/api/v1`
- 真机：替换为电脑局域网 IP，例如 `http://192.168.1.10:8081/api/v1`

示例（Android 模拟器）：

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api/v1
```

### 3) 高德地图 Key 配置

- Android 默认内置高德 Key，可直接运行定位功能。
- 如需覆盖（例如不同环境），可通过 `--dart-define` 传入：

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8081/api/v1 \
  --dart-define=AMAP_ANDROID_KEY=your_android_key
```

### 4) 登录/下单流程

- 发送验证码：登录页点击获取验证码（对应后端 `/auth/send-code`）
- 登录：使用手机号 + 验证码（对应后端 `/auth/login`）
- 服务列表：`/services/list`
- 创建订单：`/orders/create`
- 拉起支付：`/orders/{orderId}/pay`

### 5) 运行测试

```bash
flutter test
```

