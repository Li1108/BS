import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/app_router.dart';

/// 启动页
///
/// 应用启动时显示，用于检查登录状态并导航到对应首页
@RoutePage()
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _readyToNavigate = false;
  bool _hasNavigated = false;
  ProviderSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _authSub?.close();
    super.dispose();
  }

  void _start() {
    _authSub?.close();
    _authSub = ref.listenManual<AuthState>(authProvider, (previous, next) {
      if (!mounted || _hasNavigated) return;
      if (!_readyToNavigate) return;
      if (next.isLoading) return;
      _navigate(next);
    });

    _delayAndMarkReady();
  }

  Future<void> _delayAndMarkReady() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || _hasNavigated) return;
    _readyToNavigate = true;
    final current = ref.read(authProvider);
    if (!current.isLoading) {
      _navigate(current);
    }
  }

  void _navigate(AuthState state) {
    if (_hasNavigated) return;

    if (state.isAuthenticated) {
      _hasNavigated = true;
      final role = state.role;
      if (role == UserRole.nurse) {
        context.router.replaceAll([const NurseHomeRoute()]);
      } else {
        context.router.replaceAll([const UserHomeRoute()]);
      }
      return;
    }

    _hasNavigated = true;
    context.router.replaceAll([const LoginRoute()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 120.w,
                height: 120.w,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.medical_services_outlined,
                  size: 60.sp,
                  color: Theme.of(context).primaryColor,
                ),
              ),

              SizedBox(height: 24.h),

              // 应用名称
              Text(
                '互联网+护理服务',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              SizedBox(height: 8.h),

              // 副标题
              Text(
                '专业上门护理，温暖到家',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),

              SizedBox(height: 60.h),

              // 加载指示器
              SizedBox(
                width: 40.w,
                height: 40.w,
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),

              SizedBox(height: 16.h),

              Text(
                '正在加载...',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
