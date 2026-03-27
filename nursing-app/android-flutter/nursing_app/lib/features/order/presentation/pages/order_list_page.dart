import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'orders_screen.dart';

/// 用户端订单页入口
///
/// 复用增强版订单页（真实数据 + 分页刷新 + 商业化视觉）。
@RoutePage()
class OrderListPage extends StatelessWidget {
  const OrderListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const OrdersScreenPage();
  }
}
