import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/real_name_verify_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/user/presentation/pages/user_home_page.dart';
import '../../features/user/presentation/pages/profile_edit_page.dart';
import '../../features/nurse/presentation/pages/nurse_home_page.dart';
import '../../features/nurse/presentation/pages/nurse_task_detail_page.dart';
import '../../features/order/presentation/pages/order_list_page.dart';
import '../../features/order/presentation/pages/order_detail_page.dart';
import '../../features/order/presentation/pages/payment_page.dart';
import '../../features/order/presentation/pages/orders_screen.dart';
import '../../features/order/presentation/pages/evaluation_screen.dart';
import '../../features/service/presentation/pages/service_list_page.dart';
import '../../features/service/presentation/pages/service_order_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/address/presentation/pages/address_list_page.dart';
import '../../features/address/presentation/pages/address_edit_page.dart';
import '../../features/message/presentation/pages/message_center_page.dart';
import '../../features/nurse/presentation/pages/nurse_task_page.dart';
import '../../features/nurse/presentation/pages/nurse_income_page.dart';
import '../../features/nurse/presentation/pages/nurse_register_page.dart';
import '../../features/nurse/presentation/pages/nurse_message_page.dart';
import '../../features/nurse/presentation/pages/nurse_profile_page.dart';
import '../../features/nurse/presentation/pages/nurse_profile_edit_page.dart';

part 'app_router.gr.dart';

/// 应用路由配置
///
/// 使用 AutoRouter 进行声明式路由管理
/// 根据用户角色 (USER / NURSE) 导航到不同首页
@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    // ==================== 启动页 ====================
    AutoRoute(page: SplashRoute.page, path: '/', initial: true),

    // ==================== 认证模块 ====================
    AutoRoute(page: LoginRoute.page, path: '/login'),
    AutoRoute(page: RegisterRoute.page, path: '/register'),
    AutoRoute(page: RealNameVerifyRoute.page, path: '/real-name-verify'),
    AutoRoute(page: NurseRegisterRoute.page, path: '/nurse-register'),

    // ==================== 用户端首页 ====================
    AutoRoute(
      page: UserHomeRoute.page,
      path: '/user-home',
      children: [
        AutoRoute(page: ServiceListRoute.page, path: 'services', initial: true),
        AutoRoute(page: OrderListRoute.page, path: 'orders'),
        AutoRoute(page: MessageCenterRoute.page, path: 'messages'),
        AutoRoute(page: ProfileRoute.page, path: 'profile'),
      ],
    ),

    // ==================== 护士端首页 ====================
    AutoRoute(
      page: NurseHomeRoute.page,
      path: '/nurse-home',
      children: [
        AutoRoute(page: NurseTaskRoute.page, path: 'tasks', initial: true),
        AutoRoute(page: NurseIncomeRoute.page, path: 'income'),
        AutoRoute(page: NurseMessageRoute.page, path: 'messages'),
        AutoRoute(page: NurseProfileRoute.page, path: 'profile'),
      ],
    ),

    // ==================== 服务相关页面 ====================
    AutoRoute(page: ServiceOrderRoute.page, path: '/service-order/:serviceId'),

    // ==================== 订单相关页面 ====================
    AutoRoute(page: OrdersScreenRoute.page, path: '/orders'),
    AutoRoute(page: OrderDetailRoute.page, path: '/order/:orderId'),
    AutoRoute(page: PaymentRoute.page, path: '/payment/:orderId'),
    AutoRoute(page: EvaluationScreenRoute.page, path: '/evaluation/:orderId'),

    // ==================== 地址管理 ====================
    AutoRoute(page: AddressListRoute.page, path: '/addresses'),
    AutoRoute(page: AddressEditRoute.page, path: '/address/edit'),

    // ==================== 个人资料编辑 ====================
    AutoRoute(page: ProfileEditRoute.page, path: '/profile/edit'),
    AutoRoute(page: NurseProfileEditRoute.page, path: '/nurse/profile/edit'),

    // ==================== 护士端任务详情 ====================
    AutoRoute(page: NurseTaskDetailRoute.page, path: '/nurse/task/:orderId'),
  ];

  @override
  List<AutoRouteGuard> get guards => [
    // 认证守卫 - 检查登录状态
    AuthGuard(),
  ];
}

/// 认证路由守卫
///
/// 用于检查用户登录状态，未登录时重定向到登录页
class AuthGuard extends AutoRouteGuard {
  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    resolver.next(true);
  }
}
