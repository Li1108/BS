import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

/// 用户模型
///
/// 对应数据库表 sys_user
@JsonSerializable()
class UserModel {
  final int? id;
  final String? username;
  final String phone;
  final String? avatar;
  final String? role; // USER, NURSE, ADMIN
  final int? status; // 1正常, 0禁用

  @JsonKey(name: 'created_at')
  final String? createdAt;

  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  UserModel({
    this.id,
    this.username,
    required this.phone,
    this.avatar,
    this.role,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  /// 是否为护士
  bool get isNurse => role == 'NURSE';

  /// 是否为普通用户
  bool get isUser => role == 'USER';

  /// 是否为管理员
  bool get isAdmin => role == 'ADMIN';

  /// 是否被禁用
  bool get isDisabled => status == 0;

  /// 复制并修改
  UserModel copyWith({
    int? id,
    String? username,
    String? phone,
    String? avatar,
    String? role,
    int? status,
    String? createdAt,
    String? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 登录响应模型
@JsonSerializable()
class LoginResponse {
  final UserModel user;
  final String token;

  @JsonKey(name: 'refresh_token')
  final String? refreshToken;

  @JsonKey(name: 'expires_in')
  final int? expiresIn;

  @JsonKey(name: 'realNameVerified')
  final bool? realNameVerified;

  LoginResponse({
    required this.user,
    required this.token,
    this.refreshToken,
    this.expiresIn,
    this.realNameVerified,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}

/// 护士档案模型
///
/// 对应数据库表 nurse_profile
@JsonSerializable()
class NurseProfileModel {
  @JsonKey(name: 'user_id')
  final int userId;

  @JsonKey(name: 'real_name')
  final String realName;

  @JsonKey(name: 'id_card_no')
  final String? idCardNo;

  @JsonKey(name: 'id_card_photo_front')
  final String? idCardPhotoFront;

  @JsonKey(name: 'id_card_photo_back')
  final String? idCardPhotoBack;

  @JsonKey(name: 'certificate_photo')
  final String? certificatePhoto;

  @JsonKey(name: 'audit_status')
  final int? auditStatus; // 0待审，1通过，2拒绝

  @JsonKey(name: 'audit_reason')
  final String? auditReason;

  @JsonKey(name: 'work_mode')
  final int? workMode; // 1开启，0休息中

  final double? balance;
  final double? rating;

  @JsonKey(name: 'service_area')
  final String? serviceArea;

  @JsonKey(name: 'location_lat')
  final double? locationLat;

  @JsonKey(name: 'location_lng')
  final double? locationLng;

  NurseProfileModel({
    required this.userId,
    required this.realName,
    this.idCardNo,
    this.idCardPhotoFront,
    this.idCardPhotoBack,
    this.certificatePhoto,
    this.auditStatus,
    this.auditReason,
    this.workMode,
    this.balance,
    this.rating,
    this.serviceArea,
    this.locationLat,
    this.locationLng,
  });

  factory NurseProfileModel.fromJson(Map<String, dynamic> json) =>
      _$NurseProfileModelFromJson(json);

  Map<String, dynamic> toJson() => _$NurseProfileModelToJson(this);

  /// 审核状态文本
  String get auditStatusText {
    switch (auditStatus) {
      case 0:
        return '待审核';
      case 1:
        return '已通过';
      case 2:
        return '已拒绝';
      default:
        return '未知';
    }
  }

  /// 是否在接单中
  bool get isWorking => workMode == 1;

  /// 是否审核通过
  bool get isApproved => auditStatus == 1;
}
