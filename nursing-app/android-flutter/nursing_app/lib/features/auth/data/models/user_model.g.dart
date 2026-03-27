// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  id: (json['id'] as num?)?.toInt(),
  username: json['username'] as String?,
  phone: json['phone'] as String,
  avatar: json['avatar'] as String?,
  role: json['role'] as String?,
  status: (json['status'] as num?)?.toInt(),
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'phone': instance.phone,
  'avatar': instance.avatar,
  'role': instance.role,
  'status': instance.status,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
};

LoginResponse _$LoginResponseFromJson(Map<String, dynamic> json) =>
    LoginResponse(
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: (json['expires_in'] as num?)?.toInt(),
      realNameVerified: json['realNameVerified'] as bool?,
    );

Map<String, dynamic> _$LoginResponseToJson(LoginResponse instance) =>
    <String, dynamic>{
      'user': instance.user,
      'token': instance.token,
      'refresh_token': instance.refreshToken,
      'expires_in': instance.expiresIn,
      'realNameVerified': instance.realNameVerified,
    };

NurseProfileModel _$NurseProfileModelFromJson(Map<String, dynamic> json) =>
    NurseProfileModel(
      userId: (json['user_id'] as num).toInt(),
      realName: json['real_name'] as String,
      idCardNo: json['id_card_no'] as String?,
      idCardPhotoFront: json['id_card_photo_front'] as String?,
      idCardPhotoBack: json['id_card_photo_back'] as String?,
      certificatePhoto: json['certificate_photo'] as String?,
      auditStatus: (json['audit_status'] as num?)?.toInt(),
      auditReason: json['audit_reason'] as String?,
      workMode: (json['work_mode'] as num?)?.toInt(),
      balance: (json['balance'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble(),
      serviceArea: json['service_area'] as String?,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$NurseProfileModelToJson(NurseProfileModel instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'real_name': instance.realName,
      'id_card_no': instance.idCardNo,
      'id_card_photo_front': instance.idCardPhotoFront,
      'id_card_photo_back': instance.idCardPhotoBack,
      'certificate_photo': instance.certificatePhoto,
      'audit_status': instance.auditStatus,
      'audit_reason': instance.auditReason,
      'work_mode': instance.workMode,
      'balance': instance.balance,
      'rating': instance.rating,
      'service_area': instance.serviceArea,
      'location_lat': instance.locationLat,
      'location_lng': instance.locationLng,
    };
