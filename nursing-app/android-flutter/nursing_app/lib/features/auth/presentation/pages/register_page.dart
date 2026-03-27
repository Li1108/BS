import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/commercial_ui_widgets.dart';

/// 用户注册页面
///
/// 支持手机号验证码注册
@RoutePage()
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _usernameController = TextEditingController();

  int _countdown = 0;
  Timer? _timer;
  bool _isSendingCode = false;

  bool _isValidPhone(String phone) => RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _usernameController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /// 发送验证码
  Future<void> _sendVerificationCode() async {
    if (_isSendingCode || _countdown > 0) return;

    final phone = _phoneController.text.trim();

    if (!_isValidPhone(phone)) {
      _showSnackBar('请输入正确的手机号');
      return;
    }

    setState(() => _isSendingCode = true);

    final success = await ref
        .read(authProvider.notifier)
        .sendVerificationCode(phone);

    if (!mounted) return;

    if (success) {
      setState(() => _countdown = 60);

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_countdown > 0) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          setState(() => _countdown--);
        } else {
          timer.cancel();
        }
      });

      _showSnackBar('验证码已发送');
    } else {
      _showSnackBar(ref.read(authProvider).errorMessage ?? '验证码发送失败');
    }

    if (mounted) {
      setState(() => _isSendingCode = false);
    }
  }

  /// 注册
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    final username = _usernameController.text.trim();

    final confirm = await AppConfirmSheet.show(
      context: context,
      title: '确认注册',
      message: '昵称：$username\n手机号：$phone\n注册成功后将自动登录。',
      confirmText: '确认注册',
      cancelText: '再看看',
      icon: Icons.person_add_alt_1_outlined,
    );
    if (!confirm || !mounted) return;

    final success = await ref
        .read(authProvider.notifier)
        .register(phone: phone, code: code, username: username, role: 'USER');

    if (success && mounted) {
      final verified = await ref
          .read(authProvider.notifier)
          .isCurrentUserRealNameVerified();
      if (!mounted) return;

      if (!verified) {
        context.router.replaceAll([const RealNameVerifyRoute()]);
      } else {
        context.router.replaceAll([const UserHomeRoute()]);
      }
    } else if (mounted) {
      await AppConfirmSheet.show(
        context: context,
        title: '注册失败',
        message: ref.read(authProvider).errorMessage ?? '注册未成功，请检查验证码并重试。',
        confirmText: '知道了',
        cancelText: '关闭',
        icon: Icons.error_outline_rounded,
        iconBgColor: const Color(0x33F44336),
        iconColor: Colors.redAccent,
      );
    }
  }

  bool get _canSendCode {
    return _isValidPhone(_phoneController.text.trim()) &&
        _countdown == 0 &&
        !_isSendingCode;
  }

  bool get _canSubmit {
    return _usernameController.text.trim().length >= 2 &&
        _isValidPhone(_phoneController.text.trim()) &&
        _codeController.text.trim().length == 6;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('用户注册')),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 32.h),

                  // 用户名输入框
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: '昵称',
                      hintText: '请输入您的昵称',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入昵称';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 4.h),
                  _buildFieldHint(
                    valid: _usernameController.text.trim().length >= 2,
                    text: _usernameController.text.trim().length >= 2
                        ? '昵称长度可用'
                        : '建议至少2个字符',
                  ),

                  SizedBox(height: 16.h),

                  // 手机号输入框
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      labelText: '手机号',
                      hintText: '请输入手机号',
                      prefixIcon: Icon(Icons.phone_android),
                      counterText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入手机号';
                      }
                      if (!_isValidPhone(value)) {
                        return '请输入正确的手机号';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 4.h),
                  _buildFieldHint(
                    valid: _isValidPhone(_phoneController.text.trim()),
                    text: _isValidPhone(_phoneController.text.trim())
                        ? '手机号格式正确'
                        : '请输入中国大陆11位手机号',
                  ),

                  SizedBox(height: 16.h),

                  // 验证码输入框
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          autofillHints: const [AutofillHints.oneTimeCode],
                          decoration: const InputDecoration(
                            labelText: '验证码',
                            hintText: '请输入验证码',
                            prefixIcon: Icon(Icons.security),
                            counterText: '',
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入验证码';
                            }
                            if (value.length != 6) {
                              return '验证码为6位数字';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 12.w),
                      SizedBox(
                        width: 120.w,
                        child: ElevatedButton(
                          onPressed: _canSendCode
                              ? _sendVerificationCode
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !_canSendCode
                                ? Colors.grey
                                : Theme.of(context).primaryColor,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                          ),
                          child: Text(
                            _isSendingCode
                                ? '发送中...'
                                : (_countdown > 0 ? '${_countdown}s' : '获取验证码'),
                            style: TextStyle(fontSize: 14.sp),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  _buildFieldHint(
                    valid: _codeController.text.trim().length == 6,
                    text: _codeController.text.trim().length == 6
                        ? '验证码格式正确'
                        : '验证码为6位数字',
                  ),

                  SizedBox(height: 32.h),

                  // 注册按钮
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: (authState.isLoading || !_canSubmit)
                          ? null
                          : _register,
                      child: authState.isLoading
                          ? SizedBox(
                              width: 24.w,
                              height: 24.w,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text('注册', style: TextStyle(fontSize: 18.sp)),
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // 错误提示
                  if (authState.errorMessage != null)
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              authState.errorMessage!,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 24.h),

                  // 登录入口
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '已有账号？',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.router.maybePop();
                        },
                        child: Text(
                          '立即登录',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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
