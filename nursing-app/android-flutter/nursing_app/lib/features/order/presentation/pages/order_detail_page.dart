import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/network/http_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../user/providers/user_profile_provider.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../../providers/order_provider.dart';

/// 订单详情页面
///
/// 展示订单完整信息
/// 支持取消订单（30分钟内）
/// 支持申请退款
/// 支持评价已完成订单
@RoutePage()
class OrderDetailPage extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailPage({
    super.key,
    @PathParam('orderId') required this.orderId,
  });

  @override
  ConsumerState<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends ConsumerState<OrderDetailPage> {
  final _cancelReasonController = TextEditingController();
  final _refundReasonController = TextEditingController();
  final _sosReasonController = TextEditingController();
  Timer? _payCountdownTimer;
  bool _expiryRefreshTriggered = false;

  // 对话框状态
  bool _showCancelDialog = false;
  bool _showRefundDialog = false;
  bool _loadingTrackData = false;
  List<Map<String, dynamic>> _timeline = const [];
  List<Map<String, dynamic>> _checkinPhotos = const [];
  List<Map<String, dynamic>> _paymentRecords = const [];
  List<Map<String, dynamic>> _refundRecords = const [];
  List<Map<String, dynamic>> _sosRecords = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTrackData();
      ref.read(userProfileProvider.notifier).loadProfile();
    });
  }

  @override
  void dispose() {
    _payCountdownTimer?.cancel();
    _cancelReasonController.dispose();
    _refundReasonController.dispose();
    _sosReasonController.dispose();
    super.dispose();
  }

  int get _orderIdInt => int.tryParse(widget.orderId) ?? 0;

  void _syncPayCountdownTimer(OrderModel? order) {
    final shouldTick =
        order != null &&
        order.orderStatus == OrderStatus.pendingPayment &&
        !order.isPaid;

    if (!shouldTick) {
      _payCountdownTimer?.cancel();
      _payCountdownTimer = null;
      _expiryRefreshTriggered = false;
      return;
    }

    if (_payCountdownTimer != null) return;

    _payCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});

      final latestOrder = ref.read(orderDetailProvider(_orderIdInt)).order;
      if (latestOrder == null) return;
      if (latestOrder.orderStatus != OrderStatus.pendingPayment ||
          latestOrder.isPaid) {
        _payCountdownTimer?.cancel();
        _payCountdownTimer = null;
        _expiryRefreshTriggered = false;
        return;
      }
      if (!_expiryRefreshTriggered && latestOrder.isPaymentExpired) {
        _expiryRefreshTriggered = true;
        ref
            .read(orderDetailProvider(_orderIdInt).notifier)
            .loadOrder(_orderIdInt);
      }
    });
  }

  /// 取消订单
  Future<void> _handleCancelOrder() async {
    setState(() => _showCancelDialog = false);

    final reason = _cancelReasonController.text.trim();
    final success = await ref
        .read(orderOperationProvider.notifier)
        .cancelOrder(_orderIdInt, reason.isEmpty ? '用户主动取消' : reason);

    _cancelReasonController.clear();

    if (mounted) {
      final state = ref.read(orderOperationProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message ?? (success ? '取消成功' : '取消失败')),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        // 刷新订单详情
        ref
            .read(orderDetailProvider(_orderIdInt).notifier)
            .loadOrder(_orderIdInt);
        // 刷新订单列表
        ref.read(orderListProvider.notifier).refresh();
      }
    }
  }

  /// 申请退款
  Future<void> _handleRefund(OrderModel order) async {
    final reason = _refundReasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入退款原因'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _showRefundDialog = false);

    final success = await ref
        .read(orderOperationProvider.notifier)
        .requestRefund(_orderIdInt, reason);

    _refundReasonController.clear();

    if (mounted) {
      final state = ref.read(orderOperationProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message ?? (success ? '退款申请已提交' : '退款申请失败')),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );

      if (success) {
        // 刷新订单详情
        ref
            .read(orderDetailProvider(_orderIdInt).notifier)
            .loadOrder(_orderIdInt);
      }
    }
  }

  /// 复制电话号码到剪贴板
  void _copyPhoneNumber(String phoneNumber) {
    Clipboard.setData(ClipboardData(text: phoneNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('电话号码已复制：$phoneNumber'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// 跳转支付页面
  void _goToPayment() {
    context.router.push(PaymentRoute(orderId: _orderIdInt));
  }

  Future<void> _loadTrackData() async {
    if (_orderIdInt <= 0) return;
    setState(() => _loadingTrackData = true);
    final repo = ref.read(orderRepositoryProvider);
    final results = await Future.wait([
      repo.getOrderTimeline(_orderIdInt),
      repo.getOrderCheckinPhotos(_orderIdInt),
      repo.getOrderFlow(_orderIdInt),
    ]);
    if (!mounted) return;
    final timeline = (results[0] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final checkinPhotos = (results[1] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final flow = results[2] as Map<String, dynamic>;
    setState(() {
      _timeline = timeline;
      _checkinPhotos = checkinPhotos;
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
      _loadingTrackData = false;
    });
  }

  String _payMethodLabel(dynamic value) {
    final method = int.tryParse('$value') ?? 0;
    switch (method) {
      case 1:
        return '支付宝';
      case 2:
        return '微信';
      default:
        return '-';
    }
  }

  String _payStatusLabel(dynamic value) {
    final status = int.tryParse('$value') ?? 0;
    switch (status) {
      case 1:
        return '支付成功';
      case 2:
        return '支付失败';
      default:
        return '未支付';
    }
  }

  String _refundStatusLabel(dynamic value) {
    final status = int.tryParse('$value') ?? 0;
    switch (status) {
      case 1:
        return '退款成功';
      case 2:
        return '退款失败';
      default:
        return '待处理';
    }
  }

  String _sosStatusLabel(dynamic value) {
    final status = int.tryParse('$value') ?? 0;
    return status == 1 ? '已处理' : '待处理';
  }

  String _callerRoleLabel(dynamic value) {
    final role = (value ?? '').toString().toUpperCase();
    if (role == 'USER') return '用户';
    if (role == 'NURSE') return '护士';
    return role.isEmpty ? '-' : role;
  }

  String _statusLabelFromCode(dynamic code) {
    final value = int.tryParse('$code') ?? -1;
    switch (value) {
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

  String _checkinTypeLabel(dynamic type) {
    switch (int.tryParse('$type')) {
      case 1:
        return '到达现场';
      case 2:
        return '开始服务';
      case 3:
        return '完成服务';
      default:
        return '打卡';
    }
  }

  String _resolveImageUrl(String raw) {
    final path = raw.trim().replaceAll('\\', '/');
    if (path.isEmpty) return '';

    final apiUri = Uri.tryParse(ApiConfig.baseUrl);
    if (apiUri == null) return path;
    final origin =
        '${apiUri.scheme}://${apiUri.host}${apiUri.hasPort ? ':${apiUri.port}' : ''}';
    final contextPath = () {
      final p = apiUri.path.trim();
      if (p.isEmpty || p == '/') return '';
      return p.endsWith('/') ? p.substring(0, p.length - 1) : p;
    }();

    String? normalizeToUploadPath(String value) {
      var v = value.trim().replaceAll('\\', '/');
      if (v.isEmpty) return null;

      final staticUploadsIndex = v.indexOf('/static/uploads/');
      if (staticUploadsIndex >= 0) {
        v = v.substring(staticUploadsIndex).replaceFirst('/static', '');
      }

      final uploadsIndex = v.indexOf('/uploads/');
      if (uploadsIndex >= 0) {
        return v.substring(uploadsIndex);
      }

      if (v.startsWith('uploads/')) {
        return '/$v';
      }
      if (v.startsWith('static/uploads/')) {
        return '/${v.replaceFirst('static/', '')}';
      }
      if (v.startsWith('/static/uploads/')) {
        return v.replaceFirst('/static', '');
      }

      return null;
    }

    final uploadPath = normalizeToUploadPath(path);
    if (uploadPath != null) {
      return '$origin$contextPath$uploadPath';
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$origin$normalizedPath';
  }

  Future<void> _dialEmergencyContact() async {
    final phone = ref.read(userProfileProvider).profile?.emergencyPhone?.trim();
    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未设置紧急联系人电话，请先在个人资料中完善')));
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法发起电话呼叫')));
  }

  Future<void> _handleSos(OrderModel order) async {
    final reason = _sosReasonController.text.trim();
    final success = await ref
        .read(orderOperationProvider.notifier)
        .triggerSos(order.id, description: reason);

    _sosReasonController.clear();

    if (!mounted) return;
    final state = ref.read(orderOperationProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(state.message ?? (success ? 'SOS发送成功' : 'SOS发送失败')),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderDetailProvider(_orderIdInt));
    final operationState = ref.watch(orderOperationProvider);
    _syncPayCountdownTimer(orderState.order);

    return Scaffold(
      appBar: AppBar(title: const Text('订单详情')),
      body: Stack(
        children: [
          if (orderState.isLoading && orderState.order == null)
            const Center(child: CircularProgressIndicator())
          else if (orderState.error != null && orderState.order == null)
            _buildErrorView(orderState.error!)
          else if (orderState.order != null)
            _buildContent(orderState.order!),

          // 加载遮罩
          if (operationState.isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),

          // 取消对话框
          if (_showCancelDialog) _buildCancelDialog(),

          // 退款对话框
          if (_showRefundDialog && orderState.order != null)
            _buildRefundDialog(orderState.order!),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: Colors.grey),
          SizedBox(height: 16.h),
          Text(
            error,
            style: TextStyle(color: Colors.grey, fontSize: 14.sp),
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(orderDetailProvider(_orderIdInt).notifier)
                  .loadOrder(_orderIdInt);
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(OrderModel order) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 订单状态卡片
          _buildStatusCard(order),
          SizedBox(height: 16.h),

          // 取消/退款提示
          if (order.canCancel || order.canRefund) _buildCancelInfoCard(order),

          if (order.orderStatus == OrderStatus.inService) _buildSosCard(order),

          // 退款状态
          if (order.orderRefundStatus != RefundStatus.none)
            _buildRefundStatusCard(order),

          SizedBox(height: 16.h),

          // 服务信息
          _buildSection(
            title: '服务信息',
            child: Column(
              children: [
                _buildInfoRow('订单编号', order.orderNo),
                _buildInfoRow('服务项目', order.serviceName),
                _buildInfoRow(
                  '服务费用',
                  '¥${order.totalAmount.toStringAsFixed(2)}',
                ),
                _buildInfoRow('预约时间', _formatDateTime(order.appointmentTime)),
                if (order.createdAt != null)
                  _buildInfoRow('下单时间', _formatDateTime(order.createdAt!)),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // 地址信息
          _buildSection(
            title: '服务地址',
            child: Column(children: [_buildInfoRow('地址', order.address)]),
          ),

          SizedBox(height: 16.h),

          // 护士信息
          if (order.nurseName != null)
            _buildSection(
              title: '护士信息',
              child: Column(
                children: [
                  _buildInfoRow('姓名', order.nurseName!),
                  if (order.nursePhone != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 80.w,
                          child: Text(
                            '电话',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                order.nursePhone!,
                                style: TextStyle(fontSize: 14.sp),
                              ),
                              SizedBox(width: 8.w),
                              GestureDetector(
                                onTap: () =>
                                    _copyPhoneNumber(order.nursePhone!),
                                child: Icon(
                                  Icons.copy,
                                  size: 20.sp,
                                  color: Colors.green,
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

          SizedBox(height: 16.h),

          // 服务进度
          if (order.orderStatus.value >= OrderStatus.arrived.value ||
              order.arrivalTime != null ||
              order.startTime != null ||
              order.finishTime != null)
            _buildSection(
              title: '服务进度',
              child: Column(
                children: [
                  if (order.arrivalTime != null)
                    _buildInfoRow('到达时间', _formatDateTime(order.arrivalTime!)),
                  if (order.startTime != null)
                    _buildInfoRow('开始时间', _formatDateTime(order.startTime!)),
                  if (order.finishTime != null)
                    _buildInfoRow('完成时间', _formatDateTime(order.finishTime!)),
                ],
              ),
            ),

          SizedBox(height: 16.h),

          _buildSection(
            title: '服务流程时间轴',
            child: _loadingTrackData
                ? const Center(child: CircularProgressIndicator())
                : (_timeline.isEmpty
                      ? Text(
                          '暂无流程记录',
                          style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                        )
                      : Column(
                          children: _timeline.map((item) {
                            final oldStatus = _statusLabelFromCode(
                              item['oldStatus'] ?? item['old_status'],
                            );
                            final newStatus = _statusLabelFromCode(
                              item['newStatus'] ?? item['new_status'],
                            );
                            final time =
                                (item['createTime'] ??
                                        item['create_time'] ??
                                        '')
                                    .toString();
                            final remark = (item['remark'] ?? '').toString();
                            return Padding(
                              padding: EdgeInsets.only(bottom: 10.h),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.timeline,
                                    size: 16.sp,
                                    color: AppTheme.primaryColor,
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$oldStatus → $newStatus',
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (remark.isNotEmpty)
                                          Text(
                                            remark,
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        if (time.isNotEmpty)
                                          Text(
                                            _formatDateTime(time),
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        )),
          ),

          SizedBox(height: 16.h),

          _buildSection(
            title: '打卡照片',
            child: _checkinPhotos.isEmpty
                ? Text(
                    '暂无打卡照片',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                  )
                : Column(
                    children: _checkinPhotos.map((item) {
                      final url = _resolveImageUrl(
                        (item['photoUrl'] ?? item['photo_url'] ?? '')
                            .toString(),
                      );
                      final typeLabel = _checkinTypeLabel(
                        item['checkinType'] ?? item['checkin_type'],
                      );
                      final time =
                          (item['createTime'] ?? item['create_time'] ?? '')
                              .toString();
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            if (url.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.r),
                                child: Image.network(
                                  url,
                                  width: double.infinity,
                                  height: 160.h,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        height: 160.h,
                                        alignment: Alignment.center,
                                        color: Colors.grey.shade100,
                                        child: const Text('照片加载失败'),
                                      ),
                                ),
                              ),
                            if (time.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 6.h),
                                child: Text(
                                  _formatDateTime(time),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),

          SizedBox(height: 16.h),

          _buildSection(
            title: '支付记录',
            child: _paymentRecords.isEmpty
                ? Text(
                    '暂无支付记录',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                  )
                : Column(
                    children: _paymentRecords.map((item) {
                      final amount = (item['payAmount'] ?? item['pay_amount'])
                          ?.toString();
                      final tradeNo =
                          (item['tradeNo'] ?? item['trade_no'] ?? '-')
                              .toString();
                      final time =
                          (item['payTime'] ??
                                  item['pay_time'] ??
                                  item['createTime'] ??
                                  item['create_time'] ??
                                  '')
                              .toString();
                      return Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
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
                              SizedBox(height: 4.h),
                              Text(
                                '金额：${amount == null || amount.isEmpty ? '-' : '¥$amount'}',
                                style: TextStyle(fontSize: 12.sp),
                              ),
                              Text(
                                '交易号：$tradeNo',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (time.isNotEmpty)
                                Text(
                                  _formatDateTime(time),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),

          SizedBox(height: 16.h),

          _buildSection(
            title: '退款记录',
            child: _refundRecords.isEmpty
                ? Text(
                    '暂无退款记录',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                  )
                : Column(
                    children: _refundRecords.map((item) {
                      final amount =
                          (item['refundAmount'] ?? item['refund_amount'])
                              ?.toString();
                      final reason =
                          (item['refundReason'] ?? item['refund_reason'] ?? '-')
                              .toString();
                      final time =
                          (item['updateTime'] ??
                                  item['update_time'] ??
                                  item['createTime'] ??
                                  item['create_time'] ??
                                  '')
                              .toString();
                      return Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
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
                              SizedBox(height: 4.h),
                              Text(
                                '金额：${amount == null || amount.isEmpty ? '-' : '¥$amount'}',
                                style: TextStyle(fontSize: 12.sp),
                              ),
                              Text(
                                '原因：$reason',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (time.isNotEmpty)
                                Text(
                                  _formatDateTime(time),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),

          SizedBox(height: 16.h),

          _buildSection(
            title: 'SOS记录',
            child: _sosRecords.isEmpty
                ? Text(
                    '暂无SOS记录',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                  )
                : Column(
                    children: _sosRecords.map((item) {
                      final description = (item['description'] ?? '')
                          .toString()
                          .trim();
                      final remark =
                          (item['handleRemark'] ?? item['handle_remark'] ?? '-')
                              .toString();
                      final created =
                          (item['createTime'] ?? item['create_time'] ?? '')
                              .toString();
                      final handled =
                          (item['handledTime'] ?? item['handled_time'] ?? '')
                              .toString();
                      return Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
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
                              SizedBox(height: 4.h),
                              Text(
                                '描述：${description.isEmpty ? '-' : description}',
                                style: TextStyle(fontSize: 12.sp),
                              ),
                              Text(
                                '处理说明：$remark',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (created.isNotEmpty)
                                Text(
                                  '发起：${_formatDateTime(created)}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey,
                                  ),
                                ),
                              if (handled.isNotEmpty)
                                Text(
                                  '处理：${_formatDateTime(handled)}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),

          SizedBox(height: 16.h),

          // 评价区域（待评价状态显示评价入口）
          if (order.orderStatus == OrderStatus.pendingEvaluation)
            _buildEvaluationSection(),

          // 已完成状态显示评价内容
          if (order.orderStatus == OrderStatus.completed)
            _buildCompletedSection(order),

          SizedBox(height: 100.h),
        ],
      ),
    );
  }

  /// 格式化日期时间字符串
  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  Widget _buildStatusCard(OrderModel order) {
    final status = order.orderStatus;
    final isCompleted = status == OrderStatus.completed;
    final isCancelled = status == OrderStatus.cancelled;
    final statusColor = Color(status.colorValue);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withValues(alpha: 0.8)],
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          Icon(
            isCompleted
                ? Icons.check_circle
                : isCancelled
                ? Icons.cancel
                : Icons.access_time,
            size: 48.sp,
            color: Colors.white,
          ),
          SizedBox(height: 12.h),
          Text(
            order.displayStatusText,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (status == OrderStatus.pendingPayment) ...[
            SizedBox(height: 8.h),
            Text(
              order.isPaymentExpired
                  ? '支付超时，订单即将自动关闭'
                  : '订单保留倒计时：${order.remainingPaySeconds ~/ 60}分${order.remainingPaySeconds % 60}秒',
              style: TextStyle(
                fontSize: 12.sp,
                color: order.isPaymentExpired ? Colors.redAccent : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            ElevatedButton(
              onPressed: order.isPaymentExpired ? null : _goToPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: statusColor,
              ),
              child: Text('立即支付 ¥${order.totalAmount.toStringAsFixed(2)}'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCancelInfoCard(OrderModel order) {
    final remainingMinutes = order.remainingCancelMinutes;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                '取消/退款说明',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          if (order.canCancel) ...[
            Text(
              '• 支付后30分钟内可免费取消订单',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
            ),
            SizedBox(height: 4.h),
            Text(
              '• 剩余取消时间：$remainingMinutes 分钟',
              style: TextStyle(
                fontSize: 13.sp,
                color: remainingMinutes <= 10 ? Colors.red : Colors.grey[700],
                fontWeight: remainingMinutes <= 10
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
          SizedBox(height: 12.h),
          Row(
            children: [
              if (order.canCancel)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showCancelDialog = true),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: Text(
                      '取消订单',
                      style: TextStyle(color: Colors.red, fontSize: 14.sp),
                    ),
                  ),
                ),
              if (order.canCancel && order.canRefund) SizedBox(width: 12.w),
              if (order.canRefund && !order.canCancel)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _showRefundDialog = true),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                    ),
                    child: Text(
                      '申请退款',
                      style: TextStyle(color: Colors.blue, fontSize: 14.sp),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefundStatusCard(OrderModel order) {
    Color color;
    String text;
    IconData icon;

    switch (order.orderRefundStatus) {
      case RefundStatus.processing:
        color = Colors.blue;
        text = '退款处理中';
        icon = Icons.hourglass_top;
        break;
      case RefundStatus.refunded:
        color = Colors.green;
        text = '退款成功';
        icon = Icons.check_circle;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(width: 8.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 14.sp,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (order.refundAmount != null) ...[
            const Spacer(),
            Text(
              '¥${order.refundAmount!.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16.sp,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSosCard(OrderModel order) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                '紧急呼叫（SOS）',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '服务中如遇突发情况，可立即发起紧急呼叫，平台将优先处理。',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
          ),
          SizedBox(height: 10.h),
          TextField(
            controller: _sosReasonController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: '请简要描述紧急情况（可选）',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              isDense: true,
            ),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _handleSos(order),
                    icon: const Icon(Icons.sos),
                    label: const Text('立即SOS求助'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _dialEmergencyContact,
                    icon: const Icon(Icons.call),
                    label: const Text('紧急联系人快拨'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvaluationSection() {
    return _buildSection(
      title: '服务评价',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '您的订单已完成，请对本次服务进行评价',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final submitted = await context.router.push<bool>(
                  EvaluationScreenRoute(orderId: _orderIdInt),
                );
                if (submitted == true && mounted) {
                  ref
                      .read(orderDetailProvider(_orderIdInt).notifier)
                      .loadOrder(_orderIdInt);
                  ref.read(orderListProvider.notifier).refresh();
                }
              },
              icon: const Icon(Icons.star),
              label: const Text('立即评价'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSection(OrderModel order) {
    return _buildSection(
      title: '我的评价',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.rating != null) ...[
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < order.rating! ? Icons.star : Icons.star_border,
                    size: 24.sp,
                    color: Colors.amber,
                  );
                }),
                SizedBox(width: 8.w),
                Text(
                  '${order.rating}分',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
          ],
          if (order.evaluationContent != null &&
              order.evaluationContent!.isNotEmpty)
            Text(
              order.evaluationContent!,
              style: TextStyle(fontSize: 14.sp, color: Colors.black87),
            )
          else if (order.rating != null)
            Text(
              '暂无文字评价',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppTheme.textSecondaryColor,
              ),
            )
          else
            Row(
              children: [
                Icon(Icons.check_circle, size: 20.sp, color: Colors.green),
                SizedBox(width: 8.w),
                Text(
                  '订单已完成',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12.h),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: Text(value, style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelDialog() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(32.w),
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 48.sp,
                color: Colors.orange,
              ),
              SizedBox(height: 16.h),
              Text(
                '确认取消订单？',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                '取消后订单将关闭，支付金额将原路退回',
                style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _cancelReasonController,
                decoration: InputDecoration(
                  hintText: '请输入取消原因（选填）',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  contentPadding: EdgeInsets.all(12.w),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _showCancelDialog = false);
                        _cancelReasonController.clear();
                      },
                      child: const Text('再想想'),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleCancelOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        '确认取消',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefundDialog(OrderModel order) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(32.w),
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 48.sp,
                color: Colors.blue,
              ),
              SizedBox(height: 16.h),
              Text(
                '申请退款',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              Text(
                '退款金额：¥${order.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16.h),
              TextField(
                controller: _refundReasonController,
                decoration: InputDecoration(
                  hintText: '请输入退款原因',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  contentPadding: EdgeInsets.all(12.w),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 8.h),
              Text(
                '提交后系统会自动原路退款至支付账户，请留意到账通知',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _showRefundDialog = false);
                        _refundReasonController.clear();
                      },
                      child: const Text('取消'),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleRefund(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text(
                        '提交申请',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
