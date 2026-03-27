import 'package:dio/dio.dart';

import '../../../../core/network/http_client.dart';
import '../../../../core/utils/error_mapper.dart';
import '../models/user_model.dart';

/// 认证仓库
///
/// 处理用户认证相关的 API 请求
class AuthRepository {
  final HttpClient _http = HttpClient.instance;

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool _toBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return fallback;
  }

  Map<String, dynamic> _normalizeUser(Map<String, dynamic> source) {
    return {
      'id': _toInt(source['id'] ?? source['user_id'] ?? source['userId']),
      'username':
          source['username']?.toString() ??
          source['nickname']?.toString() ??
          source['phone']?.toString() ??
          '',
      'phone': source['phone']?.toString() ?? '',
      'avatar':
          source['avatar']?.toString() ??
          source['avatar_url']?.toString() ??
          '',
      'role': source['role']?.toString() ?? 'USER',
      'status': _toInt(source['status']) ?? 1,
      'created_at':
          source['created_at']?.toString() ?? source['create_time']?.toString(),
      'updated_at':
          source['updated_at']?.toString() ?? source['update_time']?.toString(),
    };
  }

  /// 发送短信验证码
  ///
  /// [phone] 手机号
  Future<bool> sendVerificationCode(String phone) async {
    try {
      final response = await _http.post(
        '/auth/sendCode',
        data: {'phone': phone},
      );

      final result = ApiResponse.fromJson(response.data, null);
      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '验证码发送失败'));
    }
  }

  /// 手机号验证码登录
  ///
  /// [phone] 手机号
  /// [code] 验证码
  ///
  /// 后端会验证验证码是否正确，并检查账户状态
  /// 如果账户被禁用（status=0），后端会返回相应错误
  Future<LoginResponse> loginWithPhone(
    String phone,
    String code, {
    String role = 'USER',
  }) async {
    try {
      final response = await _http.post(
        '/auth/login',
        data: {'phone': phone, 'code': code, 'role': role},
      );

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        // 检查是否是账户禁用错误
        final message = result.message.isNotEmpty ? result.message : '登录失败';
        if (message.contains('禁用') || message.contains('封禁')) {
          throw AccountDisabledException(message);
        }
        throw Exception(message);
      }

      final loginData = result.data!;
      final token = loginData['token']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('登录成功但未返回 token');
      }

      Map<String, dynamic> userPayload = {};
      try {
        final meResp = await _http.get(
          '/auth/me',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
        final meResult = ApiResponse<Map<String, dynamic>>.fromJson(
          meResp.data,
          (data) => data as Map<String, dynamic>,
        );
        if (meResult.isSuccess && meResult.data != null) {
          userPayload = Map<String, dynamic>.from(meResult.data!);
        }
      } catch (_) {
        // 使用登录接口最小数据兜底
      }

      userPayload = {
        ...userPayload,
        'id': userPayload['id'] ?? loginData['user_id'] ?? loginData['userId'],
        'phone': userPayload['phone'] ?? phone,
        'role': userPayload['role'] ?? loginData['role'],
      };

      final normalizedUser = _normalizeUser(userPayload);
      final loginResponse = LoginResponse(
        user: UserModel.fromJson(normalizedUser),
        token: token,
        realNameVerified: _toBool(loginData['realNameVerified']),
      );

      // 前端再次校验账户状态
      if (loginResponse.user.status == 0) {
        throw AccountDisabledException('您的账户已被禁用，请联系客服处理');
      }

      return loginResponse;
    } catch (e) {
      if (e is AccountDisabledException) rethrow;
      throw Exception(normalizeErrorMessage(e, fallback: '登录失败'));
    }
  }

  /// 密码登录
  ///
  /// [phone] 手机号
  /// [password] 密码
  Future<LoginResponse> loginWithPassword(String phone, String password) async {
    throw Exception('当前后端未开放用户密码登录，请使用验证码登录');
  }

  /// 用户注册
  ///
  /// [phone] 手机号
  /// [code] 验证码
  /// [username] 用户名
  /// [role] 角色 (USER/NURSE)
  Future<LoginResponse> register({
    required String phone,
    required String code,
    required String username,
    String role = 'USER',
  }) async {
    final login = await loginWithPhone(phone, code);
    if (username.trim().isNotEmpty) {
      try {
        await _http.put(
          '/user/profile',
          data: {'nickname': username.trim()},
          options: Options(headers: {'Authorization': 'Bearer ${login.token}'}),
        );
      } catch (_) {
        // 注册后昵称更新失败不影响登录流程
      }
    }
    return login;
  }

  /// 护士注册（提交审核资料）
  ///
  /// [userId] 用户ID
  /// [realName] 真实姓名
  /// [idCardNo] 身份证号
  /// [idCardPhotoFront] 身份证正面照片URL
  /// [idCardPhotoBack] 身份证背面照片URL
  /// [certificatePhoto] 执业证照片URL
  Future<bool> registerNurse({
    required int userId,
    required String realName,
    required String idCardNo,
    required String idCardPhotoFront,
    required String idCardPhotoBack,
    required String certificatePhoto,
    String? serviceArea,
  }) async {
    try {
      final response = await _http.post(
        '/nurse/register',
        data: {
          'user_id': userId,
          'nurse_name': realName,
          'id_card_no': idCardNo,
          'id_card_front_url': idCardPhotoFront,
          'id_card_back_url': idCardPhotoBack,
          'license_no': idCardNo,
          'license_url': certificatePhoto,
          'nurse_photo_url': certificatePhoto,
          if (serviceArea != null && serviceArea.isNotEmpty)
            'skill_desc': '服务区域：$serviceArea',
        },
      );

      final result = ApiResponse.fromJson(response.data, null);
      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '护士注册失败'));
    }
  }

  /// 获取当前用户信息
  Future<UserModel> getCurrentUser() async {
    try {
      final response = await _http.get('/auth/me');

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      return UserModel.fromJson(_normalizeUser(result.data!));
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '获取用户信息失败'));
    }
  }

  /// 获取护士档案信息
  Future<NurseProfileModel> getNurseProfile() async {
    try {
      final response = await _http.get('/nurse/profile');

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      final raw = result.data!;
      final normalized = <String, dynamic>{
        'user_id': _toInt(raw['user_id'] ?? raw['userId'] ?? raw['id']) ?? 0,
        'real_name':
            raw['real_name']?.toString() ?? raw['nurse_name']?.toString() ?? '',
        'id_card_no': raw['id_card_no']?.toString(),
        'id_card_photo_front':
            raw['id_card_photo_front']?.toString() ??
            raw['id_card_front_url']?.toString(),
        'id_card_photo_back':
            raw['id_card_photo_back']?.toString() ??
            raw['id_card_back_url']?.toString(),
        'certificate_photo':
            raw['certificate_photo']?.toString() ??
            raw['license_url']?.toString(),
        'audit_status': _toInt(raw['audit_status']) ?? 0,
        'audit_reason':
            raw['audit_reason']?.toString() ?? raw['audit_remark']?.toString(),
        'work_mode': _toInt(raw['work_mode'] ?? raw['accept_enabled']) ?? 0,
        'balance': raw['balance'],
        'rating': raw['rating'],
        'service_area':
            raw['hospital']?.toString() ??
            raw['service_area']?.toString() ??
            raw['skill_desc']?.toString(),
      };
      return NurseProfileModel.fromJson(normalized);
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '获取护士档案失败'));
    }
  }

  /// 更新用户信息
  Future<bool> updateProfile({String? username, String? avatar}) async {
    return updateUserProfile(nickname: username, avatarUrl: avatar);
  }

  /// 获取用户完整个人资料
  Future<Map<String, dynamic>> getUserProfileDetail() async {
    try {
      final response = await _http.get('/user/profile');
      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      return Map<String, dynamic>.from(result.data!);
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '获取个人资料失败'));
    }
  }

  /// 更新用户完整个人资料
  Future<bool> updateUserProfile({
    String? nickname,
    String? avatarUrl,
    int? gender,
    String? realName,
    String? emergencyContact,
    String? emergencyPhone,
  }) async {
    try {
      final payload = <String, dynamic>{
        'nickname': nickname,
        'avatarUrl': avatarUrl,
        'gender': gender,
        'realName': realName,
        'emergencyContact': emergencyContact,
        'emergencyPhone': emergencyPhone,
      }..removeWhere((_, value) => value == null);

      if (payload.isEmpty) {
        return true;
      }

      final response = await _http.put('/user/profile', data: payload);

      final result = ApiResponse.fromJson(response.data, null);
      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '更新个人信息失败'));
    }
  }

  /// 提交实名认证
  Future<bool> verifyRealName({
    required String realName,
    required String idCardNo,
  }) async {
    try {
      final response = await _http.post(
        '/user/real-name-verify',
        data: {'realName': realName, 'idCardNo': idCardNo},
      );
      final result = ApiResponse.fromJson(response.data, null);
      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '实名认证失败'));
    }
  }

  /// 查询实名认证状态
  Future<bool> getRealNameVerifiedStatus() async {
    try {
      final response = await _http.get('/user/real-name-status');
      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      return _toBool(result.data!['verified']);
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '获取实名认证状态失败'));
    }
  }

  /// 退出登录
  Future<void> logout() async {
    try {
      await _http.post('/auth/logout');
    } catch (e) {
      // 忽略退出登录的错误
    }
  }

  /// 退出其他设备（当前设备保持登录，并返回新token）
  Future<String> logoutOtherDevices() async {
    try {
      final response = await _http.post('/auth/logout/others');
      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }
      final token = result.data!['token']?.toString() ?? '';
      if (token.isEmpty) {
        throw Exception('服务端未返回新登录凭证');
      }
      return token;
    } on DioException catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '退出其他设备失败'));
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '退出其他设备失败'));
    }
  }

  /// 上传文件（头像等）
  ///
  /// 使用 image_picker 选择的文件路径
  Future<String?> uploadAvatar(String filePath) async {
    try {
      // 与后端文件上传控制器对齐：/upload/image
      final response = await _http.uploadFile<Map<String, dynamic>>(
        '/upload/image',
        filePath: filePath,
        fileKey: 'file',
        data: {'biz_type': 'avatar'},
      );

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data!,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      // 返回可访问 URL，优先 file_url
      return result.data!['file_url'] as String? ??
          result.data!['file_path'] as String?;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '上传头像失败'));
    }
  }
}

/// 账户被禁用异常
class AccountDisabledException implements Exception {
  final String message;
  AccountDisabledException(this.message);

  @override
  String toString() => message;
}
