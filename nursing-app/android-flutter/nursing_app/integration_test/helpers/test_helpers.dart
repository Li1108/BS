import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 集成测试辅助工具类
class TestHelpers {
  TestHelpers._();

  /// 等待页面加载完成
  static Future<void> waitForPageLoad(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await tester.pumpAndSettle(timeout);
  }

  /// 查找并点击文本按钮
  static Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    if (finder.evaluate().isNotEmpty) {
      await tester.tap(finder.first);
      await tester.pumpAndSettle();
    }
  }

  /// 查找并输入文本
  static Future<void> enterTextByKey(
    WidgetTester tester,
    Key key,
    String text,
  ) async {
    final finder = find.byKey(key);
    if (finder.evaluate().isNotEmpty) {
      await tester.enterText(finder.first, text);
      await tester.pumpAndSettle();
    }
  }

  /// 滚动列表查找元素
  static Future<Finder> scrollUntilVisible(
    WidgetTester tester,
    Finder finder,
    Finder scrollable, {
    double delta = 300,
    int maxScrolls = 50,
  }) async {
    for (int i = 0; i < maxScrolls; i++) {
      if (finder.evaluate().isNotEmpty) {
        return finder;
      }
      await tester.drag(scrollable, Offset(0, -delta));
      await tester.pumpAndSettle();
    }
    return finder;
  }

  /// 验证SnackBar消息
  static void expectSnackBar(String message) {
    expect(find.text(message), findsOneWidget);
  }

  /// 验证对话框存在
  static void expectDialog() {
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  /// 关闭对话框
  static Future<void> dismissDialog(WidgetTester tester) async {
    final cancelButton = find.text('取消');
    if (cancelButton.evaluate().isNotEmpty) {
      await tester.tap(cancelButton.first);
      await tester.pumpAndSettle();
    }
  }

  /// 截图（用于调试）
  static Future<void> takeScreenshot(WidgetTester tester, String name) async {
    // 在实际测试中可以保存截图
    await tester.pumpAndSettle();
  }
}

/// 测试用户数据
class TestUserData {
  static const String testPhone = '13800138000';
  static const String testCode = '123456';
  static const String testName = '测试用户';
  static const String testAddress = '杭州市西湖区测试路1号';
  static const String testNursePhone = '13900139000';
  static const String testNurseName = '测试护士';
  static const String testIdCard = '330100199001011234';
}

/// 测试订单数据
class TestOrderData {
  static const String testOrderNo = 'ORD202601240001';
  static const String testServiceName = '静脉采血';
  static const double testServicePrice = 50.0;
  static const double testPlatformFeeRate = 0.20;
}
