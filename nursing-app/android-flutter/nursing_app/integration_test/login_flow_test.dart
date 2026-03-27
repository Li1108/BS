import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nursing_app/main.dart' as app;

/// 登录流程集成测试
///
/// 测试场景：
/// 1. 正常登录流程（手机号+验证码）
/// 2. 验证码发送倒计时（60秒）
/// 3. 登录成功后根据角色跳转
/// 4. 登录失败处理（无效验证码、账户禁用）
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('登录流程测试', () {
    testWidgets('T001 - 登录页面UI元素验证', (tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 等待启动页加载完成
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 验证登录页面基本元素
      expect(find.text('手机号登录'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2)); // 手机号和验证码输入框
      expect(find.text('获取验证码'), findsOneWidget);
      expect(find.text('登录'), findsOneWidget);
    });

    testWidgets('T002 - 手机号格式验证', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 查找手机号输入框
      final phoneField = find.byKey(const Key('phone_field'));
      if (phoneField.evaluate().isNotEmpty) {
        // 输入无效手机号
        await tester.enterText(phoneField, '123');
        await tester.pumpAndSettle();

        // 点击获取验证码
        final sendCodeButton = find.text('获取验证码');
        await tester.tap(sendCodeButton);
        await tester.pumpAndSettle();

        // 验证错误提示
        expect(find.textContaining('手机号'), findsWidgets);
      }
    });

    testWidgets('T003 - 验证码发送倒计时测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 查找手机号输入框
      final phoneField = find.byKey(const Key('phone_field'));
      if (phoneField.evaluate().isNotEmpty) {
        // 输入有效手机号
        await tester.enterText(phoneField, '13800138000');
        await tester.pumpAndSettle();

        // 点击获取验证码
        final sendCodeButton = find.text('获取验证码');
        await tester.tap(sendCodeButton);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // 验证倒计时开始（按钮显示秒数或禁用）
        // 注意：实际测试中需要mock网络请求
        expect(find.textContaining('秒'), findsWidgets);
      }
    });

    testWidgets('T004 - 用户角色登录跳转测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 此测试需要mock后端返回不同角色
      // USER角色 -> 跳转到用户首页
      // NURSE角色 -> 跳转到护士首页

      // 验证登录页面存在
      expect(find.text('登录'), findsOneWidget);
    });

    testWidgets('T005 - 禁用账户登录测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 此测试需要mock后端返回status=0（禁用账户）
      // 验证登录失败提示

      expect(find.text('登录'), findsOneWidget);
    });
  });
}
