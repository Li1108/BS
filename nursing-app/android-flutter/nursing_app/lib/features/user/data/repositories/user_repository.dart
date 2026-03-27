import 'dart:io';

import '../../../../core/network/http_client.dart';
import '../../../../core/utils/error_mapper.dart';
import '../models/user_profile_model.dart';

/// 用户资料仓库
///
/// 处理用户个人资料相关的 API 请求
class UserRepository {
  final HttpClient _http = HttpClient.instance;

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> _normalizeProfile(Map<String, dynamic> raw) {
    return {
      'id': _toInt(raw['id']) ?? 0,
      'phone': raw['phone']?.toString() ?? '',
      'nickname': raw['nickname']?.toString(),
      'avatarUrl':
          raw['avatarUrl']?.toString() ?? raw['avatar_url']?.toString(),
      'gender': _toInt(raw['gender']),
      'realName': raw['realName']?.toString() ?? raw['real_name']?.toString(),
      'idCardNo': raw['idCardNo']?.toString() ?? raw['id_card_no']?.toString(),
      'birthday': raw['birthday']?.toString(),
      'emergencyContact':
          raw['emergencyContact']?.toString() ??
          raw['emergency_contact']?.toString(),
      'emergencyPhone':
          raw['emergencyPhone']?.toString() ??
          raw['emergency_phone']?.toString(),
      'status': _toInt(raw['status']),
      'createTime':
          raw['createTime']?.toString() ?? raw['create_time']?.toString(),
      'realNameVerified': _toInt(
        raw['realNameVerified'] ?? raw['real_name_verified'],
      ),
      'realNameVerifyTime':
          raw['realNameVerifyTime']?.toString() ??
          raw['real_name_verify_time']?.toString(),
    };
  }

  String _extractUploadedUrl(Map<String, dynamic> data) {
    final candidates = [
      data['file_url'],
      data['fileUrl'],
      data['file_path'],
      data['filePath'],
    ];
    for (final value in candidates) {
      final text = value?.toString() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// 获取用户个人资料
  Future<UserProfileModel> getProfile() async {
    try {
      final response = await _http.get('/user/profile');

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(
          result.message.isNotEmpty ? result.message : '获取个人资料失败',
        );
      }

      return UserProfileModel.fromJson(_normalizeProfile(result.data!));
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '获取个人资料失败'));
    }
  }

  /// 更新用户个人资料
  ///
  /// [data] 要更新的字段
  /// 支持的字段: nickname, avatarUrl, gender, realName, emergencyContact, emergencyPhone
  Future<UserProfileModel?> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _http.put('/user/profile', data: data);

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (json) => json as Map<String, dynamic>,
      );

      if (!result.isSuccess) {
        throw Exception(
          result.message.isNotEmpty ? result.message : '更新个人资料失败',
        );
      }

      final payload = result.data;
      if (payload == null) return null;
      return UserProfileModel.fromJson(_normalizeProfile(payload));
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '更新个人资料失败'));
    }
  }

  /// 上传头像并返回图片URL/路径
  Future<String> uploadAvatar(File file) async {
    try {
      final response = await _http.uploadFile(
        '/upload/image',
        filePath: file.path,
        data: {'bizType': 'avatar'},
      );

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message.isNotEmpty ? result.message : '上传头像失败');
      }

      final avatarUrl = _extractUploadedUrl(result.data!);
      if (avatarUrl.isEmpty) {
        throw Exception('上传成功但未返回头像地址');
      }
      return avatarUrl;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '上传头像失败'));
    }
  }
}
