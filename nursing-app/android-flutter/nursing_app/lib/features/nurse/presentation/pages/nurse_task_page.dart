import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/widgets/commercial_ui_widgets.dart';
import '../../data/models/nurse_profile_model.dart';
import '../../data/repositories/nurse_repository.dart';
import '../../providers/nurse_provider.dart';

/// 护士今日任务页面
///
/// 展示护士已接订单列表
/// 支持服务过程状态更新（到达/开始/完成）和照片上传
@RoutePage()
class NurseTaskPage extends ConsumerStatefulWidget {
  const NurseTaskPage({super.key});

  @override
  ConsumerState<NurseTaskPage> createState() => _NurseTaskPageState();
}

enum NurseTaskViewMode { today, accepted, completed }

class _NurseTaskPageState extends ConsumerState<NurseTaskPage>
    with WidgetsBindingObserver {
  final RefreshController _refreshController = RefreshController();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _sosReasonController = TextEditingController();
  NurseTaskViewMode _taskMode = NurseTaskViewMode.today;
  Timer? _autoRefreshTimer;

  static const Duration _autoRefreshInterval = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 加载任务列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasksByCurrentMode();
      _startAutoRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTasksByCurrentMode();
      _startAutoRefresh();
    } else if (state == AppLifecycleState.paused) {
      _autoRefreshTimer?.cancel();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (!mounted) return;
      ref
          .read(nurseTaskListProvider.notifier)
          .refresh(status: _statusFilterForMode());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _sosReasonController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  /// 下拉刷新
  Future<void> _onRefresh() async {
    await ref
        .read(nurseTaskListProvider.notifier)
        .refresh(status: _statusFilterForMode());
    _refreshController.refreshCompleted();
  }

  Future<void> _loadTasksByCurrentMode() async {
    await ref
        .read(nurseTaskListProvider.notifier)
        .loadTodayTasks(status: _statusFilterForMode());
  }

  int? _statusFilterForMode() {
    switch (_taskMode) {
      case NurseTaskViewMode.today:
        return null;
      case NurseTaskViewMode.accepted:
        return 2;
      case NurseTaskViewMode.completed:
        return 6;
    }
  }

  Future<void> _switchTaskMode(NurseTaskViewMode mode) async {
    if (_taskMode == mode) return;
    setState(() {
      _taskMode = mode;
    });
    await _loadTasksByCurrentMode();
  }

  /// 拨打电话
  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法拨打电话')));
      }
    }
  }

  /// 打开高德地图导航
  Future<void> _openNavigation(NurseTaskModel task) async {
    final address = task.address.trim();
    final latitude = task.latitude;
    final longitude = task.longitude;

    if (latitude != null && longitude != null) {
      final amapUri = Uri.parse(
        'amapuri://route/plan/?'
        'dlat=$latitude&dlon=$longitude'
        '&dname=${Uri.encodeComponent(address)}'
        '&dev=0&t=0',
      );
      if (await _tryLaunchExternal(amapUri)) return;

      final amapWebUri = Uri.parse(
        'https://uri.amap.com/navigation?to=$longitude,$latitude,${Uri.encodeComponent(address)}&mode=car&callnative=0',
      );
      if (await _tryLaunchExternal(amapWebUri)) return;

      final googleWebUri = Uri.parse(
        'https://maps.google.com/?q=$latitude,$longitude',
      );
      if (await _tryLaunchExternal(googleWebUri)) return;
    }

    // 坐标缺失或导航失败时，回退到地址搜索，保证“可用”。
    if (address.isNotEmpty) {
      final amapSearchUri = Uri.parse(
        'https://uri.amap.com/search?keyword=${Uri.encodeComponent(address)}',
      );
      if (await _tryLaunchExternal(amapSearchUri)) return;

      final googleSearchUri = Uri.parse(
        'https://maps.google.com/?q=${Uri.encodeComponent(address)}',
      );
      if (await _tryLaunchExternal(googleSearchUri)) return;
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开导航，请检查地图或浏览器应用')));
    }
  }

  Future<bool> _tryLaunchExternal(Uri uri) async {
    try {
      if (!await canLaunchUrl(uri)) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// 压缩图片
  Future<File?> _compressImage(File file) async {
    try {
      final filePath = file.path;
      final targetPath = path.join(
        path.dirname(filePath),
        '${path.basenameWithoutExtension(filePath)}_compressed.jpg',
      );

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1080,
        minHeight: 1080,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        return File(result.path);
      }
      return file;
    } catch (e) {
      debugPrint('图片压缩失败: $e');
      return file;
    }
  }

  /// 拍照或选择图片
  Future<File?> _pickPhoto() async {
    final permissionService = PermissionService.instance;

    // 弹窗选择来源
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('现场拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return null;
    if (!mounted) return null;

    // 检查相机权限
    if (source == ImageSource.camera) {
      final hasPermission = await permissionService.showCameraPermissionDialog(
        context,
      );
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('需要相机权限才能拍照')));
        }
        return null;
      }
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return null;

      // 压缩图片
      return await _compressImage(File(image.path));
    } catch (e) {
      debugPrint('选择图片失败: $e');
      return null;
    }
  }

  /// 更新订单状态（带照片上传）
  Future<void> _updateTaskStatus(NurseTaskModel task, int newStatus) async {
    String statusName;
    switch (newStatus) {
      case 3:
        statusName = '到达现场';
        break;
      case 4:
        statusName = '开始服务';
        break;
      case 5:
        statusName = '完成服务';
        break;
      default:
        return;
    }

    final confirm = await AppConfirmSheet.show(
      context: context,
      title: '确认$statusName',
      message: '将更新任务状态为“$statusName”，并提交现场照片。',
      confirmText: '确认提交',
      cancelText: '取消',
      icon: Icons.assignment_turned_in_outlined,
    );

    if (!confirm) return;

    // 选择照片
    final photo = await _pickPhoto();
    if (photo == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请上传照片后再提交')));
      }
      return;
    }

    // 显示加载提示
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在提交...'),
            ],
          ),
        ),
      );
    }

    try {
      // 上传照片并更新状态
      final success = await ref
          .read(nurseTaskListProvider.notifier)
          .uploadPhotoAndUpdateStatus(task.id, newStatus, photo);

      if (mounted) {
        // 关闭加载对话框
        Navigator.of(context).pop();

        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已更新为"$statusName"')));
        } else {
          final retry = await AppConfirmSheet.show(
            context: context,
            title: '更新失败',
            message: '状态更新未成功，请重试。',
            confirmText: '重试',
            cancelText: '稍后',
            icon: Icons.error_outline_rounded,
            iconBgColor: const Color(0x33F44336),
            iconColor: Colors.redAccent,
          );
          if (retry) {
            await _updateTaskStatus(task, newStatus);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        final retry = await AppConfirmSheet.show(
          context: context,
          title: '更新异常',
          message: '状态提交时发生异常，请重试。',
          confirmText: '重试',
          cancelText: '稍后',
          icon: Icons.error_outline_rounded,
          iconBgColor: const Color(0x33F44336),
          iconColor: Colors.redAccent,
        );
        if (retry) {
          await _updateTaskStatus(task, newStatus);
        }
      }
    }
  }

  /// 接单
  Future<void> _acceptTask(NurseTaskModel task) async {
    final confirm = await AppConfirmSheet.show(
      context: context,
      title: '确认接单',
      message: '确认接收该订单后，任务将进入待服务状态。',
      confirmText: '确认接单',
      cancelText: '取消',
      icon: Icons.assignment_turned_in_outlined,
    );
    if (!confirm) return;

    final success = await ref
        .read(nurseTaskListProvider.notifier)
        .acceptOrder(task.id);
    if (!mounted) return;

    if (success) {
      setState(() {
        _taskMode = NurseTaskViewMode.accepted;
      });
      await _loadTasksByCurrentMode();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('接单成功，已进入待服务')));
    } else {
      final retry = await AppConfirmSheet.show(
        context: context,
        title: '接单失败',
        message: '接单未成功，请稍后重试。',
        confirmText: '重试',
        cancelText: '稍后',
        icon: Icons.error_outline_rounded,
        iconBgColor: const Color(0x33F44336),
        iconColor: Colors.redAccent,
      );
      if (retry) {
        await _acceptTask(task);
      }
    }
  }

  /// 拒单
  Future<void> _rejectTask(NurseTaskModel task) async {
    final confirm = await AppConfirmSheet.show(
      context: context,
      title: '确认拒单',
      message: '拒单后该订单将回到待接单池，请确认。',
      confirmText: '确认拒单',
      cancelText: '取消',
      icon: Icons.cancel_outlined,
      iconBgColor: const Color(0x33F44336),
      iconColor: Colors.redAccent,
    );
    if (!confirm) return;

    final success = await ref
        .read(nurseTaskListProvider.notifier)
        .rejectOrder(task.id);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('拒单成功，订单已重新进入派单队列')));
    } else {
      final retry = await AppConfirmSheet.show(
        context: context,
        title: '拒单失败',
        message: '拒单未成功，请稍后重试。',
        confirmText: '重试',
        cancelText: '稍后',
        icon: Icons.error_outline_rounded,
        iconBgColor: const Color(0x33F44336),
        iconColor: Colors.redAccent,
      );
      if (retry) {
        await _rejectTask(task);
      }
    }
  }

  Future<void> _triggerSosForTask(NurseTaskModel task) async {
    _sosReasonController.clear();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('发起 SOS 求助'),
          content: TextField(
            controller: _sosReasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '请输入紧急情况描述（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确认发送'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    final success = await ref
        .read(nurseRepositoryProvider)
        .triggerSos(task.id, description: _sosReasonController.text.trim());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'SOS已发送，平台将尽快响应' : 'SOS发送失败，请稍后重试'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(nurseTaskListProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
            child: Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildModeButton(
                      title: '今日任务',
                      selected: _taskMode == NurseTaskViewMode.today,
                      onTap: () => _switchTaskMode(NurseTaskViewMode.today),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildModeButton(
                      title: '已接单',
                      selected: _taskMode == NurseTaskViewMode.accepted,
                      onTap: () => _switchTaskMode(NurseTaskViewMode.accepted),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildModeButton(
                      title: '已完成',
                      selected: _taskMode == NurseTaskViewMode.completed,
                      onTap: () => _switchTaskMode(NurseTaskViewMode.completed),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: taskState.isLoading
                ? AppListSkeleton(
                    itemCount: 5,
                    itemHeight: 196,
                    padding: EdgeInsets.all(16.w),
                  )
                : taskState.error != null && taskState.tasks.isEmpty
                ? SmartRefresher(
                    controller: _refreshController,
                    enablePullDown: true,
                    onRefresh: _onRefresh,
                    header: const WaterDropHeader(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(16.w),
                      children: [
                        AppRetryGuide(
                          title: '任务加载失败',
                          message: taskState.error!,
                          onRetry: _loadTasksByCurrentMode,
                        ),
                      ],
                    ),
                  )
                : taskState.tasks.isEmpty
                ? SmartRefresher(
                    controller: _refreshController,
                    enablePullDown: true,
                    onRefresh: _onRefresh,
                    header: const WaterDropHeader(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [_buildEmptyState()],
                    ),
                  )
                : SmartRefresher(
                    controller: _refreshController,
                    enablePullDown: true,
                    onRefresh: _onRefresh,
                    header: const WaterDropHeader(),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(16.w),
                      itemCount: taskState.tasks.length,
                      itemBuilder: (context, index) {
                        final task = taskState.tasks[index];
                        return _buildTaskCard(task);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? Theme.of(context).primaryColor
                : AppTheme.textSecondaryColor,
          ),
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    final emptyTitle = switch (_taskMode) {
      NurseTaskViewMode.today => '暂无任务',
      NurseTaskViewMode.accepted => '暂无已接订单',
      NurseTaskViewMode.completed => '暂无已完成订单',
    };

    final emptyHint = switch (_taskMode) {
      NurseTaskViewMode.today => '开启接单模式后可接收新订单',
      NurseTaskViewMode.accepted => '接单成功后会显示在这里',
      NurseTaskViewMode.completed => '完成订单后会显示在这里',
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64.sp,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            emptyTitle,
            style: TextStyle(
              fontSize: 18.sp,
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            emptyHint,
            style: TextStyle(fontSize: 14.sp, color: AppTheme.textHintColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(NurseTaskModel task) {
    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: InkWell(
        onTap: () {
          context.router.push(NurseTaskDetailRoute(orderId: task.id));
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTaskHeader(task),
              SizedBox(height: 12.h),
              _buildServiceInfo(task),
              SizedBox(height: 12.h),
              const Divider(height: 1),
              SizedBox(height: 12.h),
              _buildUserInfo(task),
              SizedBox(height: 8.h),
              _buildAddressInfo(task),
              SizedBox(height: 16.h),
              _buildActionButtons(task),
            ],
          ),
        ),
      ),
    );
  }

  /// 订单头部
  Widget _buildTaskHeader(NurseTaskModel task) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          task.orderNo,
          style: TextStyle(
            fontSize: 12.sp,
            color: AppTheme.textSecondaryColor,
            fontFamily: 'monospace',
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Color(task.statusColorValue).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            task.statusText,
            style: TextStyle(
              fontSize: 12.sp,
              color: Color(task.statusColorValue),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// 服务信息
  Widget _buildServiceInfo(NurseTaskModel task) {
    return Row(
      children: [
        Container(
          width: 56.w,
          height: 56.w,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            Icons.medical_services,
            size: 28.sp,
            color: Theme.of(context).primaryColor,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.serviceName,
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14.sp,
                    color: AppTheme.textHintColor,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    task.appointmentTime,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '预计收入',
              style: TextStyle(fontSize: 11.sp, color: AppTheme.textHintColor),
            ),
            SizedBox(height: 2.h),
            Text(
              '¥${task.nurseIncome.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 用户信息
  Widget _buildUserInfo(NurseTaskModel task) {
    return Row(
      children: [
        Icon(
          Icons.person_outline,
          size: 16.sp,
          color: AppTheme.textSecondaryColor,
        ),
        SizedBox(width: 4.w),
        Text(task.contactName, style: TextStyle(fontSize: 14.sp)),
        SizedBox(width: 16.w),
        GestureDetector(
          onTap: () => _makePhoneCall(task.contactPhone),
          child: Row(
            children: [
              Icon(
                Icons.phone_outlined,
                size: 16.sp,
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(width: 4.w),
              Text(
                task.contactPhone,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Theme.of(context).primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 地址信息
  Widget _buildAddressInfo(NurseTaskModel task) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 16.sp,
          color: AppTheme.textSecondaryColor,
        ),
        SizedBox(width: 4.w),
        Expanded(
          child: Text(
            task.address,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppTheme.textSecondaryColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 操作按钮
  Widget _buildActionButtons(NurseTaskModel task) {
    return Row(
      children: [
        // 导航按钮
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _openNavigation(task),
            icon: Icon(Icons.navigation_outlined, size: 18.sp),
            label: const Text('导航'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 10.h),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        // 状态更新按钮
        Expanded(
          flex: 2,
          child: task.canAccept && task.canReject
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rejectTask(task),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        child: Text(
                          '拒单',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(child: _buildStatusButton(task)),
                  ],
                )
              : task.canFinish
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _triggerSosForTask(task),
                        icon: Icon(Icons.sos, size: 16.sp, color: Colors.red),
                        label: const Text('SOS'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(child: _buildStatusButton(task)),
                  ],
                )
              : _buildStatusButton(task),
        ),
      ],
    );
  }

  /// 状态更新按钮
  Widget _buildStatusButton(NurseTaskModel task) {
    String buttonText;
    VoidCallback? onPressed;
    Color? buttonColor;

    if (task.canAccept) {
      // 状态1：待接单 -> 可以接单
      buttonText = '接单';
      buttonColor = Colors.teal;
      onPressed = () => _acceptTask(task);
    } else if (task.canArrived) {
      // 状态2：待服务 -> 可以点击到达
      buttonText = '📍 到达现场';
      buttonColor = Colors.purple;
      onPressed = () => _updateTaskStatus(task, 3);
    } else if (task.canStart) {
      // 状态3：已到达 -> 可以开始服务
      buttonText = '▶️ 开始服务';
      buttonColor = Colors.blue;
      onPressed = () => _updateTaskStatus(task, 4);
    } else if (task.canFinish) {
      // 状态4：服务中 -> 可以完成服务
      buttonText = '✅ 完成服务';
      buttonColor = Colors.green;
      onPressed = () => _updateTaskStatus(task, 5);
    } else {
      // 其他状态
      buttonText = task.statusText;
      buttonColor = Colors.grey;
      onPressed = null;
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonColor,
        disabledBackgroundColor: Colors.grey.shade200,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
      child: Text(
        buttonText,
        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
      ),
    );
  }
}
