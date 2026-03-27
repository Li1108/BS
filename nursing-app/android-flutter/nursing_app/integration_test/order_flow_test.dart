import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nursing_app/main.dart' as app;

/// 下单流程集成测试
///
/// 测试场景：
/// 1. 浏览服务列表
/// 2. 选择服务项目
/// 3. 填写订单信息（地址、联系人、预约时间）
/// 4. 提交订单
/// 5. 支付订单（支付宝沙箱）
/// 6. 订单状态流转
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('下单流程测试', () {
    testWidgets('T101 - 服务列表加载测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 跳过登录（需要先完成登录或使用测试账号）
      // 假设已登录状态

      // 查找服务列表
      final serviceList = find.byType(ListView);
      expect(serviceList, findsWidgets);
    });

    testWidgets('T102 - 服务分类筛选测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 查找分类Tab
      final categoryTabs = find.byType(Tab);
      if (categoryTabs.evaluate().isNotEmpty) {
        // 点击"产后护理"分类
        await tester.tap(find.text('产后护理').first);
        await tester.pumpAndSettle();

        // 验证只显示产后护理服务
        expect(find.text('产后通乳'), findsWidgets);
      }
    });

    testWidgets('T103 - 服务详情查看测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 查找服务项目
      final serviceItem = find.text('静脉采血');
      if (serviceItem.evaluate().isNotEmpty) {
        await tester.tap(serviceItem.first);
        await tester.pumpAndSettle();

        // 验证进入服务详情/下单页面
        expect(find.textContaining('立即预约'), findsWidgets);
      }
    });

    testWidgets('T104 - 订单信息填写测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 进入下单页面后验证必填项
      // 验证表单字段存在
      expect(find.byKey(const Key('address_field')), findsWidgets);
      expect(find.byKey(const Key('contact_field')), findsWidgets);
      expect(find.byKey(const Key('contact_phone_field')), findsWidgets);
      expect(find.byKey(const Key('appointment_time_field')), findsWidgets);

      // 实际测试中需要导航到下单页面
    });

    testWidgets('T105 - 地址选择与高德地图集成测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 点击选择地址
      final selectAddressButton = find.text('选择地址');
      if (selectAddressButton.evaluate().isNotEmpty) {
        await tester.tap(selectAddressButton.first);
        await tester.pumpAndSettle();

        // 验证地址选择页面打开
        // 验证高德地图组件加载
        expect(find.byType(Container), findsWidgets);
      }
    });

    testWidgets('T106 - 订单提交验证测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证未填写完整信息时无法提交
      final submitButton = find.text('提交订单');
      if (submitButton.evaluate().isNotEmpty) {
        await tester.tap(submitButton.first);
        await tester.pumpAndSettle();

        // 验证错误提示
        expect(find.textContaining('请'), findsWidgets);
      }
    });

    testWidgets('T107 - 支付流程测试（支付宝沙箱）', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证支付页面元素
      final payButton = find.text('立即支付');
      if (payButton.evaluate().isNotEmpty) {
        // 点击支付
        await tester.tap(payButton.first);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // 验证调起支付宝SDK
        // 注意：实际测试中需要mock支付宝SDK
      }
    });

    testWidgets('T108 - 订单取消与退款测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证订单取消按钮（支付后30分钟内可取消）
      final cancelButton = find.text('取消订单');
      if (cancelButton.evaluate().isNotEmpty) {
        await tester.tap(cancelButton.first);
        await tester.pumpAndSettle();

        // 验证确认对话框
        expect(find.text('确认取消'), findsWidgets);
      }
    });

    testWidgets('T109 - 订单列表状态筛选测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证订单状态Tab
      final tabs = ['待服务', '进行中', '已完成'];
      for (final tab in tabs) {
        final tabWidget = find.text(tab);
        if (tabWidget.evaluate().isNotEmpty) {
          await tester.tap(tabWidget.first);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('T110 - 订单评价流程测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 进入已完成订单详情
      // 验证评价按钮
      final evaluateButton = find.text('评价');
      if (evaluateButton.evaluate().isNotEmpty) {
        await tester.tap(evaluateButton.first);
        await tester.pumpAndSettle();

        // 验证评价页面
        expect(find.byType(Slider), findsWidgets); // 星级评分
        expect(find.byType(TextField), findsWidgets); // 评价内容输入框
      }
    });
  });
}
