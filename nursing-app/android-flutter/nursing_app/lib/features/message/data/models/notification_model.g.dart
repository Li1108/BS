// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationModel _$NotificationModelFromJson(Map<String, dynamic> json) =>
    NotificationModel(
      id: (json['id'] as num).toInt(),
      userId: (json['user_id'] as num).toInt(),
      type: (json['type'] as num).toInt(),
      content: json['content'] as String,
      title: json['title'] as String?,
      isRead: (json['is_read'] as num?)?.toInt() ?? 0,
      pushId: json['push_id'] as String?,
      orderId: (json['order_id'] as num?)?.toInt(),
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$NotificationModelToJson(NotificationModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'type': instance.type,
      'content': instance.content,
      'title': instance.title,
      'is_read': instance.isRead,
      'push_id': instance.pushId,
      'order_id': instance.orderId,
      'created_at': instance.createdAt,
    };

NotificationListResponse _$NotificationListResponseFromJson(
  Map<String, dynamic> json,
) => NotificationListResponse(
  list: (json['list'] as List<dynamic>)
      .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
  unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$NotificationListResponseToJson(
  NotificationListResponse instance,
) => <String, dynamic>{
  'list': instance.list,
  'total': instance.total,
  'unread_count': instance.unreadCount,
};
