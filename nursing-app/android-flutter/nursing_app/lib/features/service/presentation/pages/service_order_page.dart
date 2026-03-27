import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/contract_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/commercial_ui_widgets.dart';
import '../../../address/data/models/address_model.dart';
import '../../data/models/service_model.dart';
import '../../providers/service_provider.dart';

/// 服务下单页面
///
/// 用户选择服务后填写订单信息
/// 功能：
/// - 展示服务详情和价格
/// - 集成高德地图进行地址定位/选择
/// - 时间选择器选择预约时间
/// - 集成支付宝沙箱支付
@RoutePage()
class ServiceOrderPage extends ConsumerStatefulWidget {
  final int serviceId;

  const ServiceOrderPage({
    super.key,
    @PathParam('serviceId') required this.serviceId,
  });

  @override
  ConsumerState<ServiceOrderPage> createState() => _ServiceOrderPageState();
}

class _ServiceOrderPageState extends ConsumerState<ServiceOrderPage> {
  final _remarkController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // 地址信息
  String? _selectedAddress;
  double? _latitude;
  double? _longitude;

  // 是否正在定位
  bool _isLocating = false;

  // 是否正在提交订单
  bool _isSubmitting = false;

  // 服务信息（默认使用本地数据）
  ServiceModel? _service;
  bool _showValidationHint = false;
  String? _contactNameError;
  String? _contactPhoneError;
  String? _addressError;
  String? _timeError;
  bool _serviceAgreementAccepted = false;
  String? _serviceAgreementSigner;
  DateTime? _serviceAgreementSignedAt;
  String? _serviceAgreementError;
  List<String> _availableTimeSlots = const [];
  String? _selectedTimeSlot;

  @override
  void initState() {
    super.initState();
    _loadServiceInfo();
    _loadNurseAvailability();
    _getCurrentLocation();
    _contactNameController.addListener(_onRealtimeFieldChange);
    _contactPhoneController.addListener(_onRealtimeFieldChange);
  }

  void _loadNurseAvailability() {
    final raw = StorageService.instance.getCache('nurse_work_calendar_latest');
    if (raw is! Map) return;

    final slotsRaw = raw['slots'];
    if (slotsRaw is! Map) return;

    if (_selectedDate == null) return;
    final weekday = _selectedDate!.weekday;
    final daySlotsRaw = slotsRaw[weekday.toString()] ?? slotsRaw[weekday];
    if (daySlotsRaw is List) {
      setState(() {
        _availableTimeSlots = daySlotsRaw.map((e) => e.toString()).toList();
      });
    }
  }

  List<String> _slotsForDate(DateTime date) {
    final raw = StorageService.instance.getCache('nurse_work_calendar_latest');
    if (raw is! Map) return const [];
    final slotsRaw = raw['slots'];
    if (slotsRaw is! Map) return const [];

    final day = date.weekday;
    final values = slotsRaw[day.toString()] ?? slotsRaw[day];
    if (values is! List) return const [];
    return values.map((e) => e.toString()).toList();
  }

  TimeOfDay? _slotStart(String slot) {
    final split = slot.split('-');
    if (split.length != 2) return null;
    final start = split.first.split(':');
    if (start.length != 2) return null;
    final hour = int.tryParse(start[0]);
    final minute = int.tryParse(start[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void dispose() {
    _remarkController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  void _onRealtimeFieldChange() {
    if (!_showValidationHint &&
        _contactNameController.text.isEmpty &&
        _contactPhoneController.text.isEmpty) {
      return;
    }
    setState(() {
      _contactNameError = _validateContactName(_contactNameController.text);
      _contactPhoneError = _validateContactPhone(_contactPhoneController.text);
    });
  }

  String? _validateContactName(String value) {
    if (value.trim().isEmpty) {
      return '请输入联系人姓名';
    }
    if (value.trim().length < 2) {
      return '姓名至少2个字';
    }
    return null;
  }

  String? _validateContactPhone(String value) {
    if (value.trim().isEmpty) {
      return '请输入联系电话';
    }
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value.trim())) {
      return '请输入正确的手机号码';
    }
    return null;
  }

  /// 加载服务信息
  Future<void> _loadServiceInfo() async {
    // 根据 serviceId 获取服务信息
    final services = [
      ServiceModel(
        id: 1,
        name: '静脉采血',
        price: 50.0,
        description: '专业护士上门采血，需自备采血管或备注说明',
        category: '基础护理',
        status: 1,
      ),
      ServiceModel(
        id: 2,
        name: '留置导尿',
        price: 120.0,
        description: '包含导尿管更换及尿道口护理',
        category: '基础护理',
        status: 1,
      ),
      ServiceModel(
        id: 3,
        name: '压疮换药',
        price: 80.0,
        description: '针对I-III期压疮进行清洗换药',
        category: '基础护理',
        status: 1,
      ),
      ServiceModel(
        id: 4,
        name: '肌肉注射',
        price: 45.0,
        description: '皮下/肌肉注射，需提供正规医嘱',
        category: '基础护理',
        status: 1,
      ),
      ServiceModel(
        id: 5,
        name: '血糖监测',
        price: 30.0,
        description: '快速指尖血糖检测',
        category: '基础护理',
        status: 1,
      ),
      ServiceModel(
        id: 6,
        name: '产后通乳',
        price: 200.0,
        description: '专业手法疏通，缓解涨奶疼痛',
        category: '产后护理',
        status: 1,
      ),
      ServiceModel(
        id: 7,
        name: '新生儿护理',
        price: 180.0,
        description: '新生儿脐带护理、沐浴、抚触等专业护理',
        category: '产后护理',
        status: 1,
      ),
      ServiceModel(
        id: 8,
        name: '伤口换药',
        price: 60.0,
        description: '普通伤口清创换药，促进愈合',
        category: '基础护理',
        status: 1,
      ),
    ];

    final fallback = services.firstWhere(
      (s) => s.id == widget.serviceId,
      orElse: () => services.first,
    );

    // 先展示兜底数据，保证页面可立即渲染，再异步更新真实数据。
    if (mounted) {
      setState(() {
        _service = fallback;
      });
    }

    try {
      final detail = await ref
          .read(serviceRepositoryProvider)
          .getServiceDetail(widget.serviceId);
      if (!mounted) return;
      setState(() {
        _service = detail;
      });
    } catch (_) {
      // 使用本地兜底数据即可，不中断下单流程。
    }
  }

  /// 获取当前位置（使用高德地图）
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocating = true;
    });

    try {
      final locationService = ref.read(locationServiceProvider);
      final location = await locationService.getCurrentLocation();

      if (location != null && location.isSuccess) {
        setState(() {
          _selectedAddress = location.fullAddress;
          _latitude = location.latitude;
          _longitude = location.longitude;
        });
      }
    } catch (e) {
      debugPrint('获取位置失败: $e');
      // 使用默认地址（仅开发测试）
      setState(() {
        _selectedAddress = '北京市朝阳区望京SOHO';
        _latitude = 39.9998;
        _longitude = 116.4664;
      });
    } finally {
      setState(() {
        _isLocating = false;
      });
    }
  }

  /// 从已保存的地址簿中选择地址
  Future<void> _selectFromSavedAddresses() async {
    final address = await context.router.push<AddressModel>(
      AddressListRoute(selectMode: true),
    );
    if (address == null) return;
    setState(() {
      _selectedAddress = address.address;
      _latitude = address.latitude;
      _longitude = address.longitude;
      _addressError = null;
    });
    // 同步联系人信息（如果尚未填写）
    if (_contactNameController.text.trim().isEmpty) {
      _contactNameController.text = address.contactName;
    }
    if (_contactPhoneController.text.trim().isEmpty) {
      _contactPhoneController.text = address.contactPhone;
    }
  }

  /// 选择地址
  Future<void> _selectAddress() async {
    // 显示地址搜索对话框
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) => _AddressSearchSheet(
        currentAddress: _selectedAddress,
        onLocationSelect: (address, lat, lng) {
          Navigator.pop(context, {
            'address': address,
            'latitude': lat,
            'longitude': lng,
          });
        },
      ),
    );

    if (result != null) {
      setState(() {
        _selectedAddress = result['address'] as String?;
        _latitude = result['latitude'] as double?;
        _longitude = result['longitude'] as double?;
        _addressError = null;
      });
    }
  }

  /// 选择日期
  Future<void> _selectDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppTheme.primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final daySlots = _slotsForDate(date);
      setState(() {
        _selectedDate = date;
        _availableTimeSlots = daySlots;
        if (_selectedTimeSlot != null &&
            !daySlots.contains(_selectedTimeSlot)) {
          _selectedTime = null;
          _selectedTimeSlot = null;
        }
        if (_selectedTime != null && _selectedTimeSlot != null) {
          _timeError = null;
        }
      });
    }
  }

  /// 选择时间
  Future<void> _selectTime() async {
    if (_selectedDate == null) {
      _showSnackBar('请先选择预约日期');
      return;
    }

    final slots = _availableTimeSlots;
    if (slots.isEmpty) {
      _showSnackBar('当前日期暂无护士可接单时段，请更换日期');
      return;
    }

    final selectedSlot = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '选择可接单时段',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 8.h),
              ...slots.map(
                (slot) => ListTile(
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(slot),
                  trailing: _selectedTimeSlot == slot
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(slot),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedSlot == null) return;
    final start = _slotStart(selectedSlot);
    if (start == null) {
      _showSnackBar('时段格式错误，请重新选择');
      return;
    }

    setState(() {
      _selectedTime = start;
      _selectedTimeSlot = selectedSlot;
      if (_selectedDate != null) {
        _timeError = null;
      }
    });
  }

  /// 显示提示
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16.w),
      ),
    );
  }

  IconData _getServiceIcon(String? name) {
    switch (name) {
      case '静脉采血':
        return Icons.bloodtype;
      case '留置导尿':
        return Icons.medical_services;
      case '压疮换药':
        return Icons.healing;
      case '肌肉注射':
        return Icons.vaccines;
      case '血糖监测':
        return Icons.monitor_heart;
      case '产后通乳':
        return Icons.child_friendly;
      case '新生儿护理':
        return Icons.baby_changing_station;
      case '伤口换药':
        return Icons.local_hospital;
      default:
        return Icons.medical_services;
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case '基础护理':
        return Colors.blue;
      case '产后护理':
        return Colors.pink;
      default:
        return Colors.orange;
    }
  }

  int _estimateDurationMinute(String? serviceName) {
    final map = <String, int>{
      '静脉采血': 30,
      '留置导尿': 45,
      '压疮换药': 40,
      '肌肉注射': 25,
      '血糖监测': 20,
      '产后通乳': 60,
      '新生儿护理': 80,
      '伤口换药': 35,
    };
    return map[serviceName] ?? 40;
  }

  int _estimateMonthlyCount(int serviceId) {
    return 80 + (serviceId * 17 % 140);
  }

  int _estimateSatisfaction(int serviceId) {
    return 95 + (serviceId % 4);
  }

  List<String> _buildServiceHighlights(String? serviceName) {
    switch (serviceName) {
      case '静脉采血':
        return ['护士上门采血', '流程规范', '采后护理提醒'];
      case '留置导尿':
        return ['导尿护理', '无菌操作', '风险提示告知'];
      case '压疮换药':
        return ['创面评估', '清创换药', '居家护理建议'];
      case '产后通乳':
        return ['专业手法', '缓解胀痛', '哺乳指导'];
      default:
        return ['专业护士上门', '标准化服务流程', '平台服务保障'];
    }
  }

  Widget _buildSectionTitle(String title, {bool requiredMark = false}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
        ),
        if (requiredMark)
          Text(
            ' *',
            style: TextStyle(
              fontSize: 15.sp,
              color: Colors.redAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }

  Widget _buildCardShell({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInlineValidation(String? error, {required String successText}) {
    if (error != null) {
      return Padding(
        padding: EdgeInsets.only(top: 6.h, left: 4.w),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 14.sp,
            ),
            SizedBox(width: 4.w),
            Text(
              error,
              style: TextStyle(fontSize: 12.sp, color: Colors.redAccent),
            ),
          ],
        ),
      );
    }
    if (_showValidationHint) {
      return Padding(
        padding: EdgeInsets.only(top: 6.h, left: 4.w),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.green,
              size: 14.sp,
            ),
            SizedBox(width: 4.w),
            Text(
              successText,
              style: TextStyle(fontSize: 12.sp, color: Colors.green),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// 验证表单
  bool _validateForm() {
    setState(() {
      _showValidationHint = true;
      _addressError = (_selectedAddress == null || _selectedAddress!.isEmpty)
          ? '请选择服务地址'
          : null;
      _contactNameError = _validateContactName(_contactNameController.text);
      _contactPhoneError = _validateContactPhone(_contactPhoneController.text);
      _timeError = (_selectedDate == null || _selectedTime == null)
          ? '请选择完整预约时间'
          : null;
      _serviceAgreementError = _serviceAgreementAccepted ? null : '请先签署服务协议';
    });

    final firstError =
        _addressError ??
        _contactNameError ??
        _contactPhoneError ??
        _timeError ??
        _serviceAgreementError;
    if (firstError != null) {
      _showSnackBar(firstError);
      return false;
    }
    return true;
  }

  Future<void> _showRetryGuide({
    required String title,
    required String message,
    required Future<void> Function() onRetry,
  }) async {
    final retry = await AppConfirmSheet.show(
      context: context,
      title: title,
      message: message,
      confirmText: '重试',
      cancelText: '稍后',
      icon: Icons.error_outline_rounded,
      iconBgColor: const Color(0x33F44336),
      iconColor: Colors.redAccent,
    );
    if (retry) {
      await onRetry();
    }
  }

  /// 提交订单并支付
  Future<void> _submitOrder() async {
    if (!_validateForm()) return;
    final appointmentText = DateFormat('MM月dd日 HH:mm').format(
      DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      ),
    );
    final confirm = await AppConfirmSheet.show(
      context: context,
      title: '确认提交订单',
      message:
          '服务：${_service?.name ?? '护理服务'}\n时间：$appointmentText\n地址：${_selectedAddress ?? ''}\n金额：¥${(_service?.price ?? 0).toStringAsFixed(2)}',
      confirmText: '确认下单',
      cancelText: '再看看',
      icon: Icons.shopping_bag_outlined,
    );
    if (!confirm) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 构建预约时间
      final scheduledTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      // 格式化预约时间为字符串
      final appointmentTimeStr = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(scheduledTime);

      // 创建订单请求
      final signInfo = _serviceAgreementSignedAt == null
          ? ''
          : '[协议签署] ${_serviceAgreementSigner ?? ''} ${DateFormat('yyyy-MM-dd HH:mm').format(_serviceAgreementSignedAt!)}';

      final orderRequest = CreateOrderRequest(
        serviceId: widget.serviceId,
        contactName: _contactNameController.text,
        contactPhone: _contactPhoneController.text,
        address: _selectedAddress!,
        latitude: _latitude,
        longitude: _longitude,
        appointmentTime: appointmentTimeStr,
        remark: _remarkController.text.trim().isEmpty
            ? signInfo
            : '${_remarkController.text.trim()}\n$signInfo',
      );

      // 调用创建订单接口
      final orderNotifier = ref.read(orderCreateProvider.notifier);
      final orderResponse = await orderNotifier.createOrder(orderRequest);

      if (orderResponse != null) {
        if (!mounted) return;
        // 下单后进入支付页，由支付页统一处理支付状态和后续动作。
        await context.router.push(
          PaymentRoute(
            orderId: orderResponse.orderId,
            amount: orderResponse.totalAmount,
          ),
        );
      } else {
        await _showRetryGuide(
          title: '创建订单失败',
          message: '订单未创建成功，请检查网络或稍后重试。',
          onRetry: _submitOrder,
        );
      }
    } catch (e) {
      debugPrint('提交订单失败: $e');
      await _showRetryGuide(
        title: '提交失败',
        message: '网络异常导致提交失败，可重试后继续支付流程。',
        onRetry: _submitOrder,
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务详情与下单'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isLocating ? null : _getCurrentLocation,
            icon: const Icon(Icons.my_location_outlined),
            tooltip: '刷新定位',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBanner(),
            SizedBox(height: 10.h),
            _buildServiceCard(),
            SizedBox(height: 12.h),
            _buildServiceDetailSection(),
            SizedBox(height: 16.h),

            // 地址选择
            _buildAddressSection(),

            SizedBox(height: 16.h),

            // 联系人信息
            _buildContactSection(),

            SizedBox(height: 16.h),

            // 预约时间
            _buildTimeSection(),

            SizedBox(height: 16.h),

            // 备注信息
            _buildRemarkSection(),

            SizedBox(height: 16.h),

            // 服务协议签署
            _buildAgreementSection(),

            SizedBox(height: 24.h),

            // 费用明细
            _buildPriceDetail(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// 构建服务信息卡片
  Widget _buildTopBanner() {
    final service = _service;
    final title = service?.name ?? '护理服务';
    final category = service?.category ?? '上门护理';
    final duration = _estimateDurationMinute(service?.name);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.84),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '$category · 预约后护士按时上门',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '约$duration分钟',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '满意度 ${_estimateSatisfaction(service?.id ?? 1)}%',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard() {
    final service = _service;
    final categoryColor = _getCategoryColor(service?.category);
    return _buildCardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 68.w,
            height: 68.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  categoryColor.withValues(alpha: 0.26),
                  categoryColor.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              _getServiceIcon(service?.name),
              size: 34.sp,
              color: categoryColor,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service?.name ?? '护理服务',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                      child: Text(
                        service?.category ?? '其他',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: categoryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  service?.description?.isNotEmpty == true
                      ? service!.description!
                      : '专业护士上门服务，流程规范，安全放心',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppTheme.textSecondaryColor,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: [
                    _buildMiniPill(
                      Icons.schedule_outlined,
                      '约${_estimateDurationMinute(service?.name)}分钟',
                    ),
                    _buildMiniPill(
                      Icons.local_fire_department_outlined,
                      '月服务${_estimateMonthlyCount(service?.id ?? 1)}次',
                    ),
                    _buildMiniPill(
                      Icons.star_outline_rounded,
                      '满意度${_estimateSatisfaction(service?.id ?? 1)}%',
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${service?.price.toStringAsFixed(0) ?? '0'}',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.redAccent,
                ),
              ),
              Text(
                '/次',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.textHintColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPill(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: AppTheme.textSecondaryColor),
          SizedBox(width: 3.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.sp,
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDetailSection() {
    final highlights = _buildServiceHighlights(_service?.name);
    return _buildCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('服务内容'),
          SizedBox(height: 10.h),
          ...highlights.map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16.sp,
                    color: AppTheme.successColor,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6.h),
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.orange,
                  size: 18.sp,
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    '请确保联系人电话畅通，护士将于预约时间前与您确认。',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建地址选择区域
  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionTitle('服务地址', requiredMark: true),
            const Spacer(),
            if (_isLocating)
              SizedBox(
                width: 16.w,
                height: 16.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
            TextButton.icon(
              onPressed: _selectFromSavedAddresses,
              icon: Icon(Icons.bookmark_outline_rounded, size: 16.sp),
              label: const Text('地址簿'),
            ),
            TextButton.icon(
              onPressed: _isLocating ? null : _getCurrentLocation,
              icon: Icon(Icons.my_location_rounded, size: 16.sp),
              label: const Text('重新定位'),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        _buildCardShell(
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: _selectAddress,
            borderRadius: BorderRadius.circular(14.r),
            child: Padding(
              padding: EdgeInsets.all(14.w),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(9.w),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: AppTheme.primaryColor,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedAddress ?? '点击选择服务地址',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: _selectedAddress != null
                                ? AppTheme.textPrimaryColor
                                : AppTheme.textHintColor,
                            fontWeight: _selectedAddress != null
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_latitude != null && _longitude != null) ...[
                          SizedBox(height: 3.h),
                          Text(
                            '坐标: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AppTheme.textHintColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondaryColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildInlineValidation(_addressError, successText: '地址信息有效'),
      ],
    );
  }

  /// 构建联系人信息区域
  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('联系人信息', requiredMark: true),
        SizedBox(height: 8.h),
        _buildCardShell(
          child: Column(
            children: [
              TextField(
                controller: _contactNameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: '联系人姓名',
                  hintText: '请输入联系人姓名',
                  prefixIcon: const Icon(Icons.person_outline),
                  errorText: _contactNameError,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 12.h,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: _contactPhoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  labelText: '联系电话',
                  hintText: '请输入手机号码',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  errorText: _contactPhoneError,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 12.h,
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildInlineValidation(
          _contactNameError ?? _contactPhoneError,
          successText: '联系人信息有效',
        ),
      ],
    );
  }

  /// 构建预约时间区域
  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('预约时间', requiredMark: true),
        SizedBox(height: 4.h),
        Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 13.sp,
              color: AppTheme.textHintColor,
            ),
            SizedBox(width: 4.w),
            Text(
              _selectedDate == null
                  ? '请先选择日期，再选择护士可接单时段'
                  : (_availableTimeSlots.isEmpty
                        ? '当日暂无可接单时段'
                        : '可选时段：${_availableTimeSlots.join('、')}'),
              style: TextStyle(fontSize: 12.sp, color: AppTheme.textHintColor),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: _buildCardShell(
                padding: EdgeInsets.zero,
                child: InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(14.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 14.h,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: AppTheme.primaryColor,
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _selectedDate != null
                                ? DateFormat('MM月dd日').format(_selectedDate!)
                                : '选择日期',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: _selectedDate != null
                                  ? AppTheme.textPrimaryColor
                                  : AppTheme.textHintColor,
                              fontWeight: _selectedDate != null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18.sp,
                          color: AppTheme.textHintColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildCardShell(
                padding: EdgeInsets.zero,
                child: InkWell(
                  onTap: _selectTime,
                  borderRadius: BorderRadius.circular(14.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 14.h,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          color: AppTheme.primaryColor,
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            _selectedTimeSlot != null
                                ? '$_selectedTimeSlot'
                                : '选择时间',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: _selectedTimeSlot != null
                                  ? AppTheme.textPrimaryColor
                                  : AppTheme.textHintColor,
                              fontWeight: _selectedTimeSlot != null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18.sp,
                          color: AppTheme.textHintColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        _buildInlineValidation(_timeError, successText: '预约时间有效'),
      ],
    );
  }

  /// 构建备注区域
  Widget _buildRemarkSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('备注信息'),
        SizedBox(height: 8.h),
        _buildCardShell(
          child: TextField(
            controller: _remarkController,
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: '请填写其他需要说明的信息（选填）',
              contentPadding: EdgeInsets.all(12.w),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建费用明细
  Widget _buildPriceDetail() {
    final servicePrice = _service?.price ?? 0.0;
    const visitFee = 0.0; // 上门费
    final totalPrice = servicePrice + visitFee;

    return _buildCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('费用明细'),
          SizedBox(height: 12.h),
          _buildPriceRow('服务费', '¥${servicePrice.toStringAsFixed(2)}'),
          SizedBox(height: 8.h),
          _buildPriceRow(
            '上门费',
            visitFee > 0 ? '¥${visitFee.toStringAsFixed(2)}' : '免费',
          ),
          Divider(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '合计',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
              Text(
                '¥${totalPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAgreementDialog() async {
    final signerController = TextEditingController(
      text: _serviceAgreementSigner ?? _contactNameController.text.trim(),
    );
    final signed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('上门护理服务协议'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('请确认并签署以下条款：'),
              const SizedBox(height: 8),
              const Text('1. 平台将按预约时间安排护士上门服务。'),
              const Text('2. 用户需确保联系方式有效、服务地址真实。'),
              const Text('3. 如需取消请按平台规则提前操作。'),
              const Text('4. 涉及隐私信息将按平台规范保护。'),
              const SizedBox(height: 12),
              TextField(
                controller: signerController,
                decoration: const InputDecoration(
                  labelText: '签署人姓名',
                  hintText: '请输入签署人姓名',
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
              if (signerController.text.trim().isEmpty) return;
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('确认签署'),
          ),
        ],
      ),
    );

    if (signed != true) return;

    final signer = signerController.text.trim();
    final userId = ref.read(authProvider).user?.id ?? 0;
    if (userId > 0) {
      await ContractService.instance.sign(
        type: ContractType.serviceAgreement,
        userId: userId,
        signer: signer,
      );
    }

    if (!mounted) return;
    setState(() {
      _serviceAgreementAccepted = true;
      _serviceAgreementSigner = signer;
      _serviceAgreementSignedAt = DateTime.now();
      _serviceAgreementError = null;
    });
    _showSnackBar('服务协议签署成功');
  }

  Widget _buildAgreementSection() {
    final signedAt = _serviceAgreementSignedAt == null
        ? null
        : DateFormat('yyyy-MM-dd HH:mm').format(_serviceAgreementSignedAt!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('服务协议签署', requiredMark: true),
        SizedBox(height: 8.h),
        _buildCardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                value: _serviceAgreementAccepted,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) {
                  if (value == true) {
                    _showAgreementDialog();
                  } else {
                    setState(() {
                      _serviceAgreementAccepted = false;
                      _serviceAgreementSigner = null;
                      _serviceAgreementSignedAt = null;
                    });
                  }
                },
                title: const Text('我已阅读并同意《上门护理服务协议》'),
                subtitle: _serviceAgreementAccepted
                    ? Text(
                        '签署人：${_serviceAgreementSigner ?? '-'}${signedAt == null ? '' : '，时间：$signedAt'}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.textSecondaryColor,
                        ),
                      )
                    : null,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _showAgreementDialog,
                  icon: const Icon(Icons.description_outlined),
                  label: Text(_serviceAgreementAccepted ? '重新签署' : '查看协议并签署'),
                ),
              ),
            ],
          ),
        ),
        _buildInlineValidation(_serviceAgreementError, successText: '协议已签署'),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14.sp, color: AppTheme.textSecondaryColor),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 14.sp, color: AppTheme.textPrimaryColor),
        ),
      ],
    );
  }

  /// 构建底部栏
  Widget _buildBottomBar() {
    final totalPrice = _service?.price ?? 0.0;

    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '合计',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '¥',
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: totalPrice.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 24.sp,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(width: 24.w),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            '提交并支付',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 地址搜索底部弹窗
class _AddressSearchSheet extends ConsumerStatefulWidget {
  final String? currentAddress;
  final Function(String address, double lat, double lng) onLocationSelect;

  const _AddressSearchSheet({
    this.currentAddress,
    required this.onLocationSelect,
  });

  @override
  ConsumerState<_AddressSearchSheet> createState() =>
      _AddressSearchSheetState();
}

class _AddressSearchSheetState extends ConsumerState<_AddressSearchSheet> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  String? _searchError;
  bool _isSearching = false;
  int _requestToken = 0;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 搜索地址
  void _searchAddress(String keyword) async {
    final currentToken = ++_requestToken;

    if (keyword.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final results = await LocationService.instance.searchAddress(keyword);
      if (!mounted || currentToken != _requestToken) return;

      setState(() {
        _isSearching = false;
        _searchResults = results;
        _searchError = null;
      });
    } catch (e) {
      if (!mounted || currentToken != _requestToken) return;
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _searchError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _onKeywordChanged(String keyword) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _searchAddress(keyword);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 10.h),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
            ),
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '选择地址',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // 搜索框
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '搜索地址',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchAddress('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 12.h,
                  ),
                ),
                onChanged: _onKeywordChanged,
                onSubmitted: _searchAddress,
              ),
            ),

            SizedBox(height: 12.h),

            // 当前定位
            if (widget.currentAddress != null)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.my_location,
                      color: AppTheme.primaryColor,
                      size: 20.sp,
                    ),
                  ),
                  title: const Text('当前位置'),
                  subtitle: Text(
                    widget.currentAddress!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    widget.onLocationSelect(
                      widget.currentAddress!,
                      39.9042,
                      116.4074,
                    );
                  },
                ),
              ),

            Divider(height: 24.h),

            // 搜索结果
            if (_isSearching)
              const Center(child: CircularProgressIndicator())
            else if (_searchResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 10.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: AppTheme.primaryColor,
                            size: 20.sp,
                          ),
                        ),
                        title: Text(result['name'] as String),
                        subtitle: Text(
                          result['address'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          widget.onLocationSelect(
                            result['address'] as String,
                            (result['latitude'] as num).toDouble(),
                            (result['longitude'] as num).toDouble(),
                          );
                        },
                      ),
                    );
                  },
                ),
              )
            else if (_searchController.text.isNotEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchError == null
                            ? Icons.search_off
                            : Icons.error_outline,
                        size: 48.sp,
                        color: _searchError == null
                            ? Colors.grey.shade300
                            : Colors.redAccent,
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        _searchError ?? '未找到相关地址',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: _searchError == null
                              ? AppTheme.textSecondaryColor
                              : Colors.redAccent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Text(
                    '输入关键词搜索地址',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.textHintColor,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
