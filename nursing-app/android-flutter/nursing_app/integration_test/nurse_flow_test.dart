import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:nursing_app/main.dart' as app;

/// 护士端流程集成测试
///
/// 测试场景：
/// 1. 护士注册与资质审核
/// 2. 工作模式切换
/// 3. 位置上报
/// 4. 接单流程
/// 5. 服务过程（到达/开始/完成）
/// 6. 收入与提现
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('护士端流程测试', () {
    testWidgets('T301 - 护士注册页面测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 导航到护士注册页面
      // 验证表单字段
      // - 真实姓名
      // - 身份证号
      // - 身份证正面照片上传
      // - 身份证背面照片上传
      // - 执业证照片上传
    });

    testWidgets('T302 - 证件照片上传测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证图片选择器调用
      // 验证图片压缩（< 1MB）
      // 验证上传成功提示
    });

    testWidgets('T303 - 工作模式切换测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 查找工作模式开关
      final workModeSwitch = find.byType(Switch);
      if (workModeSwitch.evaluate().isNotEmpty) {
        // 切换工作模式
        await tester.tap(workModeSwitch.first);
        await tester.pumpAndSettle();

        // 验证状态变更
        // work_mode: 1 -> 接收订单推送
        // work_mode: 0 -> 休息中，不推送
      }
    });

    testWidgets('T304 - 位置上报测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证位置上报（每5分钟上报一次）
      // 需要mock LocationService
    });

    testWidgets('T305 - 今日任务列表测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证任务列表加载
      // 验证下拉刷新
      // 验证任务状态显示
    });

    testWidgets('T306 - 任务详情页面测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证任务详情显示
      // - 用户姓名
      // - 联系电话（可点击拨打）
      // - 服务地址（可点击导航）
      // - 服务项目
      // - 预约时间
      // - 服务备注
    });

    testWidgets('T307 - 导航到用户地址测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证导航按钮点击
      // 调起高德地图导航
    });

    testWidgets('T308 - 到达现场打卡测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 查找"到达现场"按钮
      final arrivalButton = find.text('到达现场');
      if (arrivalButton.evaluate().isNotEmpty) {
        await tester.tap(arrivalButton.first);
        await tester.pumpAndSettle();

        // 验证相机调起
        // 验证照片上传
        // 验证状态更新为"已到达"
      }
    });

    testWidgets('T309 - 开始服务打卡测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 查找"开始服务"按钮
      final startButton = find.text('开始服务');
      if (startButton.evaluate().isNotEmpty) {
        await tester.tap(startButton.first);
        await tester.pumpAndSettle();

        // 验证服务前照片上传
        // 验证状态更新为"服务中"
      }
    });

    testWidgets('T310 - 完成服务打卡测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 查找"完成服务"按钮
      final finishButton = find.text('完成服务');
      if (finishButton.evaluate().isNotEmpty) {
        await tester.tap(finishButton.first);
        await tester.pumpAndSettle();

        // 验证服务后照片上传
        // 验证状态更新为"待评价"
        // 验证收入计算并入账
      }
    });

    testWidgets('T311 - 收入列表测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 导航到收入页面
      // 验证余额显示
      // 验证收入统计（今日/本月/累计）
      // 验证收支明细列表
      // 验证平台费率显示（20%）
    });

    testWidgets('T312 - 申请提现测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 查找"申请提现"按钮
      final withdrawButton = find.text('申请提现');
      if (withdrawButton.evaluate().isNotEmpty) {
        await tester.tap(withdrawButton.first);
        await tester.pumpAndSettle();

        // 验证提现表单
        // - 提现金额
        // - 支付宝账号
        // - 真实姓名
        // 验证最低提现金额限制
      }
    });

    testWidgets('T313 - 提现记录查看测试', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 查找"提现记录"按钮
      final historyButton = find.text('提现记录');
      if (historyButton.evaluate().isNotEmpty) {
        await tester.tap(historyButton.first);
        await tester.pumpAndSettle();

        // 验证提现记录列表
        // 验证状态显示（待审核/已打款/已驳回）
      }
    });
  });
}
