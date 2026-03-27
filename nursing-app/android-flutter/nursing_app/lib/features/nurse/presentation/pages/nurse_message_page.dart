import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../message/presentation/pages/message_center_page.dart';

/// 护士端消息中心页面
///
/// 与用户端消息中心复用同一套真实通知流与商业化交互：
/// - 骨架屏
/// - 筛选与未读态
/// - 失败重试引导
@RoutePage()
class NurseMessagePage extends StatelessWidget {
  const NurseMessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MessageCenterPage(nurseMode: true);
  }
}
