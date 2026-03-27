import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile_model.freezed.dart';
part 'user_profile_model.g.dart';

/// 用户个人资料模型
@freezed
class UserProfileModel with _$UserProfileModel {
  const UserProfileModel._();

  const factory UserProfileModel({
    required int id,
    required String phone,
    String? nickname,
    String? avatarUrl,
    int? gender, // 0: 未设置, 1: 男, 2: 女
    String? realName,
    String? idCardNo,
    String? birthday,
    String? emergencyContact,
    String? emergencyPhone,
    int? status,
    String? createTime,
    int? realNameVerified, // 0-未认证，1-已认证
    String? realNameVerifyTime,
  }) = _UserProfileModel;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      _$UserProfileModelFromJson(json);

  /// 是否已完成实名认证
  bool get isRealNameVerified => realNameVerified == 1;
}
