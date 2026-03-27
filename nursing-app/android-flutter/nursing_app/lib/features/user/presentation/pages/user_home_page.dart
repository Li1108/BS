import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../../message/providers/notification_provider.dart';

/// 用户端首页
///
/// 底部导航栏包含：服务列表、我的订单、消息中心、个人中心
@RoutePage()
class UserHomePage extends ConsumerStatefulWidget {
  const UserHomePage({super.key});

  @override
  ConsumerState<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends ConsumerState<UserHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(notificationListProvider.notifier)
          .loadNotifications(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return AutoTabsScaffold(
      routes: [
        ServiceListRoute(),
        OrderListRoute(),
        MessageCenterRoute(),
        ProfileRoute(),
      ],
      bottomNavigationBuilder: (context, tabsRouter) {
        return BottomNavigationBar(
          currentIndex: tabsRouter.activeIndex,
          onTap: tabsRouter.setActiveIndex,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.medical_services_outlined),
              activeIcon: Icon(Icons.medical_services),
              label: '服务',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: '订单',
            ),
            BottomNavigationBarItem(
              icon: _buildMessageIcon(unreadCount, false),
              activeIcon: _buildMessageIcon(unreadCount, true),
              label: '消息',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageIcon(int unreadCount, bool active) {
    final baseIcon = Icon(
      active ? Icons.notifications : Icons.notifications_outlined,
    );
    if (unreadCount <= 0) return baseIcon;

    final badgeText = unreadCount > 99 ? '99+' : unreadCount.toString();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        baseIcon,
        Positioned(
          right: -8,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              badgeText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
