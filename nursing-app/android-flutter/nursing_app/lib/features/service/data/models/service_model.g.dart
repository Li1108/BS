// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ServiceModel _$ServiceModelFromJson(Map<String, dynamic> json) => ServiceModel(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  price: (json['price'] as num).toDouble(),
  description: json['description'] as String?,
  iconUrl: json['icon_url'] as String?,
  status: (json['status'] as num?)?.toInt(),
  category: json['category'] as String?,
  createdAt: json['created_at'] as String?,
);

Map<String, dynamic> _$ServiceModelToJson(ServiceModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'price': instance.price,
      'description': instance.description,
      'icon_url': instance.iconUrl,
      'status': instance.status,
      'category': instance.category,
      'created_at': instance.createdAt,
    };

CreateOrderRequest _$CreateOrderRequestFromJson(Map<String, dynamic> json) =>
    CreateOrderRequest(
      serviceId: (json['service_id'] as num).toInt(),
      addressId: (json['address_id'] as num?)?.toInt(),
      contactName: json['contact_name'] as String,
      contactPhone: json['contact_phone'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      appointmentTime: json['appointment_time'] as String,
      remark: json['remark'] as String?,
    );

Map<String, dynamic> _$CreateOrderRequestToJson(CreateOrderRequest instance) =>
    <String, dynamic>{
      'service_id': instance.serviceId,
      'address_id': instance.addressId,
      'contact_name': instance.contactName,
      'contact_phone': instance.contactPhone,
      'address': instance.address,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'appointment_time': instance.appointmentTime,
      'remark': instance.remark,
    };

CreateOrderResponse _$CreateOrderResponseFromJson(Map<String, dynamic> json) =>
    CreateOrderResponse(
      orderId: (json['order_id'] as num).toInt(),
      orderNo: json['order_no'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      payInfo: json['pay_info'] as String?,
    );

Map<String, dynamic> _$CreateOrderResponseToJson(
  CreateOrderResponse instance,
) => <String, dynamic>{
  'order_id': instance.orderId,
  'order_no': instance.orderNo,
  'total_amount': instance.totalAmount,
  'pay_info': instance.payInfo,
};

PaymentResult _$PaymentResultFromJson(Map<String, dynamic> json) =>
    PaymentResult(
      success: json['success'] as bool,
      message: json['message'] as String?,
      outTradeNo: json['out_trade_no'] as String?,
    );

Map<String, dynamic> _$PaymentResultToJson(PaymentResult instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'out_trade_no': instance.outTradeNo,
    };
