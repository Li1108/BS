import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/localization/app_localizations.dart';
import 'core/providers/app_settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// 护理服务APP主应用组件
///
/// 根据登录角色（USER或NURSE）区分首页显示
class NursingApp extends ConsumerStatefulWidget {
  const NursingApp({super.key});

  @override
  ConsumerState<NursingApp> createState() => _NursingAppState();
}

class _NursingAppState extends ConsumerState<NursingApp> {
  // AutoRouter 路由实例
  final _appRouter = AppRouter();

  @override
  Widget build(BuildContext context) {
    final appSettings = ref.watch(appSettingsProvider);

    return ScreenUtilInit(
      // 设计稿尺寸 (以iPhone 14为基准)
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: AppLocalizations(appSettings.locale).t('app.title'),
          debugShowCheckedModeBanner: false,

          // 主题配置
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appSettings.themeMode,

          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(appSettings.textScaleFactor),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },

          // AutoRouter 路由配置
          routerConfig: _appRouter.config(
            // 路由守卫 - 根据登录状态和角色导航
            navigatorObservers: () => [AuthRouteObserver(ref)],
          ),

          // 本地化配置
          locale: appSettings.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        );
      },
    );
  }
}

/// 路由观察者 - 用于监听路由变化和权限校验
class AuthRouteObserver extends NavigatorObserver {
  final WidgetRef ref;

  AuthRouteObserver(this.ref);
}
