import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../data/models/nurse_profile_model.dart';
import '../../data/repositories/nurse_repository.dart';
import '../../providers/nurse_provider.dart';

/// 护士端首页
///
/// 底部导航栏包含：今日任务、收入管理、消息中心、个人中心
/// 支持工作模式切换（接单/休息）
/// 定时位置上报（每10分钟，使用高德地图SDK）
@RoutePage()
class NurseHomePage extends ConsumerStatefulWidget {
  const NurseHomePage({super.key});

  @override
  ConsumerState<NurseHomePage> createState() => _NurseHomePageState();
}

class _NurseHomePageState extends ConsumerState<NurseHomePage>
    with WidgetsBindingObserver {
  bool _isWorkMode = true;
  bool _isTogglingWorkMode = false;

  // 位置上报定时器
  Timer? _locationReportTimer;
  static const Duration _locationReportInterval = Duration(minutes: 10);
  DateTime? _lastLocationReportTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNurseData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationReport();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用回到前台时检查是否需要重新上报位置
    if (state == AppLifecycleState.resumed && _isWorkMode) {
      _checkAndReportLocation();
    }
  }

  /// 初始化护士数据
  Future<void> _initNurseData() async {
    // 加载护士档案
    await ref.read(nurseProfileProvider.notifier).loadProfile();

    final profileState = ref.read(nurseProfileProvider);
    if (profileState.profile != null) {
      final bound = await _ensureHospitalBound(profileState.profile!);
      if (!bound || !mounted) {
        return;
      }

      setState(() {
        _isWorkMode = profileState.profile!.isWorkMode;
      });

      // 如果是工作模式，启动位置上报
      if (_isWorkMode) {
        _startLocationReport();
      }
    }

    // 加载今日任务
    ref.read(nurseTaskListProvider.notifier).loadTodayTasks();
  }

  Future<bool> _ensureHospitalBound(NurseProfileModel profile) async {
    final currentHospital = profile.serviceArea?.trim() ?? '';
    if (currentHospital.isNotEmpty) {
      return true;
    }

    while (mounted) {
      final formKey = GlobalKey<FormState>();
      final hospitalController = TextEditingController();

      if (!mounted) return false;

      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('完善关联医院'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: hospitalController,
                autofocus: true,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: '关联医院',
                  hintText: '请输入您当前关联医院',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '关联医院不能为空';
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('退出登录'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState?.validate() != true) return;
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('提交'),
              ),
            ],
          );
        },
      );

      if (result != true) {
        await ref.read(authProvider.notifier).logout();
        if (!mounted) return false;
        context.router.replaceAll([const LoginRoute()]);
        return false;
      }

      try {
        final ok = await ref
            .read(nurseRepositoryProvider)
            .applyHospitalChange(newHospital: hospitalController.text.trim());
        if (!ok) {
          _showSnackBar('关联医院提交失败，请重试');
          continue;
        }
        await ref.read(nurseProfileProvider.notifier).loadProfile();
        final latest = ref.read(nurseProfileProvider).profile;
        if ((latest?.serviceArea ?? '').trim().isNotEmpty) {
          _showSnackBar('关联医院已设置');
          return true;
        }
      } catch (e) {
        _showSnackBar('关联医院提交失败: $e');
      }
    }

    return false;
  }

  /// 启动位置上报
  Future<void> _startLocationReport() async {
    // 检查定位权限
    final permissionService = PermissionService.instance;
    final hasPermission = await permissionService.hasLocationPermission();

    if (!hasPermission) {
      if (!mounted) return;
      final granted = await permissionService.showLocationPermissionDialog(
        context,
      );
      if (!granted) {
        _showSnackBar('需要定位权限才能正常接单');
        return;
      }
    }

    // 初始化定位服务
    await LocationService.instance.init();

    // 立即上报一次
    await _reportLocation();

    // 启动定时上报
    _locationReportTimer?.cancel();
    _locationReportTimer = Timer.periodic(_locationReportInterval, (_) {
      _reportLocation();
    });

    debugPrint('位置上报已启动，间隔 ${_locationReportInterval.inMinutes} 分钟');
  }

  /// 停止位置上报
  void _stopLocationReport() {
    _locationReportTimer?.cancel();
    _locationReportTimer = null;
    debugPrint('位置上报已停止');
  }

  /// 检查并上报位置
  void _checkAndReportLocation() {
    if (_lastLocationReportTime == null) {
      _reportLocation();
      return;
    }

    final elapsed = DateTime.now().difference(_lastLocationReportTime!);
    if (elapsed >= _locationReportInterval) {
      _reportLocation();
    }
  }

  /// 上报当前位置
  Future<void> _reportLocation() async {
    try {
      final locationService = LocationService.instance;
      final hasPermission = await locationService.requestPermission();

      if (!hasPermission) {
        debugPrint('无定位权限，无法上报位置');
        return;
      }

      final location = await locationService.getCurrentLocation();

      if (location != null && location.isSuccess) {
        final success = await ref
            .read(nurseProfileProvider.notifier)
            .reportLocation(location.latitude, location.longitude);

        if (success) {
          _lastLocationReportTime = DateTime.now();
          debugPrint('位置上报成功: (${location.latitude}, ${location.longitude})');
        }
      }
    } catch (e) {
      debugPrint('位置上报失败: $e');
    }
  }

  /// 切换工作模式
  Future<void> _toggleWorkMode(bool value) async {
    if (_isTogglingWorkMode) return;

    setState(() => _isTogglingWorkMode = true);

    try {
      final success = await ref
          .read(nurseProfileProvider.notifier)
          .toggleWorkMode(value);

      if (success) {
        setState(() => _isWorkMode = value);

        if (value) {
          // 开启工作模式，启动位置上报
          _startLocationReport();
          _showSnackBar('已开启接单模式，系统将为您推送附近订单');
        } else {
          // 关闭工作模式，停止位置上报
          _stopLocationReport();
          _showSnackBar('已切换为休息模式，暂停接收新订单');
        }
      } else {
        _showSnackBar('切换失败，请稍后重试');
      }
    } catch (e) {
      _showSnackBar('切换失败: $e');
    } finally {
      setState(() => _isTogglingWorkMode = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 监听护士档案状态
    final profileState = ref.watch(nurseProfileProvider);

    return AutoTabsScaffold(
      routes: const [
        NurseTaskRoute(),
        NurseIncomeRoute(),
        NurseMessageRoute(),
        NurseProfileRoute(),
      ],
      appBarBuilder: (context, tabsRouter) {
        final titles = ['今日任务', '收入管理', '消息', '我的'];

        return AppBar(
          title: Text(titles[tabsRouter.activeIndex]),
          centerTitle: true,
          actions: _buildAppBarActions(tabsRouter.activeIndex, profileState),
        );
      },
      bottomNavigationBuilder: (context, tabsRouter) {
        return BottomNavigationBar(
          currentIndex: tabsRouter.activeIndex,
          onTap: tabsRouter.setActiveIndex,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: '今日任务',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet),
              label: '收入',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              activeIcon: Icon(Icons.notifications),
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

  /// 构建 AppBar Actions
  List<Widget>? _buildAppBarActions(
    int activeIndex,
    NurseProfileState profileState,
  ) {
    // 只在今日任务页面显示工作模式开关
    if (activeIndex != 0) return null;

    // 检查审核状态
    if (profileState.profile != null && !profileState.profile!.isApproved) {
      return [
        Padding(
          padding: EdgeInsets.only(right: 16.w),
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                profileState.profile!.auditStatus.text,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      Padding(
        padding: EdgeInsets.only(right: 16.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 工作状态指示器
            Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                color: _isWorkMode ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 6.w),
            Text(
              _isWorkMode ? '接单中' : '休息中',
              style: TextStyle(
                fontSize: 14.sp,
                color: _isWorkMode ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 8.w),
            // 工作模式开关
            _isTogglingWorkMode
                ? SizedBox(
                    width: 48.w,
                    height: 24.h,
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Switch(
                    value: _isWorkMode,
                    onChanged: _toggleWorkMode,
                    activeThumbColor: Colors.green,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
          ],
        ),
      ),
    ];
  }
}
