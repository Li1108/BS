// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderModel _$OrderModelFromJson(Map<String, dynamic> json) => OrderModel(
  id: (json['id'] as num).toInt(),
  orderNo: json['order_no'] as String,
  userId: (json['user_id'] as num).toInt(),
  nurseId: (json['nurse_id'] as num?)?.toInt(),
  serviceId: (json['service_id'] as num).toInt(),
  serviceName: json['service_name'] as String,
  servicePrice: (json['service_price'] as num).toDouble(),
  totalAmount: (json['total_amount'] as num).toDouble(),
  platformFee: (json['platform_fee'] as num?)?.toDouble(),
  nurseIncome: (json['nurse_income'] as num?)?.toDouble(),
  contactName: json['contact_name'] as String,
  contactPhone: json['contact_phone'] as String,
  address: json['address'] as String,
  appointmentTime: json['appointment_time'] as String,
  remark: json['remark'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  status: (json['status'] as num).toInt(),
  payStatus: (json['pay_status'] as num).toInt(),
  payTime: json['pay_time'] as String?,
  outTradeNo: json['out_trade_no'] as String?,
  arrivalTime: json['arrival_time'] as String?,
  arrivalPhoto: json['arrival_photo'] as String?,
  startTime: json['start_time'] as String?,
  startPhoto: json['start_photo'] as String?,
  finishTime: json['finish_time'] as String?,
  finishPhoto: json['finish_photo'] as String?,
  cancelTime: json['cancel_time'] as String?,
  cancelReason: json['cancel_reason'] as String?,
  refundAmount: (json['refund_amount'] as num?)?.toDouble(),
  refundStatus: (json['refund_status'] as num?)?.toInt(),
  nurseName: json['nurse_name'] as String?,
  nursePhone: json['nurse_phone'] as String?,
  nurseRating: (json['nurse_rating'] as num?)?.toDouble(),
  rating: (json['rating'] as num?)?.toInt(),
  evaluationContent: json['evaluation_content'] as String?,
  evaluationTime: json['evaluation_time'] as String?,
  createdAt: json['created_at'] as String?,
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$OrderModelToJson(OrderModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_no': instance.orderNo,
      'user_id': instance.userId,
      'nurse_id': instance.nurseId,
      'service_id': instance.serviceId,
      'service_name': instance.serviceName,
      'service_price': instance.servicePrice,
      'total_amount': instance.totalAmount,
      'platform_fee': instance.platformFee,
      'nurse_income': instance.nurseIncome,
      'contact_name': instance.contactName,
      'contact_phone': instance.contactPhone,
      'address': instance.address,
      'appointment_time': instance.appointmentTime,
      'remark': instance.remark,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'status': instance.status,
      'pay_status': instance.payStatus,
      'pay_time': instance.payTime,
      'out_trade_no': instance.outTradeNo,
      'arrival_time': instance.arrivalTime,
      'arrival_photo': instance.arrivalPhoto,
      'start_time': instance.startTime,
      'start_photo': instance.startPhoto,
      'finish_time': instance.finishTime,
      'finish_photo': instance.finishPhoto,
      'cancel_time': instance.cancelTime,
      'cancel_reason': instance.cancelReason,
      'refund_amount': instance.refundAmount,
      'refund_status': instance.refundStatus,
      'nurse_name': instance.nurseName,
      'nurse_phone': instance.nursePhone,
      'nurse_rating': instance.nurseRating,
      'rating': instance.rating,
      'evaluation_content': instance.evaluationContent,
      'evaluation_time': instance.evaluationTime,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };

CancelOrderRequest _$CancelOrderRequestFromJson(Map<String, dynamic> json) =>
    CancelOrderRequest(
      orderId: (json['order_id'] as num).toInt(),
      reason: json['reason'] as String,
      requestRefund: json['request_refund'] as bool? ?? true,
    );

Map<String, dynamic> _$CancelOrderRequestToJson(CancelOrderRequest instance) =>
    <String, dynamic>{
      'order_id': instance.orderId,
      'reason': instance.reason,
      'request_refund': instance.requestRefund,
    };

CancelOrderResponse _$CancelOrderResponseFromJson(Map<String, dynamic> json) =>
    CancelOrderResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      refundAmount: (json['refund_amount'] as num?)?.toDouble(),
      refundStatus: (json['refund_status'] as num?)?.toInt(),
    );

Map<String, dynamic> _$CancelOrderResponseToJson(
  CancelOrderResponse instance,
) => <String, dynamic>{
  'success': instance.success,
  'message': instance.message,
  'refund_amount': instance.refundAmount,
  'refund_status': instance.refundStatus,
};

RefundRequest _$RefundRequestFromJson(Map<String, dynamic> json) =>
    RefundRequest(
      orderId: (json['order_id'] as num).toInt(),
      reason: json['reason'] as String,
    );

Map<String, dynamic> _$RefundRequestToJson(RefundRequest instance) =>
    <String, dynamic>{'order_id': instance.orderId, 'reason': instance.reason};

RefundResponse _$RefundResponseFromJson(Map<String, dynamic> json) =>
    RefundResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      refundNo: json['refund_no'] as String?,
      refundAmount: (json['refund_amount'] as num?)?.toDouble(),
      refundStatus: (json['refund_status'] as num?)?.toInt(),
    );

Map<String, dynamic> _$RefundResponseToJson(RefundResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'refund_no': instance.refundNo,
      'refund_amount': instance.refundAmount,
      'refund_status': instance.refundStatus,
    };

PaymentInfoResponse _$PaymentInfoResponseFromJson(Map<String, dynamic> json) =>
    PaymentInfoResponse(
      orderId: (json['order_id'] as num).toInt(),
      orderNo: json['order_no'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      payInfo: json['pay_info'] as String,
      expireTime: json['expire_time'] as String?,
    );

Map<String, dynamic> _$PaymentInfoResponseToJson(
  PaymentInfoResponse instance,
) => <String, dynamic>{
  'order_id': instance.orderId,
  'order_no': instance.orderNo,
  'total_amount': instance.totalAmount,
  'pay_info': instance.payInfo,
  'expire_time': instance.expireTime,
};

EvaluationRequest _$EvaluationRequestFromJson(Map<String, dynamic> json) =>
    EvaluationRequest(
      orderId: (json['order_id'] as num).toInt(),
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
    );

Map<String, dynamic> _$EvaluationRequestToJson(EvaluationRequest instance) =>
    <String, dynamic>{
      'order_id': instance.orderId,
      'rating': instance.rating,
      'comment': instance.comment,
    };
