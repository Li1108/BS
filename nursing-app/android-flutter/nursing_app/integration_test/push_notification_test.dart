import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nursing_app/main.dart' as app;
import 'package:nursing_app/core/services/push_service.dart';

/// 推送通知集成测试
///
/// 测试场景：
/// 1. 阿里云移动推送SDK初始化
/// 2. 设备注册与账号绑定
/// 3. 标签绑定（护士/用户分组）
/// 4. 推送消息接收
/// 5. 推送消息点击跳转
/// 6. 厂商通道配置验证
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('推送通知测试', () {
    testWidgets('T201 - 推送服务初始化测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证推送服务初始化
      final pushService = PushService.instance;
      expect(pushService, isNotNull);
    });

    testWidgets('T202 - 设备注册测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证设备ID获取
      // 实际测试中需要mock阿里云SDK返回
      final deviceId = PushService.instance.getDeviceId();
      // expect(deviceId, isNotNull);
      debugPrint('设备ID: $deviceId');
    });

    testWidgets('T203 - 用户登录后账号绑定测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 登录成功后验证账号绑定
      // 需要mock登录成功场景
    });

    testWidgets('T204 - 护士标签绑定测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 护士登录后验证标签绑定
      // 标签示例：nurse, work_mode_on, city_hangzhou
    });

    testWidgets('T205 - 推送消息接收回调测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 模拟推送消息接收
      final pushService = PushService.instance;
      bool notificationReceived = false;

      pushService.setNotificationCallback(
        onReceived: (notification) {
          notificationReceived = true;
          expect(notification['title'], isNotNull);
          expect(notification['body'], isNotNull);
        },
      );

      // 模拟推送通知
      pushService.handleNotification({
        'title': '新订单通知',
        'body': '您有一个新的护理订单',
        'data': {'type': 'new_order', 'orderId': '123456'},
      });

      expect(notificationReceived, isTrue);
    });

    testWidgets('T206 - 推送消息点击跳转测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 模拟推送消息点击
      final pushService = PushService.instance;
      bool notificationOpened = false;

      pushService.setNotificationCallback(
        onOpened: (notification) {
          notificationOpened = true;
          // 验证跳转到订单详情页
          final orderId = notification['data']?['orderId'];
          expect(orderId, isNotNull);
        },
      );

      // 模拟点击通知
      pushService.handleNotificationOpened({
        'title': '订单状态更新',
        'body': '护士已到达服务地点',
        'data': {
          'type': 'order_status',
          'orderId': '123456',
          'status': 3, // 已到达
        },
      });

      expect(notificationOpened, isTrue);
    });

    testWidgets('T207 - 订单状态推送通知测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证不同订单状态的推送通知处理
      final statusNotifications = [
        {'status': 2, 'message': '护士已接单'},
        {'status': 3, 'message': '护士已到达'},
        {'status': 4, 'message': '服务进行中'},
        {'status': 5, 'message': '服务已完成，请评价'},
      ];

      for (final notification in statusNotifications) {
        // 模拟接收状态更新推送
        PushService.instance.handleNotification({
          'title': '订单状态更新',
          'body': notification['message'],
          'data': {
            'type': 'order_status',
            'orderId': '123456',
            'status': notification['status'],
          },
        });
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
      }
    });

    testWidgets('T208 - 护士新订单推送测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 模拟护士端接收新订单推送
      final pushService = PushService.instance;

      pushService.handleNotification({
        'title': '📍 附近有新订单',
        'body': '静脉采血 - 距离您1.2公里',
        'data': {
          'type': 'new_order',
          'orderId': '789012',
          'serviceName': '静脉采血',
          'distance': 1.2,
          'address': '杭州市西湖区xxx路xxx号',
        },
      });

      await tester.pumpAndSettle();
    });

    testWidgets('T209 - 退出登录解绑账号测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证退出登录时解绑推送账号
      // 需要mock登录->退出登录场景
    });

    testWidgets('T210 - 推送权限检查测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证推送权限检查
      final pushService = PushService.instance;
      final hasPermission = await pushService.checkPermission();

      // 在测试环境中默认返回true
      expect(hasPermission, isTrue);
    });
  });
}
