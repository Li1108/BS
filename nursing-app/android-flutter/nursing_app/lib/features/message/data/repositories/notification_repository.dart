import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../../core/network/http_client.dart';
import '../../../../core/utils/error_mapper.dart';
import '../models/notification_model.dart';

/// 通知消息仓库
///
/// 处理通知相关的API请求
class NotificationRepository {
  final HttpClient _http;
  final Logger _logger = Logger();

  NotificationRepository(this._http);

  int _bizTypeToInt(String? bizType) {
    switch ((bizType ?? '').toUpperCase()) {
      case 'ORDER':
      case 'PAY':
      case 'REFUND':
        return 1;
      case 'AUDIT':
      case 'NURSE_AUDIT':
      case 'REVIEW':
      case 'WITHDRAW':
        return 2;
      default:
        return 3;
    }
  }

  Map<String, dynamic> _normalizeNotification(Map<String, dynamic> raw) {
    final bizIdText = (raw['biz_id'] ?? raw['bizId'])?.toString() ?? '';
    return {
      'id': raw['id'],
      'user_id': raw['receiver_user_id'] ?? raw['receiverUserId'] ?? 0,
      'type': _bizTypeToInt((raw['biz_type'] ?? raw['bizType'])?.toString()),
      'content': raw['content']?.toString() ?? '',
      'title': raw['title']?.toString(),
      'is_read': raw['read_flag'] ?? raw['readFlag'] ?? 0,
      'push_id': null,
      'order_id': int.tryParse(bizIdText),
      'created_at':
          raw['created_at']?.toString() ??
          raw['create_time']?.toString() ??
          raw['createTime']?.toString(),
    };
  }

  /// 获取通知列表
  Future<NotificationListResponse> getNotifications({
    int page = 1,
    int pageSize = 20,
    int? type,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'pageNo': page,
        'pageSize': pageSize,
      };

      final response = await _http.get(
        '/notification/list',
        queryParameters: queryParams,
      );

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      final pageData = result.data!;
      final rawRecords = (pageData['records'] as List?) ?? const [];
      final normalizedRecords = rawRecords
          .map(
            (item) =>
                _normalizeNotification(Map<String, dynamic>.from(item as Map)),
          )
          .where((item) => type == null || item['type'] == type)
          .toList();
      final unreadCount = await getUnreadCount();
      return NotificationListResponse.fromJson({
        'list': normalizedRecords,
        'total': normalizedRecords.length,
        'unread_count': unreadCount,
      });
    } on DioException catch (e) {
      _logger.e('获取通知列表失败', error: e);
      throw Exception(normalizeErrorMessage(e, fallback: '加载通知列表失败'));
    }
  }

  /// 获取未读通知数量
  Future<int> getUnreadCount() async {
    try {
      final response = await _http.get('/notification/unreadCount');
      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
      if (result.isSuccess && result.data != null) {
        final rawCount =
            result.data!['unread_count'] ?? result.data!['unreadCount'] ?? 0;
        return (rawCount as num?)?.toInt() ?? 0;
      }
      return 0;
    } on DioException catch (e) {
      _logger.e('获取未读数量失败', error: e);
      return 0;
    }
  }

  /// 标记通知为已读
  Future<bool> markAsRead(int notificationId) async {
    try {
      final response = await _http.post('/notification/read/$notificationId');
      final result = ApiResponse.fromJson(response.data, null);
      return result.isSuccess;
    } on DioException catch (e) {
      _logger.e('标记已读失败', error: e);
      return false;
    }
  }

  /// 标记全部为已读
  Future<bool> markAllAsRead() async {
    try {
      final list = await getNotifications(page: 1, pageSize: 200);
      var ok = true;
      for (final item in list.list.where((n) => !n.hasRead)) {
        final success = await markAsRead(item.id);
        if (!success) ok = false;
      }
      return ok;
    } on DioException catch (e) {
      _logger.e('标记全部已读失败', error: e);
      return false;
    }
  }

  /// 删除通知
  Future<bool> deleteNotification(int notificationId) async {
    // 当前后端未提供删除接口，前端执行本地删除即可。
    return true;
  }

  /// 清空所有通知
  Future<bool> clearAll() async {
    // 当前后端未提供清空接口，前端执行本地清空即可。
    return true;
  }
}

/// NotificationRepository Provider
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(HttpClient.instance);
});
