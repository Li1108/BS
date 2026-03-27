import 'package:json_annotation/json_annotation.dart';

part 'address_model.g.dart';

/// 用户地址模型
@JsonSerializable()
class AddressModel {
  final int id;

  @JsonKey(name: 'user_id')
  final int userId;

  final String address;

  @JsonKey(name: 'contact_name')
  final String contactName;

  @JsonKey(name: 'contact_phone')
  final String contactPhone;

  @JsonKey(name: 'is_default')
  final int isDefault;

  final double? latitude;

  final double? longitude;

  /// 省份
  final String? province;

  /// 城市
  final String? city;

  /// 区县
  final String? district;

  /// 详细地址（街道门牌号等）
  final String? detail;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  AddressModel({
    required this.id,
    required this.userId,
    required this.address,
    required this.contactName,
    required this.contactPhone,
    this.isDefault = 0,
    this.latitude,
    this.longitude,
    this.province,
    this.city,
    this.district,
    this.detail,
    this.createdAt,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) =>
      _$AddressModelFromJson(json);

  Map<String, dynamic> toJson() => _$AddressModelToJson(this);

  /// 是否为默认地址
  bool get isDefaultAddress => isDefault == 1;

  /// 复制并修改
  AddressModel copyWith({
    int? id,
    int? userId,
    String? address,
    String? contactName,
    String? contactPhone,
    int? isDefault,
    double? latitude,
    double? longitude,
    String? province,
    String? city,
    String? district,
    String? detail,
    String? createdAt,
  }) {
    return AddressModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      address: address ?? this.address,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      isDefault: isDefault ?? this.isDefault,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      province: province ?? this.province,
      city: city ?? this.city,
      district: district ?? this.district,
      detail: detail ?? this.detail,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 创建/更新地址请求
@JsonSerializable()
class AddressRequest {
  final String address;

  @JsonKey(name: 'contact_name')
  final String contactName;

  @JsonKey(name: 'contact_phone')
  final String contactPhone;

  @JsonKey(name: 'is_default')
  final int isDefault;

  final double? latitude;

  final double? longitude;

  final String? province;
  final String? city;
  final String? district;
  final String? detail;

  AddressRequest({
    required this.address,
    required this.contactName,
    required this.contactPhone,
    this.isDefault = 0,
    this.latitude,
    this.longitude,
    this.province,
    this.city,
    this.district,
    this.detail,
  });

  factory AddressRequest.fromJson(Map<String, dynamic> json) =>
      _$AddressRequestFromJson(json);

  Map<String, dynamic> toJson() => _$AddressRequestToJson(this);
}
