import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/commercial_ui_widgets.dart';
import '../../../order/presentation/pages/evaluation_history_page.dart';
import '../../../user/providers/user_profile_provider.dart';

/// 用户端“我的”页面
@RoutePage()
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  DateTime? _lastAutoRefreshAt;
  bool _autoRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userProfileProvider.notifier).loadProfile();
    });
  }

  Future<void> _refreshProfile() async {
    await ref.read(userProfileProvider.notifier).loadProfile();
    _lastAutoRefreshAt = DateTime.now();
  }

  Future<void> _tryAutoRefresh() async {
    if (_autoRefreshing) return;
    final current = ref.read(userProfileProvider);
    if (current.isLoading) return;

    final now = DateTime.now();
    final shouldRefresh =
        _lastAutoRefreshAt == null ||
        now.difference(_lastAutoRefreshAt!).inSeconds >= 20;
    if (!shouldRefresh) return;

    _autoRefreshing = true;
    try {
      await _refreshProfile();
    } finally {
      _autoRefreshing = false;
    }
  }

  String _maskIdCardNo(String? idCardNo) {
    final text = (idCardNo ?? '').trim();
    if (text.isEmpty) return '';
    if (text.length < 8) return text;
    final prefix = text.substring(0, 4);
    final suffix = text.substring(text.length - 4);
    return '$prefix${'*' * (text.length - 8)}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tryAutoRefresh();
    });

    final authState = ref.watch(authProvider);
    final userState = ref.watch(userProfileProvider);
    final user = authState.user;
    final profile = userState.profile;
    final isNurse = authState.role == UserRole.nurse;

    final displayName = (profile?.nickname?.trim().isNotEmpty == true
        ? profile!.nickname!.trim()
        : (user?.username ?? '用户'));
    final phone = profile?.phone ?? user?.phone ?? '';
    final avatar = profile?.avatarUrl ?? user?.avatar;
    final realName = profile?.realName?.trim();
    final idCardMasked = _maskIdCardNo(profile?.idCardNo);
    final emergencyName = profile?.emergencyContact?.trim();
    final emergencyPhone = profile?.emergencyPhone?.trim();
    final accountStatus = profile?.status == 0 ? '已停用' : '正常';

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _refreshProfile,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: userState.isLoading && profile == null
            ? ListView(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                children: [
                  SizedBox(height: 140.h),
                  SizedBox(
                    height: 220.h,
                    child: const AppListSkeleton(itemCount: 2, itemHeight: 96),
                  ),
                ],
              )
            : userState.error != null && profile == null
            ? ListView(
                children: [
                  SizedBox(height: 120.h),
                  AppRetryGuide(
                    title: '资料加载失败',
                    message: userState.error!,
                    onRetry: _refreshProfile,
                  ),
                ],
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                children: [
                  _buildProfileHeader(
                    context,
                    username: displayName,
                    phone: phone,
                    avatar: avatar,
                    accountType: isNurse ? '护士账号' : '普通用户',
                  ),
                  SizedBox(height: 12.h),
                  _buildOverviewCard(
                    realName: realName,
                    idCardMasked: idCardMasked,
                    emergencyName: emergencyName,
                    emergencyPhone: emergencyPhone,
                    accountStatus: accountStatus,
                  ),
                  SizedBox(height: 12.h),
                  _buildQuickActions(context, isNurse),
                  SizedBox(height: 12.h),
                  _buildMenuSection(
                    context,
                    title: '账户与服务',
                    items: [
                      _MenuItem(
                        icon: Icons.edit_outlined,
                        title: '编辑资料',
                        subtitle: '昵称、性别、紧急联系人等',
                        onTap: () async {
                          await context.router.push(ProfileEditRoute());
                          if (!mounted) return;
                          await _refreshProfile();
                        },
                      ),
                      _MenuItem(
                        icon: Icons.receipt_long_outlined,
                        title: '我的订单',
                        subtitle: '查看进行中和历史订单',
                        onTap: () => _switchToTab(context, 1),
                      ),
                      _MenuItem(
                        icon: Icons.reviews_outlined,
                        title: '我的评价',
                        subtitle: '回顾历史评价与追评记录',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EvaluationHistoryPage(),
                          ),
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.location_on_outlined,
                        title: '地址管理',
                        subtitle: '管理常用服务地址',
                        onTap: () => context.router.push(AddressListRoute()),
                      ),
                      if (!isNurse)
                        _MenuItem(
                          icon: Icons.health_and_safety_outlined,
                          title: '申请成为护士',
                          subtitle: '提交资料并等待审核',
                          onTap: () =>
                              context.router.push(NurseRegisterRoute()),
                        ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildMenuSection(
                    context,
                    title: '系统与支持',
                    items: [
                      _MenuItem(
                        icon: Icons.notifications_outlined,
                        title: '消息中心',
                        subtitle: '订单提醒与平台通知',
                        onTap: () => _switchToTab(context, 2),
                      ),
                      _MenuItem(
                        icon: Icons.settings_suggest_outlined,
                        title: '偏好设置',
                        subtitle: '主题、语言、老年友好模式',
                        onTap: () => _showSettingsSheet(context, ref),
                      ),
                      _MenuItem(
                        icon: Icons.help_outline,
                        title: '帮助中心',
                        subtitle: '常见问题与客服支持',
                        onTap: () => _showFeatureTip(context, '帮助中心即将上线'),
                      ),
                      _MenuItem(
                        icon: Icons.info_outline,
                        title: '关于我们',
                        subtitle: '版本信息与平台介绍',
                        onTap: () =>
                            _showFeatureTip(context, '互联网+护理服务 APP v1.0.0'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await AppConfirmSheet.show(
                          context: context,
                          title: '退出其他设备',
                          message: '将使该账号在其他手机或平板重新登录，当前设备保持在线。',
                          confirmText: '确认执行',
                          cancelText: '取消',
                          icon: Icons.phonelink_erase_outlined,
                        );
                        if (!confirm || !context.mounted) return;

                        final ok = await ref
                            .read(authProvider.notifier)
                            .logoutOtherDevices();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? '已退出其他设备' : '操作失败，请稍后重试'),
                            backgroundColor: ok ? Colors.green : Colors.red,
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade300),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      icon: const Icon(Icons.phonelink_erase_outlined),
                      label: const Text('退出其他设备'),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('确认退出'),
                            content: const Text('确定要退出登录吗？'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.of(dialogContext).pop();
                                  await ref
                                      .read(authProvider.notifier)
                                      .logout();
                                  if (!context.mounted) return;
                                  context.router.replaceAll([
                                    const LoginRoute(),
                                  ]);
                                },
                                child: const Text(
                                  '退出',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                      ),
                      child: const Text('退出登录'),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Nursing Service App · 让护理到家更简单',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.textHintColor,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context, {
    required String username,
    required String phone,
    required String? avatar,
    required String accountType,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 16.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30.r,
            backgroundColor: Colors.white,
            child: avatar != null && avatar.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      avatar,
                      fit: BoxFit.cover,
                      width: 60.r,
                      height: 60.r,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        size: 34.sp,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  )
                : Icon(Icons.person, size: 34.sp, color: AppTheme.primaryColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  phone,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Text(
              accountType,
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard({
    required String? realName,
    required String idCardMasked,
    required String? emergencyName,
    required String? emergencyPhone,
    required String accountStatus,
  }) {
    final realNameDisplay = realName?.isNotEmpty == true ? realName! : '未设置';
    final realNameInfo = idCardMasked.isNotEmpty
        ? '$realNameDisplay（$idCardMasked）'
        : realNameDisplay;

    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow('实名信息', realNameInfo),
          SizedBox(height: 8.h),
          _buildInfoRow(
            '紧急联系人',
            emergencyName?.isNotEmpty == true
                ? '$emergencyName ${emergencyPhone ?? ''}'.trim()
                : '未设置',
          ),
          SizedBox(height: 8.h),
          _buildInfoRow('账户状态', accountStatus),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13.sp, color: AppTheme.textSecondaryColor),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.sp,
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isNurse) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.receipt_long,
        label: '订单',
        onTap: () => _switchToTab(context, 1),
      ),
      _QuickAction(
        icon: Icons.notifications_active_outlined,
        label: '消息',
        onTap: () => _switchToTab(context, 2),
      ),
      _QuickAction(
        icon: Icons.location_on_outlined,
        label: '地址',
        onTap: () => context.router.push(AddressListRoute()),
      ),
      _QuickAction(
        icon: isNurse ? Icons.badge_outlined : Icons.verified_user_outlined,
        label: isNurse ? '护士身份' : '护士认证',
        onTap: () => isNurse
            ? _showFeatureTip(context, '您已是护士账号')
            : context.router.push(NurseRegisterRoute()),
      ),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: actions
            .map(
              (a) => Expanded(
                child: InkWell(
                  onTap: a.onTap,
                  borderRadius: BorderRadius.circular(10.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Column(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            a.icon,
                            color: AppTheme.primaryColor,
                            size: 22.sp,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          a.label,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.textPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context, {
    required String title,
    required List<_MenuItem> items,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4.w, bottom: 6.h),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...items.map((item) {
            final isLast = item == items.last;
            return Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 2.w),
                  leading: Icon(
                    item.icon,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: item.subtitle == null
                      ? null
                      : Text(
                          item.subtitle!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: item.onTap,
                ),
                if (!isLast) Divider(height: 1, indent: 54.w, endIndent: 8.w),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _switchToTab(BuildContext context, int index) {
    try {
      final tabsRouter = AutoTabsRouter.of(context);
      tabsRouter.setActiveIndex(index);
    } catch (_) {
      if (index == 1) {
        context.router.push(OrderListRoute());
      } else if (index == 2) {
        context.router.push(MessageCenterRoute());
      }
    }
  }

  void _showFeatureTip(BuildContext context, String content) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(content)));
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) {
        final settings = ref.watch(appSettingsProvider);
        final notifier = ref.read(appSettingsProvider.notifier);

        String themeText(ThemeMode mode) {
          return switch (mode) {
            ThemeMode.system => sheetContext.tr('settings.theme.system'),
            ThemeMode.light => sheetContext.tr('settings.theme.light'),
            ThemeMode.dark => sheetContext.tr('settings.theme.dark'),
          };
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(sheetContext.tr('settings.title')),
                  subtitle: Text(
                    '${sheetContext.tr('settings.theme')}: ${themeText(settings.themeMode)}',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(sheetContext.tr('settings.theme')),
                  subtitle: Text(themeText(settings.themeMode)),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    underline: const SizedBox.shrink(),
                    onChanged: (value) {
                      if (value != null) {
                        notifier.setThemeMode(value);
                      }
                    },
                    items: ThemeMode.values
                        .map(
                          (mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(themeText(mode)),
                          ),
                        )
                        .toList(),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(sheetContext.tr('settings.language')),
                  trailing: DropdownButton<Locale>(
                    value: settings.locale,
                    underline: const SizedBox.shrink(),
                    onChanged: (value) {
                      if (value != null) {
                        notifier.setLocale(value);
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: Locale('zh', 'CN'),
                        child: Text('简体中文'),
                      ),
                      DropdownMenuItem(
                        value: Locale('en', 'US'),
                        child: Text('English'),
                      ),
                    ],
                  ),
                ),
                SwitchListTile.adaptive(
                  value: settings.seniorMode,
                  onChanged: notifier.setSeniorMode,
                  title: Text(sheetContext.tr('settings.accessibility')),
                  subtitle: Text(
                    sheetContext.tr('settings.accessibility.subtitle'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}

class _QuickAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  _QuickAction({required this.icon, required this.label, required this.onTap});
}
