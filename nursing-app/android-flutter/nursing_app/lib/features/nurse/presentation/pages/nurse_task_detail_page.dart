import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/widgets/commercial_ui_widgets.dart';
import '../../data/models/nurse_profile_model.dart';
import '../../data/repositories/nurse_repository.dart';
import '../../providers/nurse_provider.dart';

/// 护士任务详情页面
///
/// 展示订单完整信息
/// 支持服务过程状态更新和照片上传
@RoutePage()
class NurseTaskDetailPage extends ConsumerStatefulWidget {
  final int orderId;

  const NurseTaskDetailPage({
    super.key,
    @PathParam('orderId') required this.orderId,
  });

  @override
  ConsumerState<NurseTaskDetailPage> createState() =>
      _NurseTaskDetailPageState();
}

class _NurseTaskDetailPageState extends ConsumerState<NurseTaskDetailPage> {
  NurseTaskModel? _task;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _loadError;
  bool _isLoadingFlow = false;
  List<Map<String, dynamic>> _statusLogs = const [];
  List<Map<String, dynamic>> _paymentRecords = const [];
  List<Map<String, dynamic>> _refundRecords = const [];
  List<Map<String, dynamic>> _sosRecords = const [];
  bool _progressDialogVisible = false;
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _sosReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTaskDetail();
  }

  @override
  void dispose() {
    _sosReasonController.dispose();
    super.dispose();
  }

  /// 加载任务详情
  Future<void> _loadTaskDetail() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _isLoadingFlow = true;
    });

    try {
      final repository = ref.read(nurseRepositoryProvider);
      final task = await repository.getTaskDetail(widget.orderId);
      Map<String, dynamic> flow = const {};
      try {
        flow = await repository.getTaskFlow(widget.orderId);
      } catch (_) {
        flow = const {};
      }
      if (!mounted) return;
      setState(() {
        _task = task;
        _statusLogs =
            ((flow['statusLogs'] ?? flow['status_logs']) as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [];
        _paymentRecords =
            ((flow['paymentRecords'] ?? flow['payment_records']) as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [];
        _refundRecords =
            ((flow['refundRecords'] ?? flow['refund_records']) as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [];
        _sosRecords =
            ((flow['sosRecords'] ?? flow['sos_records']) as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            const [];
        _isLoading = false;
        _isLoadingFlow = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingFlow = false;
        _task = null;
        _loadError = e.toString();
      });
    }
  }

  /// 拨打电话
  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// 打开导航
  Future<void> _openNavigation() async {
    if (_task == null) return;
    final address = _task!.address.trim();
    final latitude = _task!.latitude;
    final longitude = _task!.longitude;

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
      return file;
    }
  }

  /// 拍照
  Future<File?> _pickPhoto() async {
    final permissionService = PermissionService.instance;

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

      return await _compressImage(File(image.path));
    } catch (e) {
      return null;
    }
  }

  /// 更新订单状态
  Future<void> _updateStatus(int newStatus) async {
    if (_task == null || _isUpdating) return;

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

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('照片已选择，开始上传并更新状态...')));
    }

    setState(() => _isUpdating = true);
    _showProgressDialog('正在上传照片并更新状态...');

    try {
      final success = await ref
          .read(nurseTaskListProvider.notifier)
          .uploadPhotoAndUpdateStatus(_task!.id, newStatus, photo);
      if (!mounted) return;
      _hideProgressDialog();

      if (success) {
        // 重新加载详情
        await _loadTaskDetail();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已更新为"$statusName"')));
        }
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
          await _updateStatus(newStatus);
        }
      }
    } catch (e) {
      if (mounted) {
        _hideProgressDialog();
        final retry = await AppConfirmSheet.show(
          context: context,
          title: '更新异常',
          message: '状态提交异常，请检查网络后重试。',
          confirmText: '重试',
          cancelText: '稍后',
          icon: Icons.error_outline_rounded,
          iconBgColor: const Color(0x33F44336),
          iconColor: Colors.redAccent,
        );
        if (retry) {
          await _updateStatus(newStatus);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _triggerSos() async {
    if (_task == null || _isUpdating) return;

    final confirm = await AppConfirmSheet.show(
      context: context,
      title: '确认发起SOS',
      message: '将向平台发送紧急求助信息，请确认当前为紧急情况。',
      confirmText: '立即求助',
      cancelText: '取消',
      icon: Icons.sos,
      iconBgColor: const Color(0x33F44336),
      iconColor: Colors.redAccent,
    );
    if (!confirm) return;

    setState(() => _isUpdating = true);
    try {
      final success = await ref
          .read(nurseRepositoryProvider)
          .triggerSos(_task!.id, description: _sosReasonController.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'SOS已发送，平台将尽快联系您' : 'SOS发送失败，请重试'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) {
        _sosReasonController.clear();
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  /// 接单
  Future<void> _acceptOrder() async {
    if (_task == null || _isUpdating) return;

    final confirm = await AppConfirmSheet.show(
      context: context,
      title: '确认接单',
      message: '确认接收该订单后，任务将进入待服务状态。',
      confirmText: '确认接单',
      cancelText: '取消',
      icon: Icons.assignment_turned_in_outlined,
    );
    if (!confirm) return;

    setState(() => _isUpdating = true);
    _showProgressDialog('正在提交接单...');
    try {
      final success = await ref
          .read(nurseTaskListProvider.notifier)
          .acceptOrder(_task!.id);
      if (!mounted) return;
      _hideProgressDialog();

      if (success) {
        await _loadTaskDetail();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('接单成功，已进入待服务')));
        }
      } else {
        final retry = await AppConfirmSheet.show(
          context: context,
          title: '接单失败',
          message: '接单未成功，请重试。',
          confirmText: '重试',
          cancelText: '稍后',
          icon: Icons.error_outline_rounded,
          iconBgColor: const Color(0x33F44336),
          iconColor: Colors.redAccent,
        );
        if (retry) {
          await _acceptOrder();
        }
      }
    } catch (_) {
      if (mounted) {
        _hideProgressDialog();
        final retry = await AppConfirmSheet.show(
          context: context,
          title: '接单异常',
          message: '接单时发生异常，请重试。',
          confirmText: '重试',
          cancelText: '稍后',
          icon: Icons.error_outline_rounded,
          iconBgColor: const Color(0x33F44336),
          iconColor: Colors.redAccent,
        );
        if (retry) {
          await _acceptOrder();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  /// 拒单
  Future<void> _rejectOrder() async {
    if (_task == null || _isUpdating) return;

    final confirm = await AppConfirmSheet.show(
      context: context,
      title: '确认拒单',
      message: '拒单后该订单将重新进入待接单池，请确认。',
      confirmText: '确认拒单',
      cancelText: '取消',
      icon: Icons.cancel_outlined,
      iconBgColor: const Color(0x33F44336),
      iconColor: Colors.redAccent,
    );
    if (!confirm) return;

    setState(() => _isUpdating = true);
    _showProgressDialog('正在提交拒单...');
    try {
      final success = await ref
          .read(nurseTaskListProvider.notifier)
          .rejectOrder(_task!.id);
      if (!mounted) return;
      _hideProgressDialog();

      if (success) {
        await _loadTaskDetail();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('拒单成功，订单已回到待接单队列')));
        }
      } else {
        final retry = await AppConfirmSheet.show(
          context: context,
          title: '拒单失败',
          message: '拒单未成功，请重试。',
          confirmText: '重试',
          cancelText: '稍后',
          icon: Icons.error_outline_rounded,
          iconBgColor: const Color(0x33F44336),
          iconColor: Colors.redAccent,
        );
        if (retry) {
          await _rejectOrder();
        }
      }
    } catch (_) {
      if (mounted) {
        _hideProgressDialog();
        final retry = await AppConfirmSheet.show(
          context: context,
          title: '拒单异常',
          message: '拒单时发生异常，请重试。',
          confirmText: '重试',
          cancelText: '稍后',
          icon: Icons.error_outline_rounded,
          iconBgColor: const Color(0x33F44336),
          iconColor: Colors.redAccent,
        );
        if (retry) {
          await _rejectOrder();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _jumpToLatestCompletedOrder() async {
    if (_task == null || _isLoading || _isUpdating) return;

    setState(() => _isUpdating = true);
    try {
      final repository = ref.read(nurseRepositoryProvider);
      final tasks = await repository.getAllTasks(page: 1, pageSize: 200);
      final completed = tasks
          .where((task) => task.status >= 5 && task.id != _task!.id)
          .toList();

      if (!mounted) return;
      if (completed.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暂无可跳转的已完成订单')));
        return;
      }

      completed.sort((a, b) {
        final aTime = a.finishTime ?? a.createdAt ?? '';
        final bTime = b.finishTime ?? b.createdAt ?? '';
        return bTime.compareTo(aTime);
      });

      await context.router.replace(
        NurseTaskDetailRoute(orderId: completed.first.id),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('跳转失败，请稍后重试')));
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _showProgressDialog(String text) {
    if (!mounted) return;
    _progressDialogVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  void _hideProgressDialog() {
    if (!mounted || !_progressDialogVisible) return;
    _progressDialogVisible = false;
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务详情'),
        actions: [
          if (_task != null)
            IconButton(
              onPressed: _jumpToLatestCompletedOrder,
              icon: const Icon(Icons.history_toggle_off),
              tooltip: '最近完成单',
            ),
          if (_task != null)
            IconButton(
              onPressed: _openNavigation,
              icon: const Icon(Icons.navigation),
              tooltip: '导航',
            ),
        ],
      ),
      body: _isLoading
          ? AppListSkeleton(
              itemCount: 5,
              itemHeight: 112,
              padding: EdgeInsets.all(16.w),
            )
          : _task == null
          ? AppRetryGuide(
              title: '任务加载失败',
              message: _loadError ?? '任务不存在或已被移除',
              onRetry: _loadTaskDetail,
              retryText: '重新加载',
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 订单状态卡片
                  _buildStatusCard(),
                  SizedBox(height: 16.h),

                  // 服务信息
                  _buildServiceInfoCard(),
                  SizedBox(height: 16.h),

                  // 用户信息
                  _buildUserInfoCard(),
                  SizedBox(height: 16.h),

                  // 服务过程记录
                  _buildProcessCard(),
                  SizedBox(height: 16.h),
                  _buildStatusFlowGuide(),
                  SizedBox(height: 16.h),
                  _buildFlowRecordsCard(),
                  SizedBox(height: 16.h),

                  // 备注信息
                  if (_task!.remark != null && _task!.remark!.isNotEmpty)
                    _buildRemarkCard(),

                  SizedBox(height: 100.h), // 给底部按钮留空间
                ],
              ),
            ),
      bottomNavigationBar: _task != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildStatusFlowGuide() {
    final currentStatus = _task!.status;
    final steps = <Map<String, dynamic>>[
      {'title': '待接单', 'status': 1},
      {'title': '待服务', 'status': 2},
      {'title': '到达现场', 'status': 3},
      {'title': '服务中', 'status': 4},
      {'title': '待评价', 'status': 5},
      {'title': '已完成', 'status': 6},
    ];
    return Card(
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('状态流引导'),
            SizedBox(height: 12.h),
            Row(
              children: steps.asMap().entries.map((entry) {
                final index = entry.key;
                final step = entry.value;
                final stepStatus = step['status'] as int;
                final isCompleted = currentStatus >= stepStatus;
                final isCurrent = currentStatus == stepStatus;
                return Expanded(
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 18.w,
                            height: 18.w,
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.green
                                  : isCurrent
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCompleted ? Icons.check : Icons.circle,
                              size: 11.sp,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            step['title'] as String,
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: isCompleted || isCurrent
                                  ? AppTheme.textPrimaryColor
                                  : AppTheme.textHintColor,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (index < steps.length - 1)
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.only(
                              bottom: 14.h,
                              left: 4.w,
                              right: 4.w,
                            ),
                            height: 2.h,
                            color: currentStatus > stepStatus
                                ? Colors.green
                                : Colors.grey.shade300,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 订单状态卡片
  Widget _buildStatusCard() {
    return Card(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                color: Color(_task!.statusColorValue).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getStatusIcon(),
                size: 32.sp,
                color: Color(_task!.statusColorValue),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              _task!.statusText,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: Color(_task!.statusColorValue),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              _task!.orderNo,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.textSecondaryColor,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_task!.status) {
      case 1:
        return Icons.assignment_turned_in_outlined;
      case 2:
        return Icons.schedule;
      case 3:
        return Icons.location_on;
      case 4:
        return Icons.medical_services;
      case 5:
      case 6:
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final text = raw.trim();
    final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
    if (parsed == null) return text;
    final mm = parsed.month.toString().padLeft(2, '0');
    final dd = parsed.day.toString().padLeft(2, '0');
    final hh = parsed.hour.toString().padLeft(2, '0');
    final min = parsed.minute.toString().padLeft(2, '0');
    return '${parsed.year}-$mm-$dd $hh:$min';
  }

  String _orderStatusLabel(dynamic statusCode) {
    final code = int.tryParse('$statusCode') ?? -1;
    switch (code) {
      case 0:
        return '待支付';
      case 1:
        return '待接单';
      case 2:
        return '已派单';
      case 3:
        return '已接单';
      case 4:
        return '已到达';
      case 5:
        return '服务中';
      case 6:
        return '已完成';
      case 7:
        return '已评价';
      case 8:
        return '已取消';
      case 9:
        return '退款中';
      case 10:
        return '已退款';
      default:
        return '-';
    }
  }

  String _payMethodLabel(dynamic value) {
    final method = int.tryParse('$value') ?? 0;
    return method == 1 ? '支付宝' : (method == 2 ? '微信' : '-');
  }

  String _payStatusLabel(dynamic value) {
    final status = int.tryParse('$value') ?? 0;
    return status == 1 ? '支付成功' : (status == 2 ? '支付失败' : '未支付');
  }

  String _refundStatusLabel(dynamic value) {
    final status = int.tryParse('$value') ?? 0;
    return status == 1 ? '退款成功' : (status == 2 ? '退款失败' : '待处理');
  }

  String _callerRoleLabel(dynamic value) {
    final role = (value ?? '').toString().toUpperCase();
    if (role == 'USER') return '用户';
    if (role == 'NURSE') return '护士';
    return role.isEmpty ? '-' : role;
  }

  String _sosStatusLabel(dynamic value) {
    return (int.tryParse('$value') ?? 0) == 1 ? '已处理' : '待处理';
  }

  /// 服务信息卡片
  Widget _buildServiceInfoCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('服务信息'),
            SizedBox(height: 12.h),
            _buildInfoRow('服务项目', _task!.serviceName),
            _buildInfoRow('预约时间', _task!.appointmentTime),
            _buildInfoRow('订单金额', '¥${_task!.totalAmount.toStringAsFixed(2)}'),
            _buildInfoRow(
              '预计收入',
              '¥${_task!.nurseIncome.toStringAsFixed(2)}',
              valueColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  /// 用户信息卡片
  Widget _buildUserInfoCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('用户信息'),
            SizedBox(height: 12.h),
            _buildInfoRow('联系人', _task!.contactName),
            InkWell(
              onTap: () => _makePhoneCall(_task!.contactPhone),
              child: _buildInfoRow(
                '联系电话',
                _task!.contactPhone,
                valueColor: Theme.of(context).primaryColor,
                trailing: Icon(
                  Icons.phone,
                  size: 18.sp,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 80.w,
                  child: Text(
                    '服务地址',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_task!.address, style: TextStyle(fontSize: 14.sp)),
                      SizedBox(height: 8.h),
                      OutlinedButton.icon(
                        onPressed: _openNavigation,
                        icon: Icon(Icons.navigation, size: 16.sp),
                        label: const Text('导航前往'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 6.h,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 服务过程卡片
  Widget _buildProcessCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('服务过程'),
            SizedBox(height: 16.h),

            // 到达节点
            _buildProcessStep(
              title: '到达现场',
              time: _task!.arrivalTime,
              photo: _task!.arrivalPhoto,
              isCompleted: _task!.status >= 3,
              isCurrent: _task!.status == 2,
            ),

            // 开始服务节点
            _buildProcessStep(
              title: '开始服务',
              time: _task!.startTime,
              photo: _task!.startPhoto,
              isCompleted: _task!.status >= 4,
              isCurrent: _task!.status == 3,
            ),

            // 完成服务节点
            _buildProcessStep(
              title: '完成服务',
              time: _task!.finishTime,
              photo: _task!.finishPhoto,
              isCompleted: _task!.status >= 5,
              isCurrent: _task!.status == 4,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  /// 服务过程步骤
  Widget _buildProcessStep({
    required String title,
    String? time,
    String? photo,
    required bool isCompleted,
    required bool isCurrent,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧时间线
          Column(
            children: [
              Container(
                width: 24.w,
                height: 24.w,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green
                      : isCurrent
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCompleted ? Icons.check : Icons.circle,
                  size: 14.sp,
                  color: Colors.white,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2.w,
                    color: isCompleted ? Colors.green : Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          SizedBox(width: 12.w),

          // 右侧内容
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: isCompleted || isCurrent
                              ? AppTheme.textPrimaryColor
                              : AppTheme.textHintColor,
                        ),
                      ),
                      if (isCurrent) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            '当前',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (time != null) ...[
                    SizedBox(height: 4.h),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                  if (photo != null) ...[
                    SizedBox(height: 8.h),
                    GestureDetector(
                      onTap: () => _showPhotoPreview(photo),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: CachedNetworkImage(
                          imageUrl: photo,
                          width: 100.w,
                          height: 75.h,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 预览照片
  void _showPhotoPreview(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  /// 备注卡片
  Widget _buildRemarkCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('用户备注'),
            SizedBox(height: 8.h),
            Text(_task!.remark!, style: TextStyle(fontSize: 14.sp)),
          ],
        ),
      ),
    );
  }

  Widget _buildFlowRecordsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('全链路记录'),
            SizedBox(height: 12.h),
            if (_isLoadingFlow)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildStatusLogSection(),
              SizedBox(height: 12.h),
              _buildPaymentSection(),
              SizedBox(height: 12.h),
              _buildRefundSection(),
              SizedBox(height: 12.h),
              _buildSosSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLogSection() {
    if (_statusLogs.isEmpty) {
      return Text(
        '状态流：暂无',
        style: TextStyle(fontSize: 13.sp, color: Colors.grey),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '状态流',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8.h),
        ..._statusLogs.map((item) {
          final oldStatus = _orderStatusLabel(
            item['oldStatus'] ?? item['old_status'],
          );
          final newStatus = _orderStatusLabel(
            item['newStatus'] ?? item['new_status'],
          );
          final remark = (item['remark'] ?? '').toString();
          final time = _formatDateTime(
            (item['createTime'] ?? item['create_time'])?.toString(),
          );
          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$oldStatus -> $newStatus',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (remark.isNotEmpty)
                    Text(
                      '备注：$remark',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[700],
                      ),
                    ),
                  Text(
                    '时间：$time',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPaymentSection() {
    if (_paymentRecords.isEmpty) {
      return Text(
        '支付记录：暂无',
        style: TextStyle(fontSize: 13.sp, color: Colors.grey),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '支付记录',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8.h),
        ..._paymentRecords.map((item) {
          final amount =
              (item['payAmount'] ?? item['pay_amount'])?.toString() ?? '-';
          final tradeNo = (item['tradeNo'] ?? item['trade_no'] ?? '-')
              .toString();
          final time = _formatDateTime(
            (item['payTime'] ??
                    item['pay_time'] ??
                    item['createTime'] ??
                    item['create_time'])
                ?.toString(),
          );
          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_payMethodLabel(item['payMethod'] ?? item['pay_method'])} · ${_payStatusLabel(item['payStatus'] ?? item['pay_status'])}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text('金额：¥$amount', style: TextStyle(fontSize: 12.sp)),
                  Text(
                    '交易号：$tradeNo',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                  ),
                  Text(
                    '时间：$time',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRefundSection() {
    if (_refundRecords.isEmpty) {
      return Text(
        '退款记录：暂无',
        style: TextStyle(fontSize: 13.sp, color: Colors.grey),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '退款记录',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8.h),
        ..._refundRecords.map((item) {
          final amount =
              (item['refundAmount'] ?? item['refund_amount'])?.toString() ??
              '-';
          final reason = (item['refundReason'] ?? item['refund_reason'] ?? '-')
              .toString();
          final time = _formatDateTime(
            (item['updateTime'] ??
                    item['update_time'] ??
                    item['createTime'] ??
                    item['create_time'])
                ?.toString(),
          );
          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _refundStatusLabel(
                      item['refundStatus'] ?? item['refund_status'],
                    ),
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text('金额：¥$amount', style: TextStyle(fontSize: 12.sp)),
                  Text(
                    '原因：$reason',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                  ),
                  Text(
                    '时间：$time',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSosSection() {
    if (_sosRecords.isEmpty) {
      return Text(
        'SOS记录：暂无',
        style: TextStyle(fontSize: 13.sp, color: Colors.grey),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SOS记录',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8.h),
        ..._sosRecords.map((item) {
          final desc = (item['description'] ?? '-').toString();
          final remark = (item['handleRemark'] ?? item['handle_remark'] ?? '-')
              .toString();
          final createTime = _formatDateTime(
            (item['createTime'] ?? item['create_time'])?.toString(),
          );
          final handleTime = _formatDateTime(
            (item['handledTime'] ?? item['handled_time'])?.toString(),
          );
          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_callerRoleLabel(item['callerRole'] ?? item['caller_role'])}发起 · ${_sosStatusLabel(item['status'])}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text('描述：$desc', style: TextStyle(fontSize: 12.sp)),
                  Text(
                    '处理说明：$remark',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                  ),
                  Text(
                    '发起：$createTime',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  ),
                  Text(
                    '处理：$handleTime',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 底部操作栏
  Widget _buildBottomBar() {
    if (_task!.status >= 5) {
      // 已完成或已取消，不显示操作按钮
      return const SizedBox.shrink();
    }

    String buttonText;
    Color buttonColor;
    VoidCallback? onPressed;

    if (_task!.canAccept) {
      buttonText = '接单';
      buttonColor = Colors.teal;
      onPressed = _acceptOrder;
    } else if (_task!.canArrived) {
      buttonText = '📍 到达现场';
      buttonColor = Colors.purple;
      onPressed = () => _updateStatus(3);
    } else if (_task!.canStart) {
      buttonText = '▶️ 开始服务';
      buttonColor = Colors.blue;
      onPressed = () => _updateStatus(4);
    } else if (_task!.canFinish) {
      buttonText = '✅ 完成服务';
      buttonColor = Colors.green;
      onPressed = () => _updateStatus(5);
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: _task!.canFinish
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _sosReasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: '紧急情况描述（可选）',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      isDense: true,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isUpdating ? null : _triggerSos,
                          icon: const Icon(Icons.sos, color: Colors.red),
                          label: const Text(
                            'SOS求助',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            minimumSize: Size(double.infinity, 50.h),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isUpdating ? null : onPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            minimumSize: Size(double.infinity, 50.h),
                          ),
                          child: _isUpdating
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  buttonText,
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : _task!.canAccept && _task!.canReject
            ? Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isUpdating ? null : _rejectOrder,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        minimumSize: Size(double.infinity, 50.h),
                      ),
                      child: const Text('拒单'),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUpdating ? null : onPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        minimumSize: Size(double.infinity, 50.h),
                      ),
                      child: _isUpdating
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              buttonText,
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              )
            : SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _isUpdating ? null : onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: _isUpdating
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          buttonText,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
      ),
    );
  }

  /// 标题组件
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4.w,
          height: 16.h,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// 信息行
  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.w600 : null,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
