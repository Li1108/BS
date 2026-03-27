import 'package:json_annotation/json_annotation.dart';

part 'order_model.g.dart';

/// 订单状态枚举
enum OrderStatus {
  /// 待支付
  pendingPayment(0),

  /// 待接单
  pendingAccept(1),

  /// 已接单
  accepted(2),

  /// 护士已到达
  arrived(3),

  /// 服务中
  inService(4),

  /// 待评价
  pendingEvaluation(5),

  /// 已完成
  completed(6),

  /// 已取消/退款
  cancelled(7);

  final int value;
  const OrderStatus(this.value);

  static OrderStatus fromValue(int value) {
    return OrderStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OrderStatus.pendingPayment,
    );
  }

  /// 获取状态文本
  String get text {
    switch (this) {
      case OrderStatus.pendingPayment:
        return '待支付';
      case OrderStatus.pendingAccept:
        return '待接单';
      case OrderStatus.accepted:
        return '已接单';
      case OrderStatus.arrived:
        return '护士已到达';
      case OrderStatus.inService:
        return '服务中';
      case OrderStatus.pendingEvaluation:
        return '待评价';
      case OrderStatus.completed:
        return '已完成';
      case OrderStatus.cancelled:
        return '已取消';
    }
  }

  /// 获取状态颜色
  int get colorValue {
    switch (this) {
      case OrderStatus.pendingPayment:
        return 0xFFFF9800; // 橙色
      case OrderStatus.pendingAccept:
        return 0xFF2196F3; // 蓝色
      case OrderStatus.accepted:
        return 0xFF4CAF50; // 绿色
      case OrderStatus.arrived:
        return 0xFF9C27B0; // 紫色
      case OrderStatus.inService:
        return 0xFF00BCD4; // 青色
      case OrderStatus.pendingEvaluation:
        return 0xFFE91E63; // 粉色
      case OrderStatus.completed:
        return 0xFF4CAF50; // 绿色
      case OrderStatus.cancelled:
        return 0xFF9E9E9E; // 灰色
    }
  }
}

/// 退款状态枚举
enum RefundStatus {
  /// 无退款
  none(0),

  /// 退款中
  processing(1),

  /// 已退款
  refunded(2);

  final int value;
  const RefundStatus(this.value);

  static RefundStatus fromValue(int value) {
    return RefundStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RefundStatus.none,
    );
  }

  String get text {
    switch (this) {
      case RefundStatus.none:
        return '无退款';
      case RefundStatus.processing:
        return '退款中';
      case RefundStatus.refunded:
        return '已退款';
    }
  }
}

/// 订单模型
@JsonSerializable()
class OrderModel {
  final int id;

  @JsonKey(name: 'order_no')
  final String orderNo;

  @JsonKey(name: 'user_id')
  final int userId;

  @JsonKey(name: 'nurse_id')
  final int? nurseId;

  @JsonKey(name: 'service_id')
  final int serviceId;

  @JsonKey(name: 'service_name')
  final String serviceName;

  @JsonKey(name: 'service_price')
  final double servicePrice;

  @JsonKey(name: 'total_amount')
  final double totalAmount;

  @JsonKey(name: 'platform_fee')
  final double? platformFee;

  @JsonKey(name: 'nurse_income')
  final double? nurseIncome;

  @JsonKey(name: 'contact_name')
  final String contactName;

  @JsonKey(name: 'contact_phone')
  final String contactPhone;

  final String address;

  @JsonKey(name: 'appointment_time')
  final String appointmentTime;

  final String? remark;

  final double? latitude;
  final double? longitude;

  final int status;

  @JsonKey(name: 'pay_status')
  final int payStatus;

  @JsonKey(name: 'pay_time')
  final String? payTime;

  @JsonKey(name: 'out_trade_no')
  final String? outTradeNo;

  @JsonKey(name: 'arrival_time')
  final String? arrivalTime;

  @JsonKey(name: 'arrival_photo')
  final String? arrivalPhoto;

  @JsonKey(name: 'start_time')
  final String? startTime;

  @JsonKey(name: 'start_photo')
  final String? startPhoto;

  @JsonKey(name: 'finish_time')
  final String? finishTime;

  @JsonKey(name: 'finish_photo')
  final String? finishPhoto;

  @JsonKey(name: 'cancel_time')
  final String? cancelTime;

  @JsonKey(name: 'cancel_reason')
  final String? cancelReason;

  @JsonKey(name: 'refund_amount')
  final double? refundAmount;

  @JsonKey(name: 'refund_status')
  final int? refundStatus;

  @JsonKey(name: 'nurse_name')
  final String? nurseName;

  @JsonKey(name: 'nurse_phone')
  final String? nursePhone;

  @JsonKey(name: 'nurse_rating')
  final double? nurseRating;

  /// 用户评分 (1-5星)
  final int? rating;

  /// 评价内容
  @JsonKey(name: 'evaluation_content')
  final String? evaluationContent;

  /// 评价时间
  @JsonKey(name: 'evaluation_time')
  final String? evaluationTime;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  OrderModel({
    required this.id,
    required this.orderNo,
    required this.userId,
    this.nurseId,
    required this.serviceId,
    required this.serviceName,
    required this.servicePrice,
    required this.totalAmount,
    this.platformFee,
    this.nurseIncome,
    required this.contactName,
    required this.contactPhone,
    required this.address,
    required this.appointmentTime,
    this.remark,
    this.latitude,
    this.longitude,
    required this.status,
    required this.payStatus,
    this.payTime,
    this.outTradeNo,
    this.arrivalTime,
    this.arrivalPhoto,
    this.startTime,
    this.startPhoto,
    this.finishTime,
    this.finishPhoto,
    this.cancelTime,
    this.cancelReason,
    this.refundAmount,
    this.refundStatus,
    this.nurseName,
    this.nursePhone,
    this.nurseRating,
    this.rating,
    this.evaluationContent,
    this.evaluationTime,
    this.createdAt,
    this.updatedAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderModelFromJson(json);

  Map<String, dynamic> toJson() => _$OrderModelToJson(this);

  /// 获取订单状态枚举
  OrderStatus get orderStatus => OrderStatus.fromValue(status);

  /// 获取退款状态枚举
  RefundStatus get orderRefundStatus =>
      RefundStatus.fromValue(refundStatus ?? 0);

  /// 是否已支付
  bool get isPaid => payStatus == 1;

  DateTime? get _cancelStartTime {
    String? source;
    if (isPaid) {
      source = payTime ?? updatedAt ?? createdAt;
    } else {
      source = createdAt;
    }
    if (source == null || source.isEmpty) return null;
    try {
      return DateTime.parse(source);
    } catch (_) {
      return null;
    }
  }

  DateTime? get _paymentStartTime {
    final source = createdAt;
    if (source == null || source.isEmpty) return null;
    try {
      return DateTime.parse(source);
    } catch (_) {
      return null;
    }
  }

  /// 是否可取消（支付后30分钟内且未开始服务）
  bool get canCancel {
    if (status >= OrderStatus.arrived.value ||
        status == OrderStatus.cancelled.value) {
      return false;
    }
    if (!isPaid) {
      return status == OrderStatus.pendingPayment.value;
    }
    // 已支付订单：支付后30分钟内可取消
    final startTime = _cancelStartTime;
    if (startTime == null) return false;
    final diff = DateTime.now().difference(startTime);
    return diff.inSeconds >= 0 && diff.inSeconds <= 30 * 60;
  }

  /// 是否可申请退款
  bool get canRefund {
    return isPaid &&
        canCancel &&
        (refundStatus == null || refundStatus == RefundStatus.none.value);
  }

  /// 剩余可取消时间（秒）
  int get remainingCancelSeconds {
    if (!isPaid) return 0;
    final startTime = _cancelStartTime;
    if (startTime == null) return 0;

    final diffSeconds = DateTime.now().difference(startTime).inSeconds;
    if (diffSeconds < 0) return 30 * 60;

    final remainingSeconds = 30 * 60 - diffSeconds;
    return remainingSeconds > 0 ? remainingSeconds : 0;
  }

  /// 剩余可取消时间（分钟）
  int get remainingCancelMinutes {
    final seconds = remainingCancelSeconds;
    if (seconds <= 0) return 0;
    return (seconds / 60).ceil();
  }

  /// 剩余支付保留时间（秒）
  int get remainingPaySeconds {
    if (status != OrderStatus.pendingPayment.value || isPaid) return 0;
    final startTime = _paymentStartTime;
    if (startTime == null) return 0;

    final diffSeconds = DateTime.now().difference(startTime).inSeconds;
    if (diffSeconds < 0) return 30 * 60;

    final remainingSeconds = 30 * 60 - diffSeconds;
    return remainingSeconds > 0 ? remainingSeconds : 0;
  }

  /// 剩余支付保留时间（分钟）
  int get remainingPayMinutes {
    final seconds = remainingPaySeconds;
    if (seconds <= 0) return 0;
    return (seconds / 60).ceil();
  }

  /// 支付保留是否已超时
  bool get isPaymentExpired {
    return status == OrderStatus.pendingPayment.value &&
        !isPaid &&
        remainingPaySeconds <= 0;
  }

  /// 统一状态展示文案（覆盖退款中/已退款）
  String get displayStatusText {
    if (orderStatus == OrderStatus.cancelled) {
      if (orderRefundStatus == RefundStatus.processing) {
        return '退款中';
      }
      if (orderRefundStatus == RefundStatus.refunded) {
        return '已退款';
      }
    }
    return orderStatus.text;
  }
}

/// 取消订单请求
@JsonSerializable()
class CancelOrderRequest {
  @JsonKey(name: 'order_id')
  final int orderId;

  final String reason;

  @JsonKey(name: 'request_refund')
  final bool requestRefund;

  CancelOrderRequest({
    required this.orderId,
    required this.reason,
    this.requestRefund = true,
  });

  factory CancelOrderRequest.fromJson(Map<String, dynamic> json) =>
      _$CancelOrderRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CancelOrderRequestToJson(this);
}

/// 取消订单响应
@JsonSerializable()
class CancelOrderResponse {
  final bool success;
  final String message;

  @JsonKey(name: 'refund_amount')
  final double? refundAmount;

  @JsonKey(name: 'refund_status')
  final int? refundStatus;

  CancelOrderResponse({
    required this.success,
    required this.message,
    this.refundAmount,
    this.refundStatus,
  });

  factory CancelOrderResponse.fromJson(Map<String, dynamic> json) =>
      _$CancelOrderResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CancelOrderResponseToJson(this);
}

/// 退款请求
@JsonSerializable()
class RefundRequest {
  @JsonKey(name: 'order_id')
  final int orderId;

  final String reason;

  RefundRequest({required this.orderId, required this.reason});

  factory RefundRequest.fromJson(Map<String, dynamic> json) =>
      _$RefundRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RefundRequestToJson(this);
}

/// 退款响应
@JsonSerializable()
class RefundResponse {
  final bool success;
  final String message;

  @JsonKey(name: 'refund_no')
  final String? refundNo;

  @JsonKey(name: 'refund_amount')
  final double? refundAmount;

  @JsonKey(name: 'refund_status')
  final int? refundStatus;

  RefundResponse({
    required this.success,
    required this.message,
    this.refundNo,
    this.refundAmount,
    this.refundStatus,
  });

  factory RefundResponse.fromJson(Map<String, dynamic> json) =>
      _$RefundResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RefundResponseToJson(this);
}

/// 支付信息响应
@JsonSerializable()
class PaymentInfoResponse {
  @JsonKey(name: 'order_id')
  final int orderId;

  @JsonKey(name: 'order_no')
  final String orderNo;

  @JsonKey(name: 'total_amount')
  final double totalAmount;

  @JsonKey(name: 'pay_info')
  final String payInfo;

  @JsonKey(name: 'expire_time')
  final String? expireTime;

  PaymentInfoResponse({
    required this.orderId,
    required this.orderNo,
    required this.totalAmount,
    required this.payInfo,
    this.expireTime,
  });

  factory PaymentInfoResponse.fromJson(Map<String, dynamic> json) =>
      _$PaymentInfoResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PaymentInfoResponseToJson(this);
}

/// 订单评价请求
@JsonSerializable()
class EvaluationRequest {
  @JsonKey(name: 'order_id')
  final int orderId;

  final int rating;
  final String? comment;

  EvaluationRequest({
    required this.orderId,
    required this.rating,
    this.comment,
  });

  factory EvaluationRequest.fromJson(Map<String, dynamic> json) =>
      _$EvaluationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$EvaluationRequestToJson(this);
}
