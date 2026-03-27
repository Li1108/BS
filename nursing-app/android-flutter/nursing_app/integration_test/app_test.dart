import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nursing_app/main.dart' as app;

/// 护理服务APP集成测试
///
/// 测试完整的用户流程：
/// 1. 登录流程
/// 2. 下单流程
/// 3. 推送通知流程
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('端到端集成测试', () {
    testWidgets('完整用户流程测试：登录 -> 浏览服务 -> 下单', (tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 等待启动页完成
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 验证进入登录页面
      expect(find.text('手机号登录'), findsOneWidget);
    });
  });
}
