import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_mapper.dart';
import '../data/models/notification_model.dart';
import '../data/repositories/notification_repository.dart';

/// 通知列表状态
class NotificationListState {
  final List<NotificationModel> notifications;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final int unreadCount;
  final String? error;

  const NotificationListState({
    this.notifications = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 1,
    this.unreadCount = 0,
    this.error,
  });

  NotificationListState copyWith({
    List<NotificationModel>? notifications,
    bool? isLoading,
    bool? hasMore,
    int? page,
    int? unreadCount,
    String? error,
  }) {
    return NotificationListState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      unreadCount: unreadCount ?? this.unreadCount,
      error: error,
    );
  }
}

/// 通知列表 Notifier
class NotificationListNotifier extends StateNotifier<NotificationListState> {
  final NotificationRepository _repository;

  NotificationListNotifier(this._repository)
    : super(const NotificationListState());

  /// 加载通知列表
  Future<void> loadNotifications({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 1 : state.page;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _repository.getNotifications(page: page);

      final notifications = refresh
          ? response.list
          : [...state.notifications, ...response.list];

      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
        hasMore: response.list.length >= 20,
        page: page + 1,
        unreadCount: response.unreadCount,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: normalizeErrorMessage(e, fallback: '加载通知失败'),
      );
    }
  }

  /// 刷新列表
  Future<void> refresh() async {
    await loadNotifications(refresh: true);
  }

  /// 加载更多
  Future<void> loadMore() async {
    if (state.hasMore && !state.isLoading) {
      await loadNotifications();
    }
  }

  /// 标记为已读
  Future<void> markAsRead(int notificationId) async {
    final success = await _repository.markAsRead(notificationId);
    if (success) {
      final updatedList = state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: 1);
        }
        return n;
      }).toList();

      state = state.copyWith(
        notifications: updatedList,
        unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
      );
    }
  }

  /// 标记全部已读
  Future<void> markAllAsRead() async {
    final success = await _repository.markAllAsRead();
    if (success) {
      final updatedList = state.notifications
          .map((n) => n.copyWith(isRead: 1))
          .toList();

      state = state.copyWith(notifications: updatedList, unreadCount: 0);
    }
  }

  /// 删除通知
  Future<void> deleteNotification(int notificationId) async {
    final success = await _repository.deleteNotification(notificationId);
    if (success) {
      final notification = state.notifications.firstWhere(
        (n) => n.id == notificationId,
        orElse: () => state.notifications.first,
      );
      final wasUnread = notification.isRead == 0;

      final updatedList = state.notifications
          .where((n) => n.id != notificationId)
          .toList();

      state = state.copyWith(
        notifications: updatedList,
        unreadCount: wasUnread && state.unreadCount > 0
            ? state.unreadCount - 1
            : state.unreadCount,
      );
    }
  }

  /// 清空所有通知
  Future<void> clearAll() async {
    final success = await _repository.clearAll();
    if (success) {
      state = state.copyWith(notifications: [], unreadCount: 0);
    }
  }

  /// 添加新通知（推送收到时调用）
  void addNotification(NotificationModel notification) {
    final updatedList = [notification, ...state.notifications];
    state = state.copyWith(
      notifications: updatedList,
      unreadCount: state.unreadCount + 1,
    );
  }
}

/// 通知列表 Provider
final notificationListProvider =
    StateNotifierProvider<NotificationListNotifier, NotificationListState>((
      ref,
    ) {
      final repository = ref.watch(notificationRepositoryProvider);
      return NotificationListNotifier(repository);
    });

/// 未读通知数量 Provider
final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationListProvider).unreadCount;
});
