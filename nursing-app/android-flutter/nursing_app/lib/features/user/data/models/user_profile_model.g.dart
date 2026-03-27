// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserProfileModelImpl _$$UserProfileModelImplFromJson(
  Map<String, dynamic> json,
) => _$UserProfileModelImpl(
  id: (json['id'] as num).toInt(),
  phone: json['phone'] as String,
  nickname: json['nickname'] as String?,
  avatarUrl: json['avatarUrl'] as String?,
  gender: (json['gender'] as num?)?.toInt(),
  realName: json['realName'] as String?,
  idCardNo: json['idCardNo'] as String?,
  birthday: json['birthday'] as String?,
  emergencyContact: json['emergencyContact'] as String?,
  emergencyPhone: json['emergencyPhone'] as String?,
  status: (json['status'] as num?)?.toInt(),
  createTime: json['createTime'] as String?,
  realNameVerified: (json['realNameVerified'] as num?)?.toInt(),
  realNameVerifyTime: json['realNameVerifyTime'] as String?,
);

Map<String, dynamic> _$$UserProfileModelImplToJson(
  _$UserProfileModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'phone': instance.phone,
  'nickname': instance.nickname,
  'avatarUrl': instance.avatarUrl,
  'gender': instance.gender,
  'realName': instance.realName,
  'idCardNo': instance.idCardNo,
  'birthday': instance.birthday,
  'emergencyContact': instance.emergencyContact,
  'emergencyPhone': instance.emergencyPhone,
  'status': instance.status,
  'createTime': instance.createTime,
  'realNameVerified': instance.realNameVerified,
  'realNameVerifyTime': instance.realNameVerifyTime,
};
