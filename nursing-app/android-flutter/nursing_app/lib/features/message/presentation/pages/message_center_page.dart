import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/push_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/commercial_ui_widgets.dart';
import '../../data/models/notification_model.dart';
import '../../providers/notification_provider.dart';

/// 消息中心页面
///
/// 功能：
/// 1. 展示订单更新通知、系统消息等
/// 2. 集成阿里云推送SDK接收实时通知
/// 3. 点击通知跳转到对应详情页
/// 4. 支持标记已读、全部已读、删除
@RoutePage()
class MessageCenterPage extends ConsumerStatefulWidget {
  final bool nurseMode;

  const MessageCenterPage({super.key, this.nurseMode = false});

  @override
  ConsumerState<MessageCenterPage> createState() => _MessageCenterPageState();
}

class _MessageCenterPageState extends ConsumerState<MessageCenterPage>
    with WidgetsBindingObserver {
  static const Duration _pollingInterval = Duration(seconds: 20);

  final RefreshController _refreshController = RefreshController();
  int? _selectedType;
  bool _onlyUnread = false;
  Timer? _pollingTimer;

  int? _parseOrderId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  void _navigateToOrderDetail(int orderId) {
    if (widget.nurseMode) {
      context.router.push(NurseTaskDetailRoute(orderId: orderId));
      return;
    }
    context.router.push(OrderDetailRoute(orderId: orderId.toString()));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPushCallback();
    // 加载通知列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(notificationListProvider.notifier)
          .loadNotifications(refresh: true);
      _startPolling();
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      if (!mounted) return;
      ref.read(notificationListProvider.notifier).refresh();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _handleAppResumed() {
    if (!mounted) return;
    ref.read(notificationListProvider.notifier).refresh();
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopPolling();
    }
  }

  /// 初始化推送回调
  void _initPushCallback() {
    PushService.instance.setNotificationCallback(
      onReceived: (notification) {
        // 收到新通知时刷新列表
        ref.read(notificationListProvider.notifier).refresh();
      },
      onOpened: (notification) {
        // 点击通知时跳转
        _handleNotificationClick(notification);
      },
    );
  }

  /// 处理通知点击
  void _handleNotificationClick(Map<String, dynamic> notification) {
    final typeRaw = notification['type'];
    final type = typeRaw is int
        ? typeRaw
        : int.tryParse(typeRaw?.toString() ?? '');
    final bizType = notification['biz_type']?.toString().toUpperCase();
    final orderId = _parseOrderId(
      notification['order_id'] ??
          notification['orderId'] ??
          notification['biz_id'],
    );
    final isOrderNotification =
        type == NotificationType.orderUpdate.value ||
        bizType == 'ORDER' ||
        bizType == 'PAY' ||
        bizType == 'REFUND';

    if (isOrderNotification && orderId != null) {
      _navigateToOrderDetail(orderId);
    }
  }

  /// 处理通知项点击
  void _onNotificationTap(NotificationModel notification) {
    // 标记为已读
    if (!notification.hasRead) {
      ref.read(notificationListProvider.notifier).markAsRead(notification.id);
    }

    // 根据类型跳转
    if (notification.notificationType == NotificationType.orderUpdate &&
        notification.orderId != null) {
      _navigateToOrderDetail(notification.orderId!);
      return;
    }

    _showNotificationDetail(notification);
  }

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    _refreshController.dispose();
    super.dispose();
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.orderUpdate:
        return Icons.receipt_long;
      case NotificationType.auditResult:
        return Icons.verified_user;
      case NotificationType.system:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.orderUpdate:
        return Colors.blue;
      case NotificationType.auditResult:
        return Colors.green;
      case NotificationType.system:
        return Colors.orange;
    }
  }

  String _formatTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final diff = now.difference(dateTime);

      if (diff.inMinutes < 1) {
        return '刚刚';
      } else if (diff.inHours < 1) {
        return '${diff.inMinutes}分钟前';
      } else if (diff.inDays < 1) {
        return '${diff.inHours}小时前';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}天前';
      } else {
        return DateFormat('MM-dd HH:mm').format(dateTime);
      }
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationListProvider);
    final notifications = _filteredNotifications(state.notifications);

    bool hasParentTabs = false;
    try {
      AutoTabsRouter.of(context);
      hasParentTabs = true;
    } catch (_) {
      hasParentTabs = false;
    }
    final hideInnerAppBar = widget.nurseMode && hasParentTabs;

    return Scaffold(
      appBar: hideInnerAppBar
          ? null
          : AppBar(
              title: const Text('消息中心'),
              centerTitle: true,
              actions: [
                if (state.unreadCount > 0)
                  TextButton(
                    onPressed: () {
                      ref
                          .read(notificationListProvider.notifier)
                          .markAllAsRead();
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('已全部标记为已读')));
                    },
                    child: const Text('全部已读'),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'clear') {
                      _showClearConfirmDialog();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20),
                          SizedBox(width: 8),
                          Text('清空消息'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: Column(
        children: [
          _buildSummaryHeader(state),
          _buildFilterBar(),
          Expanded(
            child: state.isLoading && state.notifications.isEmpty
                ? AppListSkeleton(
                    itemCount: 7,
                    itemHeight: 98,
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                  )
                : state.error != null && state.notifications.isEmpty
                ? _buildErrorView(state.error!)
                : notifications.isEmpty
                ? _buildEmptyView()
                : SmartRefresher(
                    controller: _refreshController,
                    enablePullDown: true,
                    enablePullUp: state.hasMore,
                    onRefresh: () async {
                      await ref
                          .read(notificationListProvider.notifier)
                          .refresh();
                      _refreshController.refreshCompleted();
                    },
                    onLoading: () async {
                      await ref
                          .read(notificationListProvider.notifier)
                          .loadMore();
                      _refreshController.loadComplete();
                    },
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationItem(notifications[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<NotificationModel> _filteredNotifications(
    List<NotificationModel> source,
  ) {
    return source.where((n) {
      if (_selectedType != null && n.type != _selectedType) return false;
      if (_onlyUnread && n.hasRead) return false;
      return true;
    }).toList();
  }

  Widget _buildSummaryHeader(NotificationListState state) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '共 ${state.notifications.length} 条消息',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '未读 ${state.unreadCount} 条',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (state.unreadCount > 0)
            FilledButton.tonal(
              onPressed: () async {
                await ref
                    .read(notificationListProvider.notifier)
                    .markAllAsRead();
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已全部标记为已读')));
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.18),
              ),
              child: Text(
                '全部已读',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final chips = <Map<String, dynamic>>[
      {'label': '全部', 'value': null},
      {
        'label': NotificationType.orderUpdate.text,
        'value': NotificationType.orderUpdate.value,
      },
      {
        'label': NotificationType.auditResult.text,
        'value': NotificationType.auditResult.value,
      },
      {
        'label': NotificationType.system.text,
        'value': NotificationType.system.value,
      },
    ];

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 8.h),
      padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          ...chips.map((item) {
            final selected = _selectedType == item['value'];
            return ChoiceChip(
              label: Text(item['label'] as String),
              selected: selected,
              onSelected: (_) =>
                  setState(() => _selectedType = item['value'] as int?),
              labelStyle: TextStyle(
                fontSize: 12.sp,
                color: selected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              selectedColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              backgroundColor: Colors.grey.withValues(alpha: 0.08),
              side: BorderSide(
                color: selected
                    ? AppTheme.primaryColor.withValues(alpha: 0.36)
                    : Colors.transparent,
              ),
            );
          }),
          FilterChip(
            label: Text('仅看未读', style: TextStyle(fontSize: 12.sp)),
            selected: _onlyUnread,
            onSelected: (v) => setState(() => _onlyUnread = v),
            selectedColor: Colors.red.withValues(alpha: 0.12),
            checkmarkColor: Colors.redAccent,
            side: BorderSide(color: Colors.red.withValues(alpha: 0.25)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    final hasFilter = _selectedType != null || _onlyUnread;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80.sp,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            hasFilter ? '当前筛选条件下暂无消息' : '暂无消息',
            style: TextStyle(
              fontSize: 16.sp,
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            hasFilter ? '试试切换筛选条件' : '订单状态更新、系统通知将在这里显示',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey),
          ),
          if (hasFilter) ...[
            SizedBox(height: 16.h),
            OutlinedButton(
              onPressed: () => setState(() {
                _selectedType = null;
                _onlyUnread = false;
              }),
              child: const Text('重置筛选'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return AppRetryGuide(
      title: '消息加载失败',
      message: error,
      onRetry: () => ref.read(notificationListProvider.notifier).refresh(),
      retryText: '重新获取',
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    final type = notification.notificationType;
    final isRead = notification.hasRead;

    return Dismissible(
      key: Key('notification_${notification.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        ref
            .read(notificationListProvider.notifier)
            .deleteNotification(notification.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已删除')));
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: EdgeInsets.only(bottom: 10.h),
        elevation: isRead ? 0 : 1,
        color: isRead ? Colors.white : Colors.blue.withValues(alpha: 0.03),
        child: InkWell(
          onTap: () => _onNotificationTap(notification),
          onLongPress: () => _showNotificationDetail(notification),
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图标
                Stack(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: _getTypeColor(type).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        _getTypeIcon(type),
                        color: _getTypeColor(type),
                        size: 24.sp,
                      ),
                    ),
                    if (!isRead)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10.w,
                          height: 10.w,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 12.w),
                // 内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title ?? type.text,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(notification.createdAt),
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        notification.content,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: isRead
                              ? AppTheme.textSecondaryColor
                              : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (notification.orderId != null) ...[
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Text(
                              widget.nurseMode ? '查看任务详情' : '查看订单详情',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 16.sp,
                              color: Theme.of(context).primaryColor,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotificationDetail(NotificationModel notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) {
        final type = notification.notificationType;
        final hasOrder = notification.orderId != null;

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 20.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title ?? type.text,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      _getTypeIcon(type),
                      size: 18.sp,
                      color: _getTypeColor(type),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      type.text,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: _getTypeColor(type),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!notification.hasRead) ...[
                      SizedBox(width: 8.w),
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '未读',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 12.h),
                Text(
                  notification.content,
                  style: TextStyle(fontSize: 14.sp, height: 1.5),
                ),
                SizedBox(height: 12.h),
                if (notification.createdAt != null)
                  _buildDetailRow('时间', _formatTime(notification.createdAt)),
                if (hasOrder)
                  _buildDetailRow(
                    widget.nurseMode ? '关联任务' : '关联订单',
                    '#${notification.orderId}',
                  ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('关闭'),
                      ),
                    ),
                    if (hasOrder) ...[
                      SizedBox(width: 10.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _navigateToOrderDetail(notification.orderId!);
                          },
                          child: Text(widget.nurseMode ? '查看任务' : '查看订单'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12.sp)),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空消息'),
        content: const Text('确定要清空所有消息吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(notificationListProvider.notifier).clearAll();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('已清空所有消息')));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
