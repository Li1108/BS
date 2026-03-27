import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/address_model.dart';
import '../../providers/address_provider.dart';

/// 地址列表页面
///
/// 功能：
/// 1. 展示用户保存的地址列表
/// 2. 支持添加、编辑、删除地址
/// 3. 设置默认地址
/// 4. 选择地址返回
@RoutePage()
class AddressListPage extends ConsumerStatefulWidget {
  /// 是否为选择模式（从下单页面跳转过来）
  final bool selectMode;

  const AddressListPage({super.key, this.selectMode = false});

  @override
  ConsumerState<AddressListPage> createState() => _AddressListPageState();
}

class _AddressListPageState extends ConsumerState<AddressListPage> {
  @override
  void initState() {
    super.initState();
    // 加载地址列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(addressListProvider.notifier).loadAddresses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addressListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectMode ? '选择地址' : '我的地址'),
        centerTitle: true,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.addresses.isEmpty
          ? _buildEmptyView()
          : ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: state.addresses.length,
              itemBuilder: (context, index) {
                final address = state.addresses[index];
                return _buildAddressItem(address);
              },
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 80.sp,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            '暂无地址',
            style: TextStyle(
              fontSize: 16.sp,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '点击下方按钮添加地址',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressItem(AddressModel address) {
    final isDefault = address.isDefaultAddress;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        onTap: () {
          if (widget.selectMode) {
            // 选择模式：返回选中的地址
            context.router.maybePop(address);
          }
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 联系人信息
              Row(
                children: [
                  Text(
                    address.contactName,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    _maskPhone(address.contactPhone),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                  const Spacer(),
                  if (isDefault)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        '默认',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8.h),
              // 地址信息
              Row(
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
                      address.address,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              // 经纬度信息（调试用，可隐藏）
              if (address.latitude != null && address.longitude != null)
                Padding(
                  padding: EdgeInsets.only(top: 4.h, left: 20.w),
                  child: Text(
                    '坐标: ${address.latitude!.toStringAsFixed(6)}, ${address.longitude!.toStringAsFixed(6)}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  ),
                ),
              SizedBox(height: 12.h),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!isDefault)
                    TextButton.icon(
                      onPressed: () => _setDefault(address),
                      icon: Icon(Icons.check_circle_outline, size: 18.sp),
                      label: const Text('设为默认'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () => _editAddress(address),
                    icon: Icon(Icons.edit_outlined, size: 18.sp),
                    label: const Text('编辑'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _deleteAddress(address),
                    icon: Icon(Icons.delete_outline, size: 18.sp),
                    label: const Text('删除'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton.icon(
            onPressed: _addAddress,
            icon: const Icon(Icons.add),
            label: const Text('添加新地址'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 手机号脱敏
  String _maskPhone(String phone) {
    if (phone.length >= 11) {
      return '${phone.substring(0, 3)}****${phone.substring(7)}';
    }
    return phone;
  }

  /// 添加地址
  void _addAddress() async {
    final result = await context.router.push(AddressEditRoute());
    if (result == true) {
      // 刷新列表
      ref.read(addressListProvider.notifier).loadAddresses();
    }
  }

  /// 编辑地址
  void _editAddress(AddressModel address) async {
    final result = await context.router.push(
      AddressEditRoute(addressId: address.id),
    );
    if (result == true) {
      // 刷新列表
      ref.read(addressListProvider.notifier).loadAddresses();
    }
  }

  /// 删除地址
  void _deleteAddress(AddressModel address) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除地址'),
        content: const Text('确定要删除这个地址吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final success = await ref
                  .read(addressListProvider.notifier)
                  .deleteAddress(address.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? '删除成功' : '删除失败'),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 设为默认
  void _setDefault(AddressModel address) async {
    final success = await ref
        .read(addressListProvider.notifier)
        .setDefault(address.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '已设为默认地址' : '设置失败'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}
