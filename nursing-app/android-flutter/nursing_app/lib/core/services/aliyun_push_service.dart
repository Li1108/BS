import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'storage_service.dart';

/// 阿里云移动推送服务
///
/// 集成阿里云移动推送（Mobile Push / EMAS Push）
/// 支持自有通道 + 厂商通道（华为、小米、OPPO、vivo等）
///
/// 功能：
/// 1. 设备注册与管理
/// 2. 账号绑定/解绑（登录/退出时调用）
/// 3. 标签绑定（用于分组推送，如护士/用户）
/// 4. 别名设置（用于精准推送）
/// 5. 推送消息接收与处理
/// 6. 通知点击跳转处理
class AliyunPushService {
  AliyunPushService._internal();

  static final AliyunPushService instance = AliyunPushService._internal();

  final Logger _logger = Logger();
  final StorageService _storage = StorageService.instance;

  /// 平台通道（与原生Android/iOS通信）
  static const MethodChannel _channel = MethodChannel(
    'com.nursing_app/aliyun_push',
  );

  /// 推送回调
  Function(Map<String, dynamic>)? onNotificationReceived;
  Function(Map<String, dynamic>)? onNotificationOpened;
  Function(String)? onDeviceTokenReceived;

  /// 设备ID
  String? _deviceId;

  /// 初始化状态
  bool _isInitialized = false;

  /// 初始化推送服务
  ///
  /// 需要在应用启动时调用（main.dart或App初始化）
  Future<void> init() async {
    if (_isInitialized) {
      _logger.w('推送服务已初始化，跳过');
      return;
    }

    try {
      // 设置方法通道回调处理器
      _channel.setMethodCallHandler(_handleMethodCall);

      // 调用原生SDK初始化
      final result = await _channel.invokeMethod<Map>('init');

      if (result?['success'] == true) {
        _deviceId = result?['deviceId'];
        _isInitialized = true;
        _logger.i('阿里云推送服务初始化成功，设备ID: $_deviceId');

        // 保存设备ID
        if (_deviceId != null) {
          await _storage.saveDeviceId(_deviceId!);
        }

        // 触发设备Token回调
        if (onDeviceTokenReceived != null && _deviceId != null) {
          onDeviceTokenReceived!(_deviceId!);
        }
      } else {
        _logger.e('阿里云推送服务初始化失败: ${result?['error']}');
      }
    } on PlatformException catch (e) {
      _logger.e('阿里云推送服务初始化异常', error: e);
    } catch (e) {
      _logger.e('阿里云推送服务初始化未知错误', error: e);
    }
  }

  /// 处理来自原生端的方法调用
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationReceived':
        _handleNotificationReceived(Map<String, dynamic>.from(call.arguments));
        break;
      case 'onNotificationOpened':
        _handleNotificationOpened(Map<String, dynamic>.from(call.arguments));
        break;
      case 'onDeviceTokenReceived':
        _deviceId = call.arguments as String;
        if (onDeviceTokenReceived != null) {
          onDeviceTokenReceived!(_deviceId!);
        }
        break;
      default:
        _logger.w('未处理的方法调用: ${call.method}');
    }
  }

  /// 处理收到的通知
  void _handleNotificationReceived(Map<String, dynamic> notification) {
    _logger.i('收到推送通知: $notification');

    // 解析通知数据
    final parsedNotification = _parseNotification(notification);

    if (onNotificationReceived != null) {
      onNotificationReceived!(parsedNotification);
    }
  }

  /// 处理通知点击
  void _handleNotificationOpened(Map<String, dynamic> notification) {
    _logger.i('通知被点击: $notification');

    // 解析通知数据
    final parsedNotification = _parseNotification(notification);

    if (onNotificationOpened != null) {
      onNotificationOpened!(parsedNotification);
    }
  }

  /// 解析通知数据
  Map<String, dynamic> _parseNotification(Map<String, dynamic> raw) {
    return {
      'title': raw['title'] ?? '',
      'body': raw['body'] ?? raw['content'] ?? '',
      'data': raw['extras'] ?? raw['data'] ?? {},
      'messageId': raw['messageId'] ?? raw['msgId'],
      'receivedAt': DateTime.now().toIso8601String(),
    };
  }

  /// 获取设备ID
  String? getDeviceId() => _deviceId ?? _storage.getDeviceId();

  /// 绑定账号（登录后调用）
  ///
  /// 账号绑定后，可通过账号推送消息
  Future<bool> bindAccount(String userId) async {
    if (!_isInitialized) {
      _logger.w('推送服务未初始化，无法绑定账号');
      return false;
    }

    try {
      final result = await _channel.invokeMethod<Map>('bindAccount', {
        'account': userId,
      });

      if (result?['success'] == true) {
        _logger.i('账号绑定成功: $userId');
        return true;
      } else {
        _logger.e('账号绑定失败: ${result?['error']}');
        return false;
      }
    } catch (e) {
      _logger.e('账号绑定异常', error: e);
      return false;
    }
  }

  /// 解绑账号（退出登录时调用）
  Future<bool> unbindAccount() async {
    if (!_isInitialized) {
      _logger.w('推送服务未初始化，无法解绑账号');
      return false;
    }

    try {
      final result = await _channel.invokeMethod<Map>('unbindAccount');

      if (result?['success'] == true) {
        _logger.i('账号解绑成功');
        return true;
      } else {
        _logger.e('账号解绑失败: ${result?['error']}');
        return false;
      }
    } catch (e) {
      _logger.e('账号解绑异常', error: e);
      return false;
    }
  }

  /// 绑定标签（用于分组推送）
  ///
  /// 示例标签：
  /// - nurse: 护士用户
  /// - user: 普通用户
  /// - work_mode_on: 工作模式开启的护士
  /// - city_hangzhou: 杭州地区
  Future<bool> bindTag(List<String> tags, {int target = 1}) async {
    if (!_isInitialized || tags.isEmpty) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<Map>('bindTag', {
        'tags': tags,
        'target': target, // 1: 设备，2: 账号，3: 别名
      });

      if (result?['success'] == true) {
        _logger.i('标签绑定成功: $tags');
        return true;
      } else {
        _logger.e('标签绑定失败: ${result?['error']}');
        return false;
      }
    } catch (e) {
      _logger.e('标签绑定异常', error: e);
      return false;
    }
  }

  /// 解绑标签
  Future<bool> unbindTag(List<String> tags, {int target = 1}) async {
    if (!_isInitialized || tags.isEmpty) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<Map>('unbindTag', {
        'tags': tags,
        'target': target,
      });

      if (result?['success'] == true) {
        _logger.i('标签解绑成功: $tags');
        return true;
      } else {
        _logger.e('标签解绑失败: ${result?['error']}');
        return false;
      }
    } catch (e) {
      _logger.e('标签解绑异常', error: e);
      return false;
    }
  }

  /// 设置别名（用于精准推送）
  Future<bool> setAlias(String alias) async {
    if (!_isInitialized) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<Map>('addAlias', {
        'alias': alias,
      });

      if (result?['success'] == true) {
        _logger.i('别名设置成功: $alias');
        return true;
      } else {
        _logger.e('别名设置失败: ${result?['error']}');
        return false;
      }
    } catch (e) {
      _logger.e('别名设置异常', error: e);
      return false;
    }
  }

  /// 移除别名
  Future<bool> removeAlias(String alias) async {
    if (!_isInitialized) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<Map>('removeAlias', {
        'alias': alias,
      });

      if (result?['success'] == true) {
        _logger.i('别名移除成功: $alias');
        return true;
      } else {
        _logger.e('别名移除失败: ${result?['error']}');
        return false;
      }
    } catch (e) {
      _logger.e('别名移除异常', error: e);
      return false;
    }
  }

  /// 设置通知回调
  void setNotificationCallback({
    Function(Map<String, dynamic>)? onReceived,
    Function(Map<String, dynamic>)? onOpened,
    Function(String)? onDeviceToken,
  }) {
    onNotificationReceived = onReceived;
    onNotificationOpened = onOpened;
    onDeviceTokenReceived = onDeviceToken;
  }

  /// 检查推送权限
  Future<bool> checkPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkPermission');
      return result ?? false;
    } catch (e) {
      _logger.e('检查推送权限异常', error: e);
      return false;
    }
  }

  /// 请求推送权限
  Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } catch (e) {
      _logger.e('请求推送权限异常', error: e);
      return false;
    }
  }

  /// 清除所有通知
  Future<void> clearAllNotifications() async {
    try {
      await _channel.invokeMethod('clearNotifications');
    } catch (e) {
      _logger.e('清除通知异常', error: e);
    }
  }

  /// 设置角标数量（iOS）
  Future<void> setBadgeNumber(int count) async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('setBadgeNumber', {'count': count});
    } catch (e) {
      _logger.e('设置角标异常', error: e);
    }
  }

  /// 获取初始化状态
  bool get isInitialized => _isInitialized;

  /// 便捷方法：绑定护士标签
  Future<void> bindNurseTags({
    required String nurseId,
    required String city,
    required bool workModeOn,
  }) async {
    final tags = <String>[
      'nurse',
      'nurse_$nurseId',
      'city_$city',
      if (workModeOn) 'work_mode_on' else 'work_mode_off',
    ];
    await bindTag(tags);
  }

  /// 便捷方法：更新护士工作模式标签
  Future<void> updateWorkModeTag(bool workModeOn) async {
    if (workModeOn) {
      await unbindTag(['work_mode_off']);
      await bindTag(['work_mode_on']);
    } else {
      await unbindTag(['work_mode_on']);
      await bindTag(['work_mode_off']);
    }
  }

  /// 便捷方法：绑定用户标签
  Future<void> bindUserTags({required String userId, String? city}) async {
    final tags = <String>[
      'user',
      'user_$userId',
      if (city != null) 'city_$city',
    ];
    await bindTag(tags);
  }
}
