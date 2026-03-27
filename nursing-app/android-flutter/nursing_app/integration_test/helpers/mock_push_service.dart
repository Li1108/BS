import 'package:flutter/foundation.dart';

/// Mock推送服务
///
/// 用于集成测试中模拟阿里云移动推送SDK行为
class MockPushService {
  MockPushService._internal();

  static final MockPushService instance = MockPushService._internal();

  /// 模拟设备ID
  final String _deviceId = 'mock_device_id_12345';

  /// 绑定的账号
  String? _boundAccount;

  /// 绑定的标签
  final List<String> _boundTags = [];

  /// 通知回调
  Function(Map<String, dynamic>)? onNotificationReceived;
  Function(Map<String, dynamic>)? onNotificationOpened;

  /// 通知历史记录
  final List<Map<String, dynamic>> _notificationHistory = [];

  /// 初始化
  Future<void> init() async {
    debugPrint('[MockPushService] 初始化成功');
  }

  /// 获取设备ID
  String? getDeviceId() => _deviceId;

  /// 绑定账号
  Future<bool> bindAccount(String userId) async {
    _boundAccount = userId;
    debugPrint('[MockPushService] 绑定账号: $userId');
    return true;
  }

  /// 解绑账号
  Future<bool> unbindAccount() async {
    _boundAccount = null;
    debugPrint('[MockPushService] 解绑账号');
    return true;
  }

  /// 获取绑定的账号
  String? getBoundAccount() => _boundAccount;

  /// 绑定标签
  Future<bool> bindTag(List<String> tags) async {
    _boundTags.addAll(tags);
    debugPrint('[MockPushService] 绑定标签: $tags');
    return true;
  }

  /// 解绑标签
  Future<bool> unbindTag(List<String> tags) async {
    _boundTags.removeWhere((tag) => tags.contains(tag));
    debugPrint('[MockPushService] 解绑标签: $tags');
    return true;
  }

  /// 获取绑定的标签
  List<String> getBoundTags() => List.unmodifiable(_boundTags);

  /// 设置通知回调
  void setNotificationCallback({
    Function(Map<String, dynamic>)? onReceived,
    Function(Map<String, dynamic>)? onOpened,
  }) {
    onNotificationReceived = onReceived;
    onNotificationOpened = onOpened;
  }

  /// 模拟接收推送通知
  void simulateNotification(Map<String, dynamic> notification) {
    _notificationHistory.add(notification);
    debugPrint('[MockPushService] 接收通知: $notification');

    if (onNotificationReceived != null) {
      onNotificationReceived!(notification);
    }
  }

  /// 模拟点击推送通知
  void simulateNotificationOpened(Map<String, dynamic> notification) {
    debugPrint('[MockPushService] 点击通知: $notification');

    if (onNotificationOpened != null) {
      onNotificationOpened!(notification);
    }
  }

  /// 获取通知历史
  List<Map<String, dynamic>> getNotificationHistory() {
    return List.unmodifiable(_notificationHistory);
  }

  /// 清空通知历史
  void clearNotificationHistory() {
    _notificationHistory.clear();
  }

  /// 检查权限
  Future<bool> checkPermission() async => true;

  /// 请求权限
  Future<bool> requestPermission() async => true;

  /// 模拟新订单推送（护士端）
  void simulateNewOrderNotification({
    required String orderId,
    required String serviceName,
    required double distance,
    required String address,
  }) {
    simulateNotification({
      'title': '📍 附近有新订单',
      'body': '$serviceName - 距离您${distance.toStringAsFixed(1)}公里',
      'data': {
        'type': 'new_order',
        'orderId': orderId,
        'serviceName': serviceName,
        'distance': distance,
        'address': address,
      },
    });
  }

  /// 模拟订单状态更新推送（用户端）
  void simulateOrderStatusNotification({
    required String orderId,
    required int status,
    required String message,
  }) {
    simulateNotification({
      'title': '订单状态更新',
      'body': message,
      'data': {'type': 'order_status', 'orderId': orderId, 'status': status},
    });
  }

  /// 模拟审核结果推送（护士端）
  void simulateAuditResultNotification({required bool passed, String? reason}) {
    simulateNotification({
      'title': passed ? '🎉 审核通过' : '❌ 审核未通过',
      'body': passed ? '恭喜您，资质审核已通过，可以开始接单了！' : '很抱歉，您的资质审核未通过：$reason',
      'data': {'type': 'audit_result', 'passed': passed, 'reason': reason},
    });
  }

  /// 模拟提现结果推送（护士端）
  void simulateWithdrawResultNotification({
    required String withdrawId,
    required bool success,
    required double amount,
    String? reason,
  }) {
    simulateNotification({
      'title': success ? '💰 提现成功' : '❌ 提现失败',
      'body': success
          ? '您的提现申请（¥${amount.toStringAsFixed(2)}）已打款'
          : '您的提现申请（¥${amount.toStringAsFixed(2)}）被驳回：$reason',
      'data': {
        'type': 'withdraw_result',
        'withdrawId': withdrawId,
        'success': success,
        'amount': amount,
        'reason': reason,
      },
    });
  }
}
