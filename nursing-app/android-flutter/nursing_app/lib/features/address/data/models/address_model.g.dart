// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AddressModel _$AddressModelFromJson(Map<String, dynamic> json) => AddressModel(
  id: (json['id'] as num).toInt(),
  userId: (json['user_id'] as num).toInt(),
  address: json['address'] as String,
  contactName: json['contact_name'] as String,
  contactPhone: json['contact_phone'] as String,
  isDefault: (json['is_default'] as num?)?.toInt() ?? 0,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  province: json['province'] as String?,
  city: json['city'] as String?,
  district: json['district'] as String?,
  detail: json['detail'] as String?,
  createdAt: json['created_at'] as String?,
);

Map<String, dynamic> _$AddressModelToJson(AddressModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'address': instance.address,
      'contact_name': instance.contactName,
      'contact_phone': instance.contactPhone,
      'is_default': instance.isDefault,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'province': instance.province,
      'city': instance.city,
      'district': instance.district,
      'detail': instance.detail,
      'created_at': instance.createdAt,
    };

AddressRequest _$AddressRequestFromJson(Map<String, dynamic> json) =>
    AddressRequest(
      address: json['address'] as String,
      contactName: json['contact_name'] as String,
      contactPhone: json['contact_phone'] as String,
      isDefault: (json['is_default'] as num?)?.toInt() ?? 0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      province: json['province'] as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      detail: json['detail'] as String?,
    );

Map<String, dynamic> _$AddressRequestToJson(AddressRequest instance) =>
    <String, dynamic>{
      'address': instance.address,
      'contact_name': instance.contactName,
      'contact_phone': instance.contactPhone,
      'is_default': instance.isDefault,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'province': instance.province,
      'city': instance.city,
      'district': instance.district,
      'detail': instance.detail,
    };
