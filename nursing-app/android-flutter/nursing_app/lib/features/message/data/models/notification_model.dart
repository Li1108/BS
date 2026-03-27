import 'package:json_annotation/json_annotation.dart';

part 'notification_model.g.dart';

/// 通知类型枚举
enum NotificationType {
  /// 订单更新
  orderUpdate(1),

  /// 审核结果
  auditResult(2),

  /// 系统消息
  system(3);

  final int value;
  const NotificationType(this.value);

  static NotificationType fromValue(int value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.system,
    );
  }

  String get text {
    switch (this) {
      case NotificationType.orderUpdate:
        return '订单通知';
      case NotificationType.auditResult:
        return '审核结果';
      case NotificationType.system:
        return '系统消息';
    }
  }
}

/// 通知模型
@JsonSerializable()
class NotificationModel {
  final int id;

  @JsonKey(name: 'user_id')
  final int userId;

  final int type;

  final String content;

  final String? title;

  @JsonKey(name: 'is_read')
  final int isRead;

  @JsonKey(name: 'push_id')
  final String? pushId;

  /// 关联的订单ID（如果是订单通知）
  @JsonKey(name: 'order_id')
  final int? orderId;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.content,
    this.title,
    this.isRead = 0,
    this.pushId,
    this.orderId,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationModelToJson(this);

  /// 获取通知类型枚举
  NotificationType get notificationType => NotificationType.fromValue(type);

  /// 是否已读
  bool get hasRead => isRead == 1;

  /// 复制并修改
  NotificationModel copyWith({
    int? id,
    int? userId,
    int? type,
    String? content,
    String? title,
    int? isRead,
    String? pushId,
    int? orderId,
    String? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      content: content ?? this.content,
      title: title ?? this.title,
      isRead: isRead ?? this.isRead,
      pushId: pushId ?? this.pushId,
      orderId: orderId ?? this.orderId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 通知列表响应
@JsonSerializable()
class NotificationListResponse {
  final List<NotificationModel> list;
  final int total;

  @JsonKey(name: 'unread_count')
  final int unreadCount;

  NotificationListResponse({
    required this.list,
    required this.total,
    this.unreadCount = 0,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) =>
      _$NotificationListResponseFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationListResponseToJson(this);
}
