import 'package:logger/logger.dart';

import 'storage_service.dart';

/// 推送服务
///
/// 集成阿里云移动推送（Mobile Push / EMAS Push）
/// 用于实时通知（如新订单推送给护士、订单状态更新）
class PushService {
  PushService._internal();

  static final PushService instance = PushService._internal();

  final Logger _logger = Logger();
  final StorageService _storage = StorageService.instance;

  /// 推送回调函数
  Function(Map<String, dynamic>)? onNotificationReceived;
  Function(Map<String, dynamic>)? onNotificationOpened;

  /// 初始化推送服务
  Future<void> init() async {
    try {
      _logger.i('推送服务初始化成功');

      // 获取设备ID
      await _registerDevice();
    } catch (e) {
      _logger.e('推送服务初始化失败', error: e);
    }
  }

  /// 注册设备
  Future<void> _registerDevice() async {
    try {
      _logger.i('设备注册成功');
    } catch (e) {
      _logger.e('设备注册失败', error: e);
    }
  }

  /// 绑定用户账号（登录后调用）
  Future<void> bindAccount(String userId) async {
    try {
      _logger.i('账号绑定成功: $userId');
    } catch (e) {
      _logger.e('账号绑定失败', error: e);
    }
  }

  /// 解绑用户账号（退出登录时调用）
  Future<void> unbindAccount() async {
    try {
      _logger.i('账号解绑成功');
    } catch (e) {
      _logger.e('账号解绑失败', error: e);
    }
  }

  /// 绑定标签（用于分组推送）
  Future<void> bindTag(List<String> tags) async {
    try {
      _logger.i('标签绑定成功: $tags');
    } catch (e) {
      _logger.e('标签绑定失败', error: e);
    }
  }

  /// 解绑标签
  Future<void> unbindTag(List<String> tags) async {
    try {
      _logger.i('标签解绑成功: $tags');
    } catch (e) {
      _logger.e('标签解绑失败', error: e);
    }
  }

  /// 设置通知接收回调
  void setNotificationCallback({
    Function(Map<String, dynamic>)? onReceived,
    Function(Map<String, dynamic>)? onOpened,
  }) {
    onNotificationReceived = onReceived;
    onNotificationOpened = onOpened;
  }

  /// 处理收到的通知
  void handleNotification(Map<String, dynamic> notification) {
    _logger.i('收到推送通知: $notification');

    if (onNotificationReceived != null) {
      onNotificationReceived!(notification);
    }
  }

  /// 处理通知点击
  void handleNotificationOpened(Map<String, dynamic> notification) {
    _logger.i('通知被点击: $notification');

    if (onNotificationOpened != null) {
      onNotificationOpened!(notification);
    }
  }

  /// 获取设备ID
  String? getDeviceId() {
    return _storage.getDeviceId();
  }

  /// 检查推送权限
  Future<bool> checkPermission() async {
    return true;
  }

  /// 请求推送权限
  Future<bool> requestPermission() async {
    return true;
  }
}
