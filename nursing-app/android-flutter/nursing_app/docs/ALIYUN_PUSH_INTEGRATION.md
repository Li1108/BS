# 阿里云移动推送SDK集成指南

## 概述

本文档说明如何在护理服务APP中集成阿里云移动推送（EMAS Push）SDK，支持自有通道和厂商通道。

## 1. 阿里云EMAS控制台配置

### 1.1 创建应用
1. 登录 [阿里云EMAS控制台](https://emas.console.aliyun.com/)
2. 创建新应用或选择现有应用
3. 获取 **AppKey** 和 **AppSecret**
4. 在 `sys_config` 表中配置：
   ```sql
   UPDATE sys_config SET config_value = 'your_app_key' WHERE config_key = 'aliyun_push_app_key';
   UPDATE sys_config SET config_value = 'your_app_secret' WHERE config_key = 'aliyun_push_app_secret';
   ```

### 1.2 配置推送证书
- Android: 配置包名和签名证书SHA256
- iOS: 上传APNs推送证书

## 2. Android SDK集成

### 2.1 添加依赖

在 `android/app/build.gradle.kts` 中添加：

```kotlin
dependencies {
    // 阿里云移动推送SDK
    implementation("com.aliyun.ams:alicloud-android-push:3.8.5")
    
    // 厂商通道SDK（可选，提升到达率）
    // 华为HMS Push
    implementation("com.aliyun.ams:alicloud-android-third-push-huawei:3.8.5")
    implementation("com.huawei.hms:push:6.11.0.300")
    
    // 小米MiPush
    implementation("com.aliyun.ams:alicloud-android-third-push-xiaomi:3.8.5")
    
    // OPPO Push
    implementation("com.aliyun.ams:alicloud-android-third-push-oppo:3.8.5")
    
    // vivo Push
    implementation("com.aliyun.ams:alicloud-android-third-push-vivo:3.8.5")
    
    // 魅族Flyme Push
    implementation("com.aliyun.ams:alicloud-android-third-push-meizu:3.8.5")
}
```

### 2.2 添加Maven仓库

在 `android/build.gradle.kts` 中添加：

```kotlin
allprojects {
    repositories {
        google()
        mavenCentral()
        
        // 阿里云Maven仓库
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        
        // 华为Maven仓库（华为通道需要）
        maven { url = uri("https://developer.huawei.com/repo/") }
    }
}
```

### 2.3 配置AndroidManifest.xml

已在 `AndroidManifest.xml` 中配置的权限：
- `INTERNET` - 网络访问
- `ACCESS_NETWORK_STATE` - 网络状态
- `ACCESS_WIFI_STATE` - WiFi状态
- `WAKE_LOCK` - 保持唤醒
- `RECEIVE_BOOT_COMPLETED` - 开机启动
- `VIBRATE` - 振动
- `POST_NOTIFICATIONS` - 通知权限（Android 13+）

### 2.4 初始化SDK

在 `NursingApplication.kt` 中初始化：

```kotlin
private fun initAliyunPush() {
    val pushService = PushServiceFactory.getCloudPushService()
    pushService.register(applicationContext, object : CommonCallback {
        override fun onSuccess(response: String?) {
            Log.i(TAG, "推送初始化成功: $response")
        }
        override fun onFailed(errorCode: String?, errorMessage: String?) {
            Log.e(TAG, "推送初始化失败: $errorCode - $errorMessage")
        }
    })
}
```

## 3. 厂商通道配置

### 3.1 华为HMS Push

1. 在 [华为开发者联盟](https://developer.huawei.com/) 注册应用
2. 下载 `agconnect-services.json` 放到 `android/app/` 目录
3. 获取 AppId 和 AppSecret
4. 在 `NursingApplication.kt` 中注册：
   ```kotlin
   HuaWeiRegister.register(this)
   ```

### 3.2 小米MiPush

1. 在 [小米开放平台](https://dev.mi.com/) 注册应用
2. 获取 AppId 和 AppKey
3. 在 `NursingApplication.kt` 中注册：
   ```kotlin
   MiPushRegister.register(this, XIAOMI_APP_ID, XIAOMI_APP_KEY)
   ```

### 3.3 OPPO Push

1. 在 [OPPO开放平台](https://open.oppomobile.com/) 注册应用
2. 获取 AppKey 和 AppSecret
3. 在 `NursingApplication.kt` 中注册：
   ```kotlin
   OppoRegister.register(this, OPPO_APP_KEY, OPPO_APP_SECRET)
   ```

### 3.4 vivo Push

1. 在 [vivo开放平台](https://dev.vivo.com.cn/) 注册应用
2. 获取 AppId 和 AppKey
3. 在 `NursingApplication.kt` 中注册：
   ```kotlin
   VivoRegister.register(this)
   ```

### 3.5 魅族Flyme Push

1. 在 [魅族开放平台](https://open.flyme.cn/) 注册应用
2. 获取 AppId 和 AppKey
3. 在 `NursingApplication.kt` 中注册：
   ```kotlin
   MeizuRegister.register(this, MEIZU_APP_ID, MEIZU_APP_KEY)
   ```

## 4. Flutter集成

### 4.1 推送服务使用

```dart
import 'package:nursing_app/core/services/aliyun_push_service.dart';

// 初始化推送服务
final pushService = AliyunPushService.instance;
await pushService.init();

// 设置通知回调
pushService.setNotificationCallback(
  onReceived: (notification) {
    print('收到通知: $notification');
  },
  onOpened: (notification) {
    print('通知被点击: $notification');
    // 根据通知类型跳转到相应页面
    _handleNotificationNavigation(notification);
  },
);

// 登录后绑定账号
await pushService.bindAccount(userId);

// 护士端绑定标签
await pushService.bindNurseTags(
  nurseId: '123',
  city: 'hangzhou',
  workModeOn: true,
);

// 用户端绑定标签
await pushService.bindUserTags(
  userId: '456',
  city: 'hangzhou',
);

// 退出登录时解绑
await pushService.unbindAccount();
```

### 4.2 通知跳转处理

```dart
void _handleNotificationNavigation(Map<String, dynamic> notification) {
  final data = notification['data'] as Map<String, dynamic>?;
  if (data == null) return;

  final type = data['type'] as String?;
  final orderId = data['orderId'] as String?;

  switch (type) {
    case 'new_order':
      // 护士端：跳转到订单详情接单
      context.router.push(NurseTaskDetailRoute(orderId: orderId!));
      break;
    case 'order_status':
      // 用户端：跳转到订单详情
      context.router.push(OrderDetailRoute(orderId: orderId!));
      break;
    case 'audit_result':
      // 护士端：跳转到个人资料页
      context.router.push(const NurseProfileRoute());
      break;
    case 'withdraw_result':
      // 护士端：跳转到收入页
      context.router.push(const NurseIncomeRoute());
      break;
  }
}
```

## 5. 后端推送API

### 5.1 服务端SDK依赖

在 Spring Boot 项目的 `pom.xml` 中添加：

```xml
<dependency>
    <groupId>com.aliyun</groupId>
    <artifactId>aliyun-java-sdk-push</artifactId>
    <version>3.13.12</version>
</dependency>
```

### 5.2 推送服务实现

```java
@Service
public class AliyunPushService {
    
    @Value("${aliyun.push.app-key}")
    private String appKey;
    
    @Value("${aliyun.push.access-key-id}")
    private String accessKeyId;
    
    @Value("${aliyun.push.access-key-secret}")
    private String accessKeySecret;
    
    /**
     * 推送新订单通知给附近护士
     */
    public void pushNewOrderToNurses(Order order, List<String> nurseIds) {
        PushNoticeToAndroidRequest request = new PushNoticeToAndroidRequest();
        request.setAppKey(Long.parseLong(appKey));
        request.setTarget("ACCOUNT");
        request.setTargetValue(String.join(",", nurseIds));
        request.setTitle("📍 附近有新订单");
        request.setBody(order.getServiceName() + " - 距离您" + order.getDistance() + "公里");
        request.setExtParameters("{\"type\":\"new_order\",\"orderId\":\"" + order.getId() + "\"}");
        
        // 发送推送
        pushClient.pushNoticeToAndroid(request);
    }
    
    /**
     * 推送订单状态更新给用户
     */
    public void pushOrderStatusToUser(Order order) {
        String message = getStatusMessage(order.getStatus());
        
        PushNoticeToAndroidRequest request = new PushNoticeToAndroidRequest();
        request.setAppKey(Long.parseLong(appKey));
        request.setTarget("ACCOUNT");
        request.setTargetValue(order.getUserId().toString());
        request.setTitle("订单状态更新");
        request.setBody(message);
        request.setExtParameters("{\"type\":\"order_status\",\"orderId\":\"" + order.getId() + "\",\"status\":" + order.getStatus() + "}");
        
        pushClient.pushNoticeToAndroid(request);
    }
}
```

## 6. 测试

### 6.1 运行集成测试

```bash
cd android-flutter/nursing_app
flutter test integration_test/push_notification_test.dart
```

### 6.2 测试推送

1. 使用阿里云EMAS控制台的"推送测试"功能
2. 填入设备ID进行测试推送
3. 验证APP能正确接收和处理通知

## 7. 常见问题

### Q1: 推送无法到达
- 检查AppKey和AppSecret是否正确
- 检查设备是否成功注册
- 检查厂商通道是否正确配置
- 查看阿里云控制台的推送记录

### Q2: 点击通知无法跳转
- 检查通知的extra参数是否正确传递
- 检查Flutter层的回调是否正确设置
- 查看日志确认通知点击事件是否触发

### Q3: 厂商通道不生效
- 确保已正确配置各厂商的AppId/AppKey
- 确保已调用对应的Register方法
- 在各厂商开发者后台检查应用状态
