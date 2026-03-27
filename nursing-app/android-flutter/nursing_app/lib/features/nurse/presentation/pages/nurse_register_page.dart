import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/widgets/commercial_ui_widgets.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../providers/nurse_provider.dart';

/// 护士注册页面
///
/// 护士需通过上传姓名、身份证件及护士执业证照片完成注册
/// 等待后台人工审核
/// 使用 flutter_image_compress 压缩图片到 1MB 以内
@RoutePage()
class NurseRegisterPage extends ConsumerStatefulWidget {
  const NurseRegisterPage({super.key});

  @override
  ConsumerState<NurseRegisterPage> createState() => _NurseRegisterPageState();
}

class _NurseRegisterPageState extends ConsumerState<NurseRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _realNameController = TextEditingController();
  final _idCardNoController = TextEditingController();
  final _licenseNoController = TextEditingController();
  final _hospitalController = TextEditingController();
  final _workYearsController = TextEditingController();
  final _skillDescController = TextEditingController();

  // 图片本地路径（压缩后）
  File? _idCardPhotoFront;
  File? _idCardPhotoBack;
  File? _certificatePhoto;
  File? _nursePhoto;

  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  bool _isValidIdCard(String value) {
    return RegExp(r'^\d{17}[\dXx]$').hasMatch(value);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = ref.read(authProvider);
      if (!authState.isAuthenticated) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先完成用户登录/注册，再进行护士入驻申请')));
        context.router.replaceAll([const LoginRoute()]);
      }
    });
  }

  @override
  void dispose() {
    _realNameController.dispose();
    _idCardNoController.dispose();
    _licenseNoController.dispose();
    _hospitalController.dispose();
    _workYearsController.dispose();
    _skillDescController.dispose();
    super.dispose();
  }

  /// 压缩图片
  ///
  /// 使用 flutter_image_compress 压缩图片
  /// 目标大小：1MB 以内
  Future<File?> _compressImage(File file) async {
    try {
      final filePath = file.path;
      final lastIndex = filePath.lastIndexOf('.');
      final ext = lastIndex >= 0 ? filePath.substring(lastIndex) : '.jpg';
      final targetPath = path.join(
        path.dirname(filePath),
        '${path.basenameWithoutExtension(filePath)}_compressed$ext',
      );

      // 获取原始文件大小
      final originalSize = await file.length();
      debugPrint(
        '原始图片大小: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      // 计算压缩质量
      int quality = 80;
      if (originalSize > 5 * 1024 * 1024) {
        quality = 50;
      } else if (originalSize > 3 * 1024 * 1024) {
        quality = 60;
      } else if (originalSize > 2 * 1024 * 1024) {
        quality = 70;
      }

      // 压缩图片
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 1080,
        minHeight: 1920,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        final compressedSize = await result.length();
        debugPrint(
          '压缩后图片大小: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB',
        );

        // 如果还是大于1MB，继续压缩
        if (compressedSize > 1024 * 1024) {
          final furtherResult = await FlutterImageCompress.compressAndGetFile(
            result.path,
            targetPath.replaceAll('_compressed', '_compressed2'),
            quality: 50,
            minWidth: 800,
            minHeight: 1200,
            format: CompressFormat.jpeg,
          );
          if (furtherResult != null) {
            return File(furtherResult.path);
          }
        }

        return File(result.path);
      }
      return file;
    } catch (e) {
      debugPrint('图片压缩失败: $e');
      return file;
    }
  }

  /// 选择并压缩图片
  Future<File?> _pickAndCompressImage(String type) async {
    try {
      // 检查相机权限（如果从相机拍摄）
      final permissionService = PermissionService.instance;

      // 弹窗选择来源
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
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

      // 检查权限
      if (source == ImageSource.camera) {
        final hasPermission = await permissionService
            .showCameraPermissionDialog(context);
        if (!hasPermission) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('需要相机权限才能拍照')));
          }
          return null;
        }
      }

      // 选择图片
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (image == null) return null;

      // 显示压缩中提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('正在压缩图片...'),
              ],
            ),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // 压缩图片
      final compressedFile = await _compressImage(File(image.path));

      return compressedFile;
    } catch (e) {
      debugPrint('选择图片失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('选择图片失败: $e')));
      }
      return null;
    }
  }

  /// 提交审核资料
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_idCardPhotoFront == null) {
      _showSnackBar('请上传身份证正面照片');
      return;
    }
    if (_idCardPhotoBack == null) {
      _showSnackBar('请上传身份证背面照片');
      return;
    }
    if (_certificatePhoto == null) {
      _showSnackBar('请上传护士执业证照片');
      return;
    }
    if (_nursePhoto == null) {
      _showSnackBar('请上传护士个人照片');
      return;
    }

    final confirm = await AppConfirmSheet.show(
      context: context,
      title: '确认提交审核资料',
      message:
          '姓名：${_realNameController.text.trim()}\n身份证：${_idCardNoController.text.trim()}\n执业证号：${_licenseNoController.text.trim()}\n所属医院：${_hospitalController.text.trim()}\n从业年限：${_workYearsController.text.trim()}年',
      confirmText: '确认提交',
      cancelText: '再检查',
      icon: Icons.verified_user_outlined,
    );
    if (!confirm) return;

    setState(() => _isLoading = true);

    try {
      final registerNotifier = ref.read(nurseRegisterProvider.notifier);

      // 更新表单字段
      registerNotifier.updateField(
        realName: _realNameController.text.trim(),
        idCardNo: _idCardNoController.text.trim(),
        licenseNo: _licenseNoController.text.trim(),
        hospital: _hospitalController.text.trim(),
        workYears: int.tryParse(_workYearsController.text.trim()) ?? 0,
        skillDesc: _skillDescController.text.trim(),
      );

      // 上传照片
      if (_idCardPhotoFront != null) {
        final frontUrl = await registerNotifier.uploadPhoto(
          _idCardPhotoFront!,
          'id_card_front',
        );
        if (frontUrl == null) {
          final uploadError = ref.read(nurseRegisterProvider).error;
          _showSnackBar(uploadError ?? '身份证正面上传失败，请检查网络后重试');
          return;
        }
      }
      if (_idCardPhotoBack != null) {
        final backUrl = await registerNotifier.uploadPhoto(
          _idCardPhotoBack!,
          'id_card_back',
        );
        if (backUrl == null) {
          final uploadError = ref.read(nurseRegisterProvider).error;
          _showSnackBar(uploadError ?? '身份证背面上传失败，请检查网络后重试');
          return;
        }
      }
      if (_certificatePhoto != null) {
        final certUrl = await registerNotifier.uploadPhoto(
          _certificatePhoto!,
          'certificate',
        );
        if (certUrl == null) {
          final uploadError = ref.read(nurseRegisterProvider).error;
          _showSnackBar(uploadError ?? '护士执业证上传失败，请检查网络后重试');
          return;
        }
      }
      if (_nursePhoto != null) {
        final photoUrl = await registerNotifier.uploadPhoto(
          _nursePhoto!,
          'nurse_photo',
        );
        if (photoUrl == null) {
          final uploadError = ref.read(nurseRegisterProvider).error;
          _showSnackBar(uploadError ?? '护士个人照片上传失败，请检查网络后重试');
          return;
        }
      }

      // 提交注册
      final success = await registerNotifier.submit();

      if (mounted) {
        if (success) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('提交成功'),
              content: const Text(
                '您的资料已提交审核，请耐心等待。\n审核结果将通过APP消息通知您。\n审核通过后需在“我的”页面签署护士入职协议。',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.router.maybePop();
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        } else {
          final state = ref.read(nurseRegisterProvider);
          _showSnackBar(state.error ?? '提交失败，请稍后重试');
          final retry = await AppConfirmSheet.show(
            context: context,
            title: '提交失败',
            message: state.error ?? '资料提交失败，请重试。',
            confirmText: '重试提交',
            cancelText: '稍后再试',
            icon: Icons.error_outline_rounded,
            iconBgColor: const Color(0x33F44336),
            iconColor: Colors.redAccent,
          );
          if (retry) {
            await _submit();
          }
        }
      }
    } catch (e) {
      _showSnackBar('提交失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Scaffold(
      appBar: AppBar(title: const Text('护士入驻申请')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 720.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 提示信息
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              '请如实填写信息并上传清晰的证件照片，审核通过后即可接单。',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 24.h),

                    // 真实姓名
                    TextFormField(
                      controller: _realNameController,
                      decoration: const InputDecoration(
                        labelText: '真实姓名',
                        hintText: '请输入您的真实姓名',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入真实姓名';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 4.h),
                    _buildFieldHint(
                      valid: _realNameController.text.trim().length >= 2,
                      text: _realNameController.text.trim().length >= 2
                          ? '姓名格式有效'
                          : '建议输入真实姓名',
                    ),

                    SizedBox(height: 16.h),

                    // 身份证号
                    TextFormField(
                      controller: _idCardNoController,
                      maxLength: 18,
                      decoration: const InputDecoration(
                        labelText: '身份证号',
                        hintText: '请输入18位身份证号',
                        prefixIcon: Icon(Icons.credit_card),
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入身份证号';
                        }
                        if (!_isValidIdCard(value)) {
                          return '请输入正确的18位身份证号';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 4.h),
                    _buildFieldHint(
                      valid: _isValidIdCard(_idCardNoController.text.trim()),
                      text: _isValidIdCard(_idCardNoController.text.trim())
                          ? '身份证号格式有效'
                          : '支持18位号码，末位可为X',
                    ),

                    SizedBox(height: 16.h),

                    // 护士执业证编号
                    TextFormField(
                      controller: _licenseNoController,
                      decoration: const InputDecoration(
                        labelText: '护士执业证编号',
                        hintText: '请输入护士执业证编号',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入护士执业证编号';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 4.h),
                    _buildFieldHint(
                      valid: _licenseNoController.text.trim().isNotEmpty,
                      text: _licenseNoController.text.trim().isNotEmpty
                          ? '证书编号已填写'
                          : '请输入护士执业证编号',
                    ),

                    SizedBox(height: 16.h),

                    // 所属医院/机构
                    TextFormField(
                      controller: _hospitalController,
                      decoration: const InputDecoration(
                        labelText: '所属医院/机构',
                        hintText: '请输入您所在的医院或机构名称',
                        prefixIcon: Icon(Icons.local_hospital_outlined),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入所属医院/机构';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 4.h),
                    _buildFieldHint(
                      valid: _hospitalController.text.trim().isNotEmpty,
                      text: _hospitalController.text.trim().isNotEmpty
                          ? '医院/机构已填写'
                          : '请填写所属医疗机构',
                    ),

                    SizedBox(height: 16.h),

                    // 从业年限
                    TextFormField(
                      controller: _workYearsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '从业年限（年）',
                        hintText: '请输入您的护理从业年限',
                        prefixIcon: Icon(Icons.work_history_outlined),
                        suffixText: '年',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入从业年限';
                        }
                        final years = int.tryParse(value);
                        if (years == null || years < 0 || years > 50) {
                          return '请输入有效的年限（0-50）';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 4.h),
                    _buildFieldHint(
                      valid:
                          int.tryParse(_workYearsController.text.trim()) !=
                          null,
                      text:
                          int.tryParse(_workYearsController.text.trim()) != null
                          ? '从业年限已填写'
                          : '请填写从业年限',
                    ),

                    SizedBox(height: 16.h),

                    // 技能描述
                    TextFormField(
                      controller: _skillDescController,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: '技能描述（可选）',
                        hintText: '请简要描述您擅长的护理技能和服务项目',
                        prefixIcon: Icon(Icons.description_outlined),
                        alignLabelWithHint: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: 4.h),
                    _buildFieldHint(
                      valid: _skillDescController.text.trim().isNotEmpty,
                      text: _skillDescController.text.trim().isNotEmpty
                          ? '技能描述已填写'
                          : '可选填写您的专业技能',
                    ),

                    SizedBox(height: 24.h),

                    // 证件照片上传标题
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8.w,
                      runSpacing: 4.h,
                      children: [
                        Text(
                          '证件照片',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimaryColor,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '(图片将自动压缩)',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.textHintColor,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 12.h),

                    // 身份证正面
                    _buildPhotoUploader(
                      title: '身份证正面（人像面）',
                      subtitle: '请确保姓名、身份证号清晰可见',
                      required: true,
                      imageFile: _idCardPhotoFront,
                      onTap: () async {
                        final file = await _pickAndCompressImage('id_front');
                        if (file != null) {
                          setState(() => _idCardPhotoFront = file);
                        }
                      },
                    ),

                    SizedBox(height: 12.h),

                    // 身份证背面
                    _buildPhotoUploader(
                      title: '身份证背面（国徽面）',
                      subtitle: '请完整拍摄有效期与发证机关信息',
                      required: true,
                      imageFile: _idCardPhotoBack,
                      onTap: () async {
                        final file = await _pickAndCompressImage('id_back');
                        if (file != null) {
                          setState(() => _idCardPhotoBack = file);
                        }
                      },
                    ),

                    SizedBox(height: 12.h),

                    // 护士执业证
                    _buildPhotoUploader(
                      title: '护士执业证',
                      subtitle: '证件编号与签发信息需清晰可辨认',
                      required: true,
                      imageFile: _certificatePhoto,
                      onTap: () async {
                        final file = await _pickAndCompressImage('certificate');
                        if (file != null) {
                          setState(() => _certificatePhoto = file);
                        }
                      },
                    ),

                    SizedBox(height: 12.h),

                    // 护士个人照片
                    _buildPhotoUploader(
                      title: '护士个人照片',
                      subtitle: '请上传清晰的个人照片，用于身份展示',
                      required: true,
                      imageFile: _nursePhoto,
                      onTap: () async {
                        final file = await _pickAndCompressImage('nurse_photo');
                        if (file != null) {
                          setState(() => _nursePhoto = file);
                        }
                      },
                    ),

                    SizedBox(height: 32.h),

                    // 提交按钮
                    SizedBox(
                      width: double.infinity,
                      height: screenWidth < 360 ? 46.h : 50.h,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? SizedBox(
                                width: 24.w,
                                height: 24.w,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text('提交审核', style: TextStyle(fontSize: 18.sp)),
                      ),
                    ),

                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建照片上传组件
  Widget _buildPhotoUploader({
    required String title,
    required String subtitle,
    required bool required,
    required File? imageFile,
    required VoidCallback onTap,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final photoHeight = screenWidth < 360 ? 132.h : 152.h;
    final uploaded = imageFile != null;

    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              if (required)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Text(
                    '必传',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12.sp, color: AppTheme.textHintColor),
          ),
          SizedBox(height: 10.h),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: photoHeight,
              decoration: BoxDecoration(
                border: Border.all(
                  color: uploaded ? Colors.green : AppTheme.dividerColor,
                  width: uploaded ? 1.8 : 1,
                ),
                borderRadius: BorderRadius.circular(10.r),
                color: Colors.grey.shade50,
              ),
              child: uploaded
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(9.r),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            imageFile,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 40.sp,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                          Positioned(
                            left: 8.w,
                            top: 8.h,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 3.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(999.r),
                              ),
                              child: Text(
                                '已上传',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8.w,
                            bottom: 8.h,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                '重新选择',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 36.sp,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '点击上传',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppTheme.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '支持拍照或相册选择',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppTheme.textHintColor,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldHint({required bool valid, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          valid
              ? Icons.check_circle_outline_rounded
              : Icons.info_outline_rounded,
          size: 14.sp,
          color: valid ? Colors.green : AppTheme.textHintColor,
        ),
        SizedBox(width: 4.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.sp,
              color: valid ? Colors.green : AppTheme.textHintColor,
            ),
          ),
        ),
      ],
    );
  }
}
