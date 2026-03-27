import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/app_settings_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/contract_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/commercial_ui_widgets.dart';
import '../../data/models/nurse_profile_model.dart';
import '../../data/repositories/nurse_repository.dart';
import 'nurse_work_calendar_page.dart';
import '../../providers/nurse_provider.dart';

/// 护士端个人中心页面
@RoutePage()
class NurseProfilePage extends ConsumerStatefulWidget {
  const NurseProfilePage({super.key});

  @override
  ConsumerState<NurseProfilePage> createState() => _NurseProfilePageState();
}

class _NurseProfilePageState extends ConsumerState<NurseProfilePage> {
  bool _nurseAgreementSigned = false;
  String? _nurseAgreementSigner;
  DateTime? _nurseAgreementSignedAt;
  int? _agreementUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(nurseProfileProvider.notifier).loadProfile();
      _syncNurseAgreementStatus();
    });
  }

  void _resetAgreementStatus() {
    _nurseAgreementSigned = false;
    _nurseAgreementSigner = null;
    _nurseAgreementSignedAt = null;
  }

  void _loadNurseAgreementStatus({required int userId}) {
    _resetAgreementStatus();
    final data = ContractService.instance.getSignature(
      type: ContractType.nurseOnboarding,
      userId: userId,
    );
    if (data == null) {
      setState(() {});
      return;
    }
    final signed = data['signed'] == true;
    final signer = data['signer']?.toString().trim();
    final signedAtRaw = data['signedAt']?.toString();
    final signedAt = signedAtRaw == null
        ? null
        : DateTime.tryParse(signedAtRaw);

    final isValidSignature = signed && signedAt != null;
    setState(() {
      _nurseAgreementSigned = isValidSignature;
      _nurseAgreementSigner = (signer == null || signer.isEmpty)
          ? null
          : signer;
      _nurseAgreementSignedAt = signedAt;
    });
  }

  void _syncNurseAgreementStatus() {
    final authUserId = ref.read(authProvider).user?.id;
    final profileUserId = ref.read(nurseProfileProvider).profile?.userId;
    final userId = authUserId ?? profileUserId;

    if (userId == null) {
      if (_agreementUserId != null || _nurseAgreementSigned) {
        setState(() {
          _agreementUserId = null;
          _resetAgreementStatus();
        });
      }
      return;
    }

    if (_agreementUserId == userId) return;
    _agreementUserId = userId;
    _loadNurseAgreementStatus(userId: userId);
  }

  Future<void> _signNurseAgreement({
    required int userId,
    required String defaultSigner,
  }) async {
    final controller = TextEditingController(text: defaultSigner);
    final signed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('contract.nurse.title')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('协议要点：'),
              const SizedBox(height: 8),
              const Text('1. 通过审核后，护士应在接单前保持资质真实有效。'),
              const Text('2. 护士需在约定时间到达并按标准流程执行服务。'),
              const Text('3. 涉及用户隐私与医疗信息须严格保密。'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '签署人姓名',
                  hintText: '请输入真实姓名',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('确认签署'),
          ),
        ],
      ),
    );
    if (signed != true) return;

    final signer = controller.text.trim();
    await ContractService.instance.sign(
      type: ContractType.nurseOnboarding,
      userId: userId,
      signer: signer,
    );
    if (!mounted) return;
    setState(() {
      _nurseAgreementSigned = true;
      _nurseAgreementSigner = signer;
      _nurseAgreementSignedAt = DateTime.now();
    });
    _showFeatureTip('护士入职协议签署成功');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final profileState = ref.watch(nurseProfileProvider);
    final profile = profileState.profile;
    final nurseName = profile?.realName.isNotEmpty == true
        ? profile!.realName
        : (user?.username ?? '护士');
    final nursePhone = profile?.phone ?? user?.phone ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncNurseAgreementStatus();
    });

    bool hasParentTabs = false;
    try {
      AutoTabsRouter.of(context);
      hasParentTabs = true;
    } catch (_) {
      hasParentTabs = false;
    }

    return Scaffold(
      appBar: hasParentTabs
          ? null
          : AppBar(
              title: const Text('我的'),
              centerTitle: true,
              actions: [
                IconButton(
                  tooltip: '刷新',
                  onPressed: () =>
                      ref.read(nurseProfileProvider.notifier).loadProfile(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(nurseProfileProvider.notifier).loadProfile(),
        child: profileState.isLoading && profile == null
            ? ListView(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                children: [
                  SizedBox(height: 150.h),
                  SizedBox(
                    height: 220.h,
                    child: AppListSkeleton(
                      itemCount: 2,
                      itemHeight: 86,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              )
            : profileState.error != null && profile == null
            ? ListView(
                padding: EdgeInsets.fromLTRB(16.w, 24.h, 16.w, 24.h),
                children: [
                  AppRetryGuide(
                    title: '信息加载失败',
                    message: profileState.error!,
                    onRetry: () =>
                        ref.read(nurseProfileProvider.notifier).loadProfile(),
                  ),
                  SizedBox(height: 16.h),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await AppConfirmSheet.show(
                        context: context,
                        title: '确认退出登录',
                        message: '当前身份信息加载失败，是否退出并重新登录？',
                        confirmText: '退出登录',
                        cancelText: '取消',
                        icon: Icons.logout_rounded,
                      );
                      if (!confirm) return;
                      await ref.read(authProvider.notifier).logout();
                      if (!context.mounted) return;
                      context.router.replaceAll([const LoginRoute()]);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('退出登录'),
                  ),
                ],
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                children: [
                  _buildProfileHeader(
                    username: nurseName,
                    phone: nursePhone,
                    avatar: profile?.avatar ?? user?.avatar,
                    workMode: profile?.isWorkMode ?? false,
                    balance: profile?.balance ?? 0,
                    rating: profile?.rating ?? 5,
                  ),
                  if (profile != null) ...[
                    SizedBox(height: 12.h),
                    _buildAuditBanner(profile),
                    SizedBox(height: 12.h),
                    _buildOverviewPanel(profile),
                  ],
                  SizedBox(height: 12.h),
                  _buildQuickActions(),
                  if (profile?.isApproved == true) ...[
                    SizedBox(height: 12.h),
                    _buildOnboardingAgreementCard(
                      profile: profile,
                      userId: user?.id ?? profile!.userId,
                    ),
                  ],
                  SizedBox(height: 12.h),
                  _buildMenuSection(
                    context,
                    title: '执业管理',
                    items: [
                      _MenuItem(
                        icon: Icons.edit_outlined,
                        title: '编辑资料',
                        subtitle: '维护个人信息与执业资料',
                        onTap: () =>
                            context.router.push(NurseProfileEditRoute()),
                      ),
                      _MenuItem(
                        icon: Icons.verified_user_outlined,
                        title: '资质信息',
                        subtitle: '查看审核状态与资质照片',
                        onTap: () => _showQualificationDialog(profile),
                      ),
                      _MenuItem(
                        icon: Icons.location_on_outlined,
                        title: '医院变更',
                        subtitle: profile?.serviceArea?.isNotEmpty == true
                            ? '当前：${profile!.serviceArea!}'
                            : '暂未设置，点击去绑定',
                        onTap: () => _showServiceAreaDialog(profile),
                      ),
                      _MenuItem(
                        icon: Icons.calendar_month_outlined,
                        title: '工作日历',
                        subtitle: '设置可接单时段',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NurseWorkCalendarPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildMenuSection(
                    context,
                    title: '平台支持',
                    items: [
                      _MenuItem(
                        icon: Icons.star_outline,
                        title: '我的评价',
                        subtitle:
                            '当前评分 ${profile?.rating.toStringAsFixed(1) ?? '5.0'}',
                        onTap: () => _showEvaluationSummaryDialog(profile),
                      ),
                      _MenuItem(
                        icon: Icons.notifications_active_outlined,
                        title: '消息中心',
                        subtitle: '查看订单提醒和平台通知',
                        onTap: () => _switchToTab(2),
                      ),
                      _MenuItem(
                        icon: Icons.settings_outlined,
                        title: '偏好设置',
                        subtitle: '主题、语言与通知入口',
                        onTap: _showSettingsDialog,
                      ),
                      _MenuItem(
                        icon: Icons.help_outline,
                        title: '帮助中心',
                        subtitle: '联系客服与常见问题',
                        onTap: _showHelpCenterDialog,
                      ),
                      _MenuItem(
                        icon: Icons.info_outline,
                        title: '关于我们',
                        subtitle: '版本信息与服务说明',
                        onTap: _showAboutDialog,
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
                          message: '将使该账号在其他设备重新登录，当前护士端保持在线。',
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
                      onPressed: () async {
                        final confirm = await AppConfirmSheet.show(
                          context: context,
                          title: '确认退出登录',
                          message: '退出后将返回登录页。',
                          confirmText: '退出登录',
                          cancelText: '取消',
                          icon: Icons.logout_rounded,
                        );
                        if (!confirm || !context.mounted) return;
                        await ref.read(authProvider.notifier).logout();
                        if (!context.mounted) return;
                        context.router.replaceAll([const LoginRoute()]);
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
                    'Nursing Service App · 护士端',
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

  Widget _buildProfileHeader({
    required String username,
    required String phone,
    required String? avatar,
    required bool workMode,
    required double balance,
    required double rating,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 16.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30.r,
                backgroundColor: Colors.white,
                child: avatar != null && avatar.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          avatar,
                          width: 60.r,
                          height: 60.r,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.person,
                            size: 34.sp,
                            color: Colors.green,
                          ),
                        ),
                      )
                    : Icon(Icons.person, size: 34.sp, color: Colors.green),
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
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  workMode ? '接单中' : '休息中',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _buildMetric('账户余额', '¥${balance.toStringAsFixed(2)}'),
              _buildMetric('评分', rating.toStringAsFixed(1)),
              _buildMetric('身份', '认证护士'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditBanner(NurseProfileModel profile) {
    final status = profile.auditStatus;
    final color = Color(status.colorValue);
    final subtitle = switch (status) {
      AuditStatus.pending => '资料审核中，审核通过后可稳定接单',
      AuditStatus.approved => '资质审核通过，当前可正常接单服务',
      AuditStatus.rejected =>
        profile.auditReason?.isNotEmpty == true
            ? profile.auditReason!
            : '审核未通过，请完善资料后重试',
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, size: 18.sp, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '审核状态：${status.text}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewPanel(NurseProfileModel profile) {
    final area = profile.serviceArea?.trim();
    final locationText =
        (profile.locationLat != null && profile.locationLng != null)
        ? '已定位'
        : '未定位';

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
      child: Row(
        children: [
          Expanded(
            child: _buildOverviewItem(
              label: '服务区域',
              value: area?.isNotEmpty == true ? area! : '未设置',
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildOverviewItem(label: '定位状态', value: locationText),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildOverviewItem(
              label: '账户余额',
              value: '¥${profile.balance.toStringAsFixed(2)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewItem({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.sp, color: AppTheme.textSecondaryColor),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.sp,
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.assignment_outlined,
        label: '任务',
        onTap: () => _switchToTab(0),
      ),
      _QuickAction(
        icon: Icons.account_balance_wallet_outlined,
        label: '收入',
        onTap: () => _switchToTab(1),
      ),
      _QuickAction(
        icon: Icons.notifications_active_outlined,
        label: '消息',
        onTap: () => _switchToTab(2),
      ),
      _QuickAction(
        icon: Icons.settings_outlined,
        label: '设置',
        onTap: _showSettingsDialog,
      ),
    ];

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
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
              (action) => Expanded(
                child: InkWell(
                  onTap: action.onTap,
                  borderRadius: BorderRadius.circular(10.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Column(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            action.icon,
                            color: Colors.green,
                            size: 22.sp,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          action.label,
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
      margin: EdgeInsets.symmetric(horizontal: 16.w),
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
                  leading: Icon(item.icon, color: Colors.green),
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

  Widget _buildOnboardingAgreementCard({
    required NurseProfileModel? profile,
    required int userId,
  }) {
    final displayTime = _nurseAgreementSignedAt == null
        ? ''
        : '${_nurseAgreementSignedAt!.year}-${_nurseAgreementSignedAt!.month.toString().padLeft(2, '0')}-${_nurseAgreementSignedAt!.day.toString().padLeft(2, '0')} ${_nurseAgreementSignedAt!.hour.toString().padLeft(2, '0')}:${_nurseAgreementSignedAt!.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: Colors.green),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '护士入职协议',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_nurseAgreementSigned)
                const Chip(
                  label: Text('已签署'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            _nurseAgreementSigned
                ? '签署人：${_nurseAgreementSigner ?? profile?.realName ?? '-'}\n签署时间：$displayTime'
                : '审核已通过，请先签署入职服务协议后再稳定接单。',
            style: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _nurseAgreementSigned
                  ? null
                  : () => _signNurseAgreement(
                      userId: userId,
                      defaultSigner: profile?.realName.isNotEmpty == true
                          ? profile!.realName
                          : '护士',
                    ),
              icon: const Icon(Icons.draw_outlined),
              label: Text(_nurseAgreementSigned ? '已完成签署' : '签署入职协议'),
            ),
          ),
        ],
      ),
    );
  }

  void _switchToTab(int index) {
    try {
      final tabsRouter = AutoTabsRouter.of(context);
      tabsRouter.setActiveIndex(index);
      return;
    } catch (_) {
      // ignore and fallback to explicit route navigation
    }

    final target = switch (index) {
      0 => const NurseTaskRoute(),
      1 => const NurseIncomeRoute(),
      2 => const NurseMessageRoute(),
      _ => const NurseProfileRoute(),
    };
    context.router.navigate(NurseHomeRoute(children: [target]));
  }

  void _showFeatureTip(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _dialPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    _showFeatureTip('无法拨打电话，请检查设备权限');
  }

  void _showServiceAreaDialog(NurseProfileModel? profile) {
    final hospital = profile?.serviceArea?.trim();
    final hasHospital = hospital != null && hospital.isNotEmpty;
    final locationText =
        (profile?.locationLat != null && profile?.locationLng != null)
        ? '${profile!.locationLat}, ${profile.locationLng}'
        : '暂无定位信息';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('关联医院详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前关联医院：${hasHospital ? hospital : '暂未设置'}'),
            SizedBox(height: 8.h),
            Text('最近定位：$locationText'),
            SizedBox(height: 8.h),
            Text(
              '如需更换关联医院，需提交申请并等待管理员审核通过后生效。',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();

              final hospitalController = TextEditingController(
                text: hasHospital ? hospital : '',
              );
              final reasonController = TextEditingController();
              final formKey = GlobalKey<FormState>();

              final submit = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(hasHospital ? '申请更换关联医院' : '设置关联医院'),
                  content: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: hospitalController,
                          maxLength: 50,
                          decoration: const InputDecoration(
                            labelText: '关联医院',
                            hintText: '请输入关联医院名称',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '关联医院不能为空';
                            }
                            return null;
                          },
                        ),
                        if (hasHospital)
                          TextFormField(
                            controller: reasonController,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: '申请说明（选填）',
                              hintText: '请输入更换原因，便于管理员审核',
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (formKey.currentState?.validate() != true) return;
                        Navigator.of(ctx).pop(true);
                      },
                      child: const Text('提交申请'),
                    ),
                  ],
                ),
              );

              if (submit != true) return;

              try {
                final ok = await ref
                    .read(nurseRepositoryProvider)
                    .applyHospitalChange(
                      newHospital: hospitalController.text.trim(),
                      reason: reasonController.text.trim(),
                    );
                if (!ok) {
                  _showFeatureTip('提交失败，请稍后重试');
                  return;
                }
                await ref.read(nurseProfileProvider.notifier).loadProfile();
                _showFeatureTip(hasHospital ? '医院变更申请已提交，等待管理员审核' : '关联医院已设置');
              } catch (e) {
                _showFeatureTip('提交失败: $e');
              }
            },
            child: Text(hasHospital ? '申请更换' : '立即设置'),
          ),
          if (hasHospital)
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: hospital));
                Navigator.of(dialogContext).pop();
                _showFeatureTip('关联医院已复制');
              },
              child: const Text('复制医院'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showEvaluationSummaryDialog(NurseProfileModel? profile) {
    final taskState = ref.read(nurseTaskListProvider);
    final total = taskState.tasks.length;
    final completed = taskState.tasks.where((e) => e.status >= 5).length;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('评价概览'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前评分：${profile?.rating.toStringAsFixed(1) ?? '5.0'} / 5.0'),
            SizedBox(height: 8.h),
            Text('今日任务：$total 单'),
            Text('已完成：$completed 单'),
            SizedBox(height: 8.h),
            Text(
              '后续将接入完整历史评价列表。',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showHelpCenterDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '帮助中心',
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 10.h),
              ListTile(
                leading: const Icon(Icons.support_agent),
                title: const Text('客服电话'),
                subtitle: const Text('400-800-8899（工作日 09:00-18:00）'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _dialPhone('4008008899');
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_outlined),
                title: const Text('客服微信'),
                subtitle: const Text('NursingServiceSupport'),
                onTap: () {
                  Clipboard.setData(
                    const ClipboardData(text: 'NursingServiceSupport'),
                  );
                  Navigator.of(sheetContext).pop();
                  _showFeatureTip('客服微信已复制');
                },
              ),
              ListTile(
                leading: const Icon(Icons.question_answer_outlined),
                title: const Text('常见问题'),
                subtitle: const Text('接单、提现、异常申诉'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showFeatureTip('常见问题文档正在整理中');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: '互联网+护理服务',
      applicationVersion: 'v1.0.0',
      applicationLegalese: 'Nursing Service App - Nurse Client',
      children: [
        Text('护士端用于接单、服务打卡、消息提醒与收入管理。', style: TextStyle(fontSize: 12.sp)),
      ],
    );
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final settings = ref.watch(appSettingsProvider);
          final notifier = ref.read(appSettingsProvider.notifier);

          String themeText(ThemeMode mode) {
            return switch (mode) {
              ThemeMode.system => context.tr('settings.theme.system'),
              ThemeMode.light => context.tr('settings.theme.light'),
              ThemeMode.dark => context.tr('settings.theme.dark'),
            };
          }

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 10.h),
                Text(
                  context.tr('settings.title'),
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                ListTile(
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('刷新个人资料'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    ref.read(nurseProfileProvider.notifier).loadProfile();
                    _showFeatureTip('资料已刷新');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: Text(context.tr('settings.theme')),
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
                  title: Text(context.tr('settings.language')),
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
                  title: Text(context.tr('settings.accessibility')),
                  subtitle: Text(context.tr('settings.accessibility.subtitle')),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('通知中心'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _switchToTab(2);
                  },
                ),
                SizedBox(height: 8.h),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showQualificationDialog(NurseProfileModel? profile) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('资质信息'),
        content: Text(
          profile == null
              ? '暂无资质信息，请稍后重试。'
              : '审核状态：${profile.auditStatus.text}\n'
                    '服务区域：${profile.serviceArea ?? '-'}\n'
                    '评分：${profile.rating.toStringAsFixed(1)}\n'
                    '${profile.auditReason?.isNotEmpty == true ? '审核备注：${profile.auditReason}' : '审核备注：无'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
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
