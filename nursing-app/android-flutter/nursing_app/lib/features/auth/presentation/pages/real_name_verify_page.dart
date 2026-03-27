import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/user/providers/user_profile_provider.dart';

@RoutePage()
class RealNameVerifyPage extends ConsumerStatefulWidget {
  const RealNameVerifyPage({super.key});

  @override
  ConsumerState<RealNameVerifyPage> createState() => _RealNameVerifyPageState();
}

class _RealNameVerifyPageState extends ConsumerState<RealNameVerifyPage> {
  final _formKey = GlobalKey<FormState>();
  final _realNameController = TextEditingController();
  final _idCardNoController = TextEditingController();
  final _realNameFocusNode = FocusNode();
  final _idCardNoFocusNode = FocusNode();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 加载用户资料，如果已有实名信息则填充
    _loadUserProfile();
  }

  @override
  void dispose() {
    _realNameController.dispose();
    _idCardNoController.dispose();
    _realNameFocusNode.dispose();
    _idCardNoFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    await ref.read(userProfileProvider.notifier).loadProfile();
    final profile = ref.read(userProfileProvider).profile;
    if (profile != null) {
      if (profile.realName != null && profile.realName!.isNotEmpty) {
        _realNameController.text = profile.realName!;
      }
      if (profile.idCardNo != null && profile.idCardNo!.isNotEmpty) {
        _idCardNoController.text = profile.idCardNo!;
      }
    }
  }

  bool _isValidRealName(String name) {
    // 中文姓名验证：2-4个中文字符
    return RegExp(r'^[\u4e00-\u9fa5]{2,4}$').hasMatch(name);
  }

  bool _isValidIdCardNo(String idCardNo) {
    // 简单的身份证号格式验证
    // 15位或18位数字，最后一位可以是X
    return RegExp(
      r'^[1-9]\d{5}(18|19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}[0-9Xx]$|^[1-9]\d{7}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}$',
    ).hasMatch(idCardNo);
  }

  bool get _canSubmit {
    final realName = _realNameController.text.trim();
    final idCardNo = _idCardNoController.text.trim();
    return _isValidRealName(realName) &&
        _isValidIdCardNo(idCardNo) &&
        !_isSubmitting;
  }

  Future<void> _submitVerification() async {
    if (!_canSubmit) return;

    final realName = _realNameController.text.trim();
    final idCardNo = _idCardNoController.text.trim();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final success = await ref
          .read(authProvider.notifier)
          .verifyRealName(realName: realName, idCardNo: idCardNo);

      if (success) {
        final role = ref.read(userRoleProvider);
        if (mounted) {
          if (role == UserRole.nurse) {
            context.router.replaceAll([const NurseHomeRoute()]);
          } else {
            context.router.replaceAll([const UserHomeRoute()]);
          }
        }
      } else {
        setState(() {
          _errorMessage = ref.read(authProvider).errorMessage ?? '实名认证失败，请稍后重试';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('实名认证'),
        automaticallyImplyLeading: false,
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题和说明
                Text(
                  '请完成实名认证',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '根据国家相关规定，使用本服务需要进行实名认证',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                SizedBox(height: 32.h),

                // 错误信息显示
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: AppTheme.errorColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ),
                if (_errorMessage != null) SizedBox(height: 16.h),

                // 真实姓名输入
                Text(
                  '真实姓名',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _realNameController,
                  focusNode: _realNameFocusNode,
                  decoration: InputDecoration(
                    hintText: '请输入您的真实姓名',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: AppTheme.textSecondaryColor,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(
                        color: AppTheme.dividerColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(
                        color: AppTheme.dividerColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    filled: true,
                    fillColor: AppTheme.cardColor,
                  ),
                  style: TextStyle(fontSize: 16.sp),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入真实姓名';
                    }
                    if (!_isValidRealName(value.trim())) {
                      return '请输入2-4个中文字符的真实姓名';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _idCardNoFocusNode.requestFocus(),
                ),
                SizedBox(height: 24.h),

                // 身份证号输入
                Text(
                  '身份证号',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _idCardNoController,
                  focusNode: _idCardNoFocusNode,
                  decoration: InputDecoration(
                    hintText: '请输入您的身份证号码',
                    prefixIcon: Icon(
                      Icons.credit_card_outlined,
                      color: AppTheme.textSecondaryColor,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(
                        color: AppTheme.dividerColor,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(
                        color: AppTheme.dividerColor,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    filled: true,
                    fillColor: AppTheme.cardColor,
                  ),
                  style: TextStyle(fontSize: 16.sp),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx]')),
                  ],
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入身份证号';
                    }
                    if (!_isValidIdCardNo(value.trim())) {
                      return '请输入正确的身份证号码';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _submitVerification(),
                ),
                SizedBox(height: 8.h),
                Text(
                  '请确保身份证号码准确无误，认证后不可修改',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textHintColor,
                  ),
                ),
                SizedBox(height: 40.h),

                // 提交按钮
                SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _submitVerification : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _canSubmit
                          ? AppTheme.primaryColor
                          : AppTheme.textHintColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 24.w,
                            height: 24.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            '提交认证',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 16.h),

                // 隐私声明
                Text(
                  '我们承诺将严格保护您的个人信息安全，仅用于身份验证目的',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textHintColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
