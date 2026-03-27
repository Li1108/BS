import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';

enum _LoginMode { user, nurse }

@RoutePage()
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _codeFocusNode = FocusNode();

  int _countdown = 0;
  Timer? _timer;
  bool _isSendingCode = false;
  bool _isSubmitting = false;
  _LoginMode _loginMode = _LoginMode.user;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _phoneFocusNode.dispose();
    _codeFocusNode.dispose();
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  bool _isValidPhone(String phone) => RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);

  bool get _canSendCode {
    final phone = _phoneController.text.trim();
    return _isValidPhone(phone) && _countdown == 0 && !_isSendingCode;
  }

  bool get _canSubmit {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    return _isValidPhone(phone) && code.length == 6 && !_isSubmitting;
  }

  bool get _isNurseMode => _loginMode == _LoginMode.nurse;

  Future<void> _sendVerificationCode() async {
    if (!_canSendCode) return;
    final phone = _phoneController.text.trim();

    setState(() => _isSendingCode = true);
    try {
      final success = await ref
          .read(authProvider.notifier)
          .sendVerificationCode(phone);

      if (success) {
        _startCountdown();
        _showSuccessSnackBar('验证码已发送，请注意查收短信');
        _codeFocusNode.requestFocus();
      } else {
        _showErrorSnackBar(ref.read(authProvider).errorMessage ?? '验证码发送失败');
      }
    } catch (_) {
      _showErrorSnackBar('网络异常，请检查网络后重试');
    } finally {
      if (mounted) {
        setState(() => _isSendingCode = false);
      }
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 0) {
        timer.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _login() async {
    if (!_canSubmit) return;
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      final success = await ref
          .read(authProvider.notifier)
          .loginWithPhone(
            phone,
            code,
            loginRole: _isNurseMode ? 'NURSE' : 'USER',
          );

      if (!success) {
        _showErrorSnackBar(ref.read(authProvider).errorMessage ?? '登录失败，请重试');
        return;
      }
      if (!mounted) return;

      final role = ref.read(userRoleProvider);

      if (_isNurseMode && role != UserRole.nurse) {
        await ref.read(authProvider.notifier).logout();
        _showErrorSnackBar('该账号不是护士身份，请先完成护士入驻审核');
        return;
      }

      _showSuccessSnackBar('登录成功，欢迎回来');
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      final verified = await ref
          .read(authProvider.notifier)
          .isCurrentUserRealNameVerified();
      if (!mounted) return;

      if (!verified) {
        context.router.replaceAll([const RealNameVerifyRoute()]);
        return;
      }

      if (role == UserRole.nurse) {
        context.router.replaceAll([const NurseHomeRoute()]);
      } else {
        context.router.replaceAll([const UserHomeRoute()]);
      }
    } catch (_) {
      _showErrorSnackBar('网络异常，请检查网络后重试');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8.w),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8.w),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withAlpha(30),
                AppTheme.backgroundColor,
                Colors.white,
              ],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 460.w),
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 12.h),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 24.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(245),
                        borderRadius: BorderRadius.circular(24.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 80.w,
                                    height: 80.w,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: BorderRadius.circular(22.r),
                                    ),
                                    child: Icon(
                                      Icons.local_hospital,
                                      size: 46.sp,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  Text(
                                    _isNurseMode ? '护士端登录' : '欢迎登录',
                                    style: TextStyle(
                                      fontSize: 28.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    _isNurseMode
                                        ? '仅护士账号可登录此入口'
                                        : '互联网+护理服务APP',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 14.h),
                            _buildModeSelector(),
                            SizedBox(height: 28.h),
                            _buildPhoneField(),
                            SizedBox(height: 4.h),
                            _buildFieldHint(
                              valid: _isValidPhone(
                                _phoneController.text.trim(),
                              ),
                              text: _isValidPhone(_phoneController.text.trim())
                                  ? '手机号格式正确'
                                  : '请输入中国大陆11位手机号',
                            ),
                            SizedBox(height: 16.h),
                            _buildCodeField(),
                            SizedBox(height: 4.h),
                            _buildFieldHint(
                              valid: _codeController.text.trim().length == 6,
                              text: _codeController.text.trim().length == 6
                                  ? '验证码格式正确'
                                  : '验证码为6位数字',
                            ),
                            SizedBox(height: 24.h),
                            _buildLoginButton(authState),
                            SizedBox(height: 14.h),
                            if (authState.errorMessage != null)
                              _buildErrorMessage(authState.errorMessage!),
                            SizedBox(height: 18.h),
                            _buildRegisterEntry(),
                            SizedBox(height: 12.h),
                            _buildNurseApplyGuide(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      focusNode: _phoneFocusNode,
      keyboardType: TextInputType.phone,
      maxLength: 11,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      autofillHints: const [AutofillHints.telephoneNumber],
      decoration: InputDecoration(
        labelText: '手机号',
        hintText: '请输入11位手机号',
        prefixIcon: const Icon(Icons.phone_android),
        counterText: '',
        suffixIcon: _phoneController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _phoneController.clear();
                  setState(() {});
                },
              )
            : null,
      ),
      onChanged: (_) => setState(() {}),
      validator: (value) {
        if (value == null || value.isEmpty) return '请输入手机号';
        if (!_isValidPhone(value)) return '请输入正确的11位手机号';
        return null;
      },
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _codeFocusNode.requestFocus(),
    );
  }

  Widget _buildCodeField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _codeController,
            focusNode: _codeFocusNode,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: const InputDecoration(
              labelText: '验证码',
              hintText: '请输入6位验证码',
              prefixIcon: Icon(Icons.security),
              counterText: '',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return '请输入验证码';
              if (value.length != 6) return '验证码为6位数字';
              return null;
            },
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
          ),
        ),
        SizedBox(width: 12.w),
        SizedBox(
          width: 120.w,
          height: 56.h,
          child: ElevatedButton(
            onPressed: _canSendCode ? _sendVerificationCode : null,
            child: _isSendingCode
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_countdown > 0 ? '${_countdown}s' : '获取验证码'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(AuthState authState) {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        onPressed: (authState.isLoading || !_canSubmit) ? null : _login,
        child: authState.isLoading
            ? SizedBox(
                width: 24.w,
                height: 24.w,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                _isNurseMode ? '护士登录' : '登录 / 注册',
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeChip(
              label: '用户',
              icon: Icons.person_outline,
              selected: _loginMode == _LoginMode.user,
              onTap: () => setState(() => _loginMode = _LoginMode.user),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _buildModeChip(
              label: '护士',
              icon: Icons.medical_services_outlined,
              selected: _loginMode == _LoginMode.nurse,
              onTap: () => setState(() => _loginMode = _LoginMode.nurse),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16.sp,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 20.sp),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700, fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterEntry() {
    if (_isNurseMode) {
      return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4.w,
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            size: 14.sp,
            color: AppTheme.textHintColor,
          ),
          Text(
            '护士登录仅支持已通过审核的护士账号',
            style: TextStyle(fontSize: 13.sp, color: AppTheme.textHintColor),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 14.sp,
          color: AppTheme.textHintColor,
        ),
        SizedBox(width: 4.w),
        Text(
          '新用户首次登录自动注册',
          style: TextStyle(fontSize: 13.sp, color: AppTheme.textHintColor),
        ),
      ],
    );
  }

  Widget _buildNurseApplyGuide() {
    final title = _isNurseMode
        ? '未通过审核请先使用“用户登录”，再到“我的”提交入驻申请'
        : '护士入驻路径：用户登录/注册 → 我的页面 → 申请成为护士';
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_outlined, color: Colors.green, size: 18.sp),
            SizedBox(width: 6.w),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
