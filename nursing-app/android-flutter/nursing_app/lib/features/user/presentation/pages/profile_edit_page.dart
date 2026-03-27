import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/user_profile_provider.dart';

/// 用户个人信息编辑页面
@RoutePage()
class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nicknameController;
  late TextEditingController _realNameController;
  late TextEditingController _idCardNoController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _emergencyPhoneController;
  int _selectedGender = 0; // 0: 未设置, 1: 男, 2: 女
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  final ImagePicker _picker = ImagePicker();
  String? _avatarPreviewUrl;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController();
    _realNameController = TextEditingController();
    _idCardNoController = TextEditingController();
    _emergencyContactController = TextEditingController();
    _emergencyPhoneController = TextEditingController();

    // 加载用户资料
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    await ref.read(userProfileProvider.notifier).loadProfile();
    final profile = ref.read(userProfileProvider).profile;
    if (profile != null) {
      setState(() {
        _nicknameController.text = profile.nickname ?? '';
        _realNameController.text = profile.realName ?? '';
        _idCardNoController.text = profile.idCardNo ?? '';
        _emergencyContactController.text = profile.emergencyContact ?? '';
        _emergencyPhoneController.text = profile.emergencyPhone ?? '';
        _selectedGender = profile.gender ?? 0;
        _avatarPreviewUrl = profile.avatarUrl;
      });
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingAvatar = true);
    final avatarUrl = await ref
        .read(userProfileProvider.notifier)
        .uploadAvatar(File(picked.path));
    if (!mounted) return;
    setState(() => _isUploadingAvatar = false);

    if (avatarUrl == null || avatarUrl.isEmpty) {
      final error = ref.read(userProfileProvider).error ?? '头像上传失败';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _avatarPreviewUrl = avatarUrl);
    final authUser = ref.read(authProvider).user;
    if (authUser != null) {
      ref
          .read(authProvider.notifier)
          .updateUser(authUser.copyWith(avatar: avatarUrl));
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('头像已更新')));
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _realNameController.dispose();
    _idCardNoController.dispose();
    _emergencyContactController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  bool _isValidIdCardNo(String value) {
    final text = value.trim();
    final pattern = RegExp(
      r'^[1-9]\d{5}(18|19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}[0-9Xx]$|^[1-9]\d{7}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}$',
    );
    return pattern.hasMatch(text);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final data = <String, dynamic>{};

    if (_nicknameController.text.isNotEmpty) {
      data['nickname'] = _nicknameController.text;
    }
    if (_realNameController.text.isNotEmpty) {
      data['realName'] = _realNameController.text;
    }
    if (_idCardNoController.text.trim().isNotEmpty) {
      data['idCardNo'] = _idCardNoController.text.trim();
    }
    if (_emergencyContactController.text.isNotEmpty) {
      data['emergencyContact'] = _emergencyContactController.text;
    }
    if (_emergencyPhoneController.text.isNotEmpty) {
      data['emergencyPhone'] = _emergencyPhoneController.text;
    }
    data['gender'] = _selectedGender;

    final success = await ref
        .read(userProfileProvider.notifier)
        .updateProfile(data);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      final authUser = ref.read(authProvider).user;
      if (authUser != null) {
        ref
            .read(authProvider.notifier)
            .updateUser(
              authUser.copyWith(
                username: _nicknameController.text.trim().isEmpty
                    ? authUser.username
                    : _nicknameController.text.trim(),
                avatar: _avatarPreviewUrl ?? authUser.avatar,
              ),
            );
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存成功')));
      context.router.maybePop(true);
    } else {
      final error = ref.read(userProfileProvider).error ?? '保存失败';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _handleSave,
            child: _isLoading
                ? SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: profileState.isLoading && profileState.profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 头像上传
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              GestureDetector(
                                onTap: _isUploadingAvatar
                                    ? null
                                    : _pickAndUploadAvatar,
                                child: CircleAvatar(
                                  radius: 50.r,
                                  backgroundColor: AppTheme.primaryColor
                                      .withValues(alpha: 0.12),
                                  child: (_avatarPreviewUrl ?? '').isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            _avatarPreviewUrl!,
                                            fit: BoxFit.cover,
                                            width: 100.r,
                                            height: 100.r,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Icon(
                                                      Icons.person,
                                                      size: 50.sp,
                                                      color:
                                                          AppTheme.primaryColor,
                                                    ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.person,
                                          size: 50.sp,
                                          color: AppTheme.primaryColor,
                                        ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 28.w,
                                  height: 28.w,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: _isUploadingAvatar
                                      ? Padding(
                                          padding: EdgeInsets.all(6.w),
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                        )
                                      : Icon(
                                          Icons.camera_alt,
                                          size: 14.sp,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            _isUploadingAvatar ? '正在上传头像...' : '点击头像可上传',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppTheme.textHintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),

                    // 手机号（只读）
                    _buildSectionTitle('基本信息'),
                    _buildReadOnlyField(
                      '手机号',
                      profileState.profile?.phone ?? '',
                    ),
                    SizedBox(height: 16.h),

                    // 昵称
                    _buildTextField(
                      controller: _nicknameController,
                      label: '昵称',
                      hint: '请输入昵称',
                      icon: Icons.person_outline,
                    ),
                    SizedBox(height: 16.h),

                    // 性别
                    Text(
                      '性别',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    _buildGenderSelector(),
                    SizedBox(height: 24.h),

                    // 实名信息
                    _buildSectionTitle('实名信息'),
                    _buildTextField(
                      controller: _realNameController,
                      label: '真实姓名',
                      hint: '请输入真实姓名',
                      icon: Icons.badge_outlined,
                    ),
                    SizedBox(height: 16.h),
                    _buildTextField(
                      controller: _idCardNoController,
                      label: '身份证号',
                      hint: '请输入身份证号',
                      icon: Icons.credit_card_outlined,
                      keyboardType: TextInputType.text,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx]')),
                        LengthLimitingTextInputFormatter(18),
                      ],
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty) return null;
                        if (!_isValidIdCardNo(text)) {
                          return '请输入正确的身份证号码';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24.h),

                    // 紧急联系人
                    _buildSectionTitle('紧急联系人'),
                    _buildTextField(
                      controller: _emergencyContactController,
                      label: '联系人姓名',
                      hint: '请输入紧急联系人姓名',
                      icon: Icons.contacts_outlined,
                    ),
                    SizedBox(height: 16.h),
                    _buildTextField(
                      controller: _emergencyPhoneController,
                      label: '联系人电话',
                      hint: '请输入紧急联系人电话',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 14.sp, color: AppTheme.textPrimaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20.sp),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppTheme.primaryColor),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Row(
      children: [
        _buildGenderOption(0, '未设置', Icons.help_outline),
        SizedBox(width: 12.w),
        _buildGenderOption(1, '男', Icons.male),
        SizedBox(width: 12.w),
        _buildGenderOption(2, '女', Icons.female),
      ],
    );
  }

  Widget _buildGenderOption(int value, String label, IconData icon) {
    final isSelected = _selectedGender == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedGender = value),
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.12)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18.sp,
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
              ),
              SizedBox(width: 4.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
