import 'package:json_annotation/json_annotation.dart';

part 'service_model.g.dart';

/// 护理服务项目模型
///
/// 对应数据库表 service_item
@JsonSerializable()
class ServiceModel {
  final int id;
  final String name;
  final double price;
  final String? description;

  @JsonKey(name: 'icon_url')
  final String? iconUrl;

  final int? status; // 1上架, 0下架
  final String? category; // 分类（基础护理、产后护理等）

  @JsonKey(name: 'created_at')
  final String? createdAt;

  ServiceModel({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.iconUrl,
    this.status,
    this.category,
    this.createdAt,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) =>
      _$ServiceModelFromJson(json);

  Map<String, dynamic> toJson() => _$ServiceModelToJson(this);

  /// 是否上架
  bool get isAvailable => status == 1;

  /// 复制并修改
  ServiceModel copyWith({
    int? id,
    String? name,
    double? price,
    String? description,
    String? iconUrl,
    int? status,
    String? category,
    String? createdAt,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      status: status ?? this.status,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 创建订单请求模型
@JsonSerializable()
class CreateOrderRequest {
  @JsonKey(name: 'service_id')
  final int serviceId;

  @JsonKey(name: 'address_id')
  final int? addressId;

  @JsonKey(name: 'contact_name')
  final String contactName;

  @JsonKey(name: 'contact_phone')
  final String contactPhone;

  final String address;

  final double? latitude;
  final double? longitude;

  @JsonKey(name: 'appointment_time')
  final String appointmentTime;

  final String? remark;

  CreateOrderRequest({
    required this.serviceId,
    this.addressId,
    required this.contactName,
    required this.contactPhone,
    required this.address,
    this.latitude,
    this.longitude,
    required this.appointmentTime,
    this.remark,
  });

  factory CreateOrderRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateOrderRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateOrderRequestToJson(this);
}

/// 创建订单响应模型
@JsonSerializable()
class CreateOrderResponse {
  @JsonKey(name: 'order_id')
  final int orderId;

  @JsonKey(name: 'order_no')
  final String orderNo;

  @JsonKey(name: 'total_amount')
  final double totalAmount;

  /// 支付宝支付信息（用于调起支付）
  @JsonKey(name: 'pay_info')
  final String? payInfo;

  CreateOrderResponse({
    required this.orderId,
    required this.orderNo,
    required this.totalAmount,
    this.payInfo,
  });

  factory CreateOrderResponse.fromJson(Map<String, dynamic> json) =>
      _$CreateOrderResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CreateOrderResponseToJson(this);
}

/// 支付结果模型
@JsonSerializable()
class PaymentResult {
  final bool success;
  final String? message;

  @JsonKey(name: 'out_trade_no')
  final String? outTradeNo;

  PaymentResult({required this.success, this.message, this.outTradeNo});

  factory PaymentResult.fromJson(Map<String, dynamic> json) =>
      _$PaymentResultFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentResultToJson(this);
}
