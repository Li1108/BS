import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/services/storage_service.dart';
import 'core/services/push_service.dart';

/// 应用程序入口
///
/// 互联网+护理服务APP - 上门护理服务系统
/// 技术栈: Flutter + Dart, MVVM架构, Riverpod状态管理
void main() async {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化Hive本地存储
  await Hive.initFlutter();

  // 初始化存储服务
  await StorageService.instance.init();

  // 初始化推送服务（阿里云移动推送）
  await PushService.instance.init();

  // 设置系统UI样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // 锁定竖屏方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 运行应用
  runApp(
    // Riverpod状态管理根组件
    const ProviderScope(child: NursingApp()),
  );
}
