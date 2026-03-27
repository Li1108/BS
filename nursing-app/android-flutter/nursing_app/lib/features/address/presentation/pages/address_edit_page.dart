import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/services/location_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/commercial_ui_widgets.dart';
import '../../data/models/address_model.dart';
import '../../providers/address_provider.dart';

/// 地址编辑页面
///
/// 功能：
/// 1. 添加/编辑地址
/// 2. 集成高德地图定位和地址选择
/// 3. 自动填充经纬度
@RoutePage()
class AddressEditPage extends ConsumerStatefulWidget {
  final int? addressId;

  const AddressEditPage({super.key, @PathParam('addressId') this.addressId});

  @override
  ConsumerState<AddressEditPage> createState() => _AddressEditPageState();
}

class _AddressEditPageState extends ConsumerState<AddressEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _detailController = TextEditingController();

  double? _latitude;
  double? _longitude;
  String? _province;
  String? _city;
  String? _district;
  bool _isDefault = false;
  bool _isLoading = false;
  bool _isLocating = false;

  AddressModel? _editingAddress;

  bool get _isEditMode => widget.addressId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadAddress();
    }
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _addressController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  /// 加载地址详情（编辑模式）
  Future<void> _loadAddress() async {
    setState(() => _isLoading = true);

    try {
      final addresses = ref.read(addressListProvider).addresses;
      final address = addresses.firstWhere(
        (a) => a.id == widget.addressId,
        orElse: () => throw Exception('地址不存在'),
      );

      setState(() {
        _editingAddress = address;
        _contactNameController.text = address.contactName;
        _contactPhoneController.text = address.contactPhone;
        _addressController.text = address.address;
        _detailController.text = address.detail ?? '';
        _latitude = address.latitude;
        _longitude = address.longitude;
        _province = address.province;
        _city = address.city;
        _district = address.district;
        _isDefault = address.isDefaultAddress;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final retry = await AppConfirmSheet.show(
          context: context,
          title: '地址加载失败',
          message: '无法获取地址详情，请重试。',
          confirmText: '重试',
          cancelText: '返回',
          icon: Icons.error_outline_rounded,
          iconBgColor: const Color(0x33F44336),
          iconColor: Colors.redAccent,
        );
        if (retry) {
          await _loadAddress();
        } else {
          if (!mounted) return;
          context.router.maybePop();
        }
      }
    }
  }

  /// 获取当前位置
  Future<void> _getCurrentLocation() async {
    // 检查权限
    final hasPermission = await PermissionService.instance
        .hasLocationPermission();
    if (!hasPermission) {
      if (!mounted) return;
      final granted = await PermissionService.instance
          .showLocationPermissionDialog(context);
      if (!granted) return;
    }

    setState(() => _isLocating = true);

    try {
      final location = await LocationService.instance.getCurrentLocation();

      if (location != null && location.isSuccess && mounted) {
        setState(() {
          _latitude = location.latitude;
          _longitude = location.longitude;
        });

        // 逆地理编码获取地址
        final addressInfo = await LocationService.instance
            .getAddressFromLocation(_latitude!, _longitude!);

        if (addressInfo != null && mounted) {
          setState(() {
            _addressController.text = addressInfo['address'] ?? '';
            _province = addressInfo['province'];
            _city = addressInfo['city'];
            _district = addressInfo['district'];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('定位失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  /// 搜索并选择地址
  Future<void> _searchAddress() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddressSearchDialog(),
    );

    if (result != null && mounted) {
      setState(() {
        _addressController.text = result['address'] ?? '';
        _latitude = result['latitude'];
        _longitude = result['longitude'];
        _province = result['province'];
        _city = result['city'];
        _district = result['district'];
      });
    }
  }

  /// 地图坐标选点
  Future<void> _pickCoordinateOnMap() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CoordinatePickerDialog(
        initialLatitude: _latitude,
        initialLongitude: _longitude,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result['latitude'] as double?;
        _longitude = result['longitude'] as double?;
        _addressController.text = result['address']?.toString() ?? '';
        _province = result['province']?.toString();
        _city = result['city']?.toString();
        _district = result['district']?.toString();
      });
    }
  }

  /// 保存地址
  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await AppConfirmSheet.show(
      context: context,
      title: _isEditMode ? '确认更新地址' : '确认新增地址',
      message:
          '联系人：${_contactNameController.text.trim()}\n电话：${_contactPhoneController.text.trim()}\n地址：${_addressController.text.trim()}',
      confirmText: _isEditMode ? '确认更新' : '确认新增',
      cancelText: '再检查',
      icon: Icons.location_on_outlined,
    );
    if (!confirmed) return;

    // 组装完整地址
    String fullAddress = _addressController.text.trim();
    final detail = _detailController.text.trim();
    if (detail.isNotEmpty && !fullAddress.contains(detail)) {
      fullAddress = '$fullAddress $detail';
    }

    final request = AddressRequest(
      address: fullAddress,
      contactName: _contactNameController.text.trim(),
      contactPhone: _contactPhoneController.text.trim(),
      isDefault: _isDefault ? 1 : 0,
      latitude: _latitude,
      longitude: _longitude,
      province: _province,
      city: _city,
      district: _district,
      detail: detail,
    );

    setState(() => _isLoading = true);

    try {
      bool success;
      if (_isEditMode) {
        success = await ref
            .read(addressListProvider.notifier)
            .updateAddress(widget.addressId!, request);
      } else {
        success = await ref
            .read(addressListProvider.notifier)
            .addAddress(request);
      }

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isEditMode ? '地址已更新' : '地址已添加'),
              backgroundColor: Colors.green,
            ),
          );
          context.router.maybePop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存失败'), backgroundColor: Colors.red),
          );
          final retry = await AppConfirmSheet.show(
            context: context,
            title: '保存失败',
            message: '地址保存未成功，请重试。',
            confirmText: '重试保存',
            cancelText: '稍后再试',
            icon: Icons.error_outline_rounded,
            iconBgColor: const Color(0x33F44336),
            iconColor: Colors.redAccent,
          );
          if (retry) {
            await _saveAddress();
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '编辑地址' : '添加地址'),
        centerTitle: true,
      ),
      body: _isLoading && _editingAddress == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 联系人
                    _buildSectionTitle('联系人信息'),
                    SizedBox(height: 12.h),
                    _buildTextField(
                      controller: _contactNameController,
                      label: '联系人姓名',
                      hint: '请输入联系人姓名',
                      icon: Icons.person_outline,
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入联系人姓名';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 4.h),
                    _buildFieldHint(
                      valid: _contactNameController.text.trim().length >= 2,
                      text: _contactNameController.text.trim().length >= 2
                          ? '联系人姓名有效'
                          : '建议填写真实姓名',
                    ),
                    SizedBox(height: 12.h),
                    _buildTextField(
                      controller: _contactPhoneController,
                      label: '联系电话',
                      hint: '请输入联系电话',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入联系电话';
                        }
                        if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value.trim())) {
                          return '请输入正确的手机号';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 4.h),
                    _buildFieldHint(
                      valid: RegExp(
                        r'^1[3-9]\d{9}$',
                      ).hasMatch(_contactPhoneController.text.trim()),
                      text:
                          RegExp(
                            r'^1[3-9]\d{9}$',
                          ).hasMatch(_contactPhoneController.text.trim())
                          ? '手机号格式正确'
                          : '请输入11位手机号',
                    ),

                    SizedBox(height: 24.h),

                    // 地址信息
                    _buildSectionTitle('地址信息'),
                    SizedBox(height: 12.h),

                    // 定位按钮
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLocating ? null : _getCurrentLocation,
                            icon: _isLocating
                                ? SizedBox(
                                    width: 18.w,
                                    height: 18.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                            label: Text(_isLocating ? '定位中...' : '获取当前位置'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _searchAddress,
                            icon: const Icon(Icons.search),
                            label: const Text('搜索地址'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickCoordinateOnMap,
                        icon: const Icon(Icons.pin_drop_outlined),
                        label: const Text('地图坐标选点'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // 地址输入
                    _buildTextField(
                      controller: _addressController,
                      label: '详细地址',
                      hint: '省/市/区/街道',
                      icon: Icons.location_on_outlined,
                      maxLines: 2,
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入详细地址';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 4.h),
                    _buildFieldHint(
                      valid: _addressController.text.trim().isNotEmpty,
                      text: _addressController.text.trim().isNotEmpty
                          ? '地址信息有效'
                          : '请填写可上门服务地址',
                    ),
                    SizedBox(height: 12.h),

                    // 门牌号
                    _buildTextField(
                      controller: _detailController,
                      label: '门牌号',
                      hint: '楼栋/单元/门牌号（选填）',
                      icon: Icons.home_outlined,
                    ),

                    // 经纬度显示
                    if (_latitude != null && _longitude != null) ...[
                      SizedBox(height: 12.h),
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 18.sp,
                              color: Colors.green,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                '已获取坐标: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.green[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 24.h),

                    // 设为默认
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.star_outline,
                            size: 24.sp,
                            color: Theme.of(context).primaryColor,
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              '设为默认地址',
                              style: TextStyle(fontSize: 15.sp),
                            ),
                          ),
                          Switch(
                            value: _isDefault,
                            onChanged: (value) {
                              setState(() => _isDefault = value);
                            },
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // 保存按钮
                    SizedBox(
                      width: double.infinity,
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveAddress,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24.r),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 24.w,
                                height: 24.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                '保存地址',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    SizedBox(height: 24.h),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryColor,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      ),
    );
  }

  Widget _buildFieldHint({required bool valid, required String text}) {
    return Row(
      children: [
        Icon(
          valid
              ? Icons.check_circle_outline_rounded
              : Icons.info_outline_rounded,
          size: 14.sp,
          color: valid ? Colors.green : AppTheme.textHintColor,
        ),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.sp,
            color: valid ? Colors.green : AppTheme.textHintColor,
          ),
        ),
      ],
    );
  }
}

class _CoordinatePickerDialog extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const _CoordinatePickerDialog({this.initialLatitude, this.initialLongitude});

  @override
  State<_CoordinatePickerDialog> createState() =>
      _CoordinatePickerDialogState();
}

class _CoordinatePickerDialogState extends State<_CoordinatePickerDialog> {
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  bool _isLocating = false;
  bool _isResolving = false;
  String? _resolvedAddress;
  String? _province;
  String? _city;
  String? _district;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(
      text: widget.initialLatitude?.toStringAsFixed(6) ?? '',
    );
    _lngController = TextEditingController(
      text: widget.initialLongitude?.toStringAsFixed(6) ?? '',
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) {
    return double.tryParse(controller.text.trim());
  }

  Future<void> _fillCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final location = await LocationService.instance.getCurrentLocation();
      if (location == null || !location.isSuccess) return;

      _latController.text = location.latitude.toStringAsFixed(6);
      _lngController.text = location.longitude.toStringAsFixed(6);
      await _resolveAddress();
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _resolveAddress() async {
    final lat = _parse(_latController);
    final lng = _parse(_lngController);
    if (lat == null || lng == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先输入有效的经纬度')));
      }
      return;
    }

    setState(() => _isResolving = true);
    try {
      final result = await LocationService.instance.getAddressFromLocation(
        lat,
        lng,
      );
      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('地址解析失败，请调整坐标后重试')));
        }
        return;
      }

      setState(() {
        _resolvedAddress = result['address']?.toString();
        _province = result['province']?.toString();
        _city = result['city']?.toString();
        _district = result['district']?.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isResolving = false);
      }
    }
  }

  void _confirm() {
    final lat = _parse(_latController);
    final lng = _parse(_lngController);
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写有效经纬度')));
      return;
    }
    Navigator.pop(context, {
      'latitude': lat,
      'longitude': lng,
      'address': _resolvedAddress ?? '',
      'province': _province,
      'city': _city,
      'district': _district,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 0.9.sw,
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '地图坐标选点',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _latController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: '纬度 (latitude)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10.h),
            TextField(
              controller: _lngController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: '经度 (longitude)',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLocating ? null : _fillCurrentLocation,
                    icon: _isLocating
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('当前位置'),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isResolving ? null : _resolveAddress,
                    icon: _isResolving
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.travel_explore),
                    label: const Text('解析地址'),
                  ),
                ),
              ],
            ),
            if (_resolvedAddress != null && _resolvedAddress!.isNotEmpty) ...[
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  _resolvedAddress!,
                  style: TextStyle(fontSize: 13.sp, color: Colors.green[700]),
                ),
              ),
            ],
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirm,
                    child: const Text('使用该点'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 地址搜索对话框
class _AddressSearchDialog extends StatefulWidget {
  @override
  State<_AddressSearchDialog> createState() => _AddressSearchDialogState();
}

class _AddressSearchDialogState extends State<_AddressSearchDialog> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final results = await LocationService.instance.searchAddress(keyword);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 0.9.sw,
        height: 0.7.sh,
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Text(
              '搜索地址',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            // 搜索框
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '输入地址关键词',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            SizedBox(height: 16.h),
            // 搜索结果
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                  ? Center(
                      child: Text(
                        '请输入关键词搜索地址',
                        style: TextStyle(color: Colors.grey, fontSize: 14.sp),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(result['name'] ?? ''),
                          subtitle: Text(result['address'] ?? ''),
                          onTap: () {
                            Navigator.pop(context, result);
                          },
                        );
                      },
                    ),
            ),
            // 取消按钮
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
