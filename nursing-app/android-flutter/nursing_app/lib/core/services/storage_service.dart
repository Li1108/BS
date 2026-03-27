import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// 本地存储服务
///
/// 提供用户认证信息、配置信息的本地持久化存储
/// 使用 SharedPreferences 存储简单数据
/// 使用 Hive 存储复杂对象和离线数据
class StorageService {
  StorageService._internal();

  static final StorageService instance = StorageService._internal();

  late SharedPreferences _prefs;
  late Box _authBox;
  late Box _cacheBox;

  // ==================== 存储键定义 ====================

  static const String _keyToken = 'auth_token';
  static const String _keyUser = 'current_user';
  static const String _keyRole = 'user_role';
  static const String _keyIsFirstLaunch = 'is_first_launch';
  static const String _keyDeviceId = 'device_id';
  static const String _keyPushToken = 'push_token';

  // ==================== 初始化 ====================

  /// 初始化存储服务
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // 初始化 Hive boxes
    _authBox = await Hive.openBox('auth');
    _cacheBox = await Hive.openBox('cache');
  }

  // ==================== Token 相关 ====================

  /// 保存 JWT Token
  Future<void> saveToken(String token) async {
    await _authBox.put(_keyToken, token);
  }

  /// 获取 JWT Token
  Future<String?> getToken() async {
    return _authBox.get(_keyToken);
  }

  /// 删除 Token
  Future<void> removeToken() async {
    await _authBox.delete(_keyToken);
  }

  // ==================== 用户信息相关 ====================

  /// 保存用户信息
  Future<void> saveUser(Map<String, dynamic> userJson) async {
    await _authBox.put(_keyUser, jsonEncode(userJson));
  }

  /// 获取用户信息
  Future<Map<String, dynamic>?> getUser() async {
    final userStr = _authBox.get(_keyUser);
    if (userStr != null) {
      return jsonDecode(userStr) as Map<String, dynamic>;
    }
    return null;
  }

  /// 删除用户信息
  Future<void> removeUser() async {
    await _authBox.delete(_keyUser);
  }

  // ==================== 角色相关 ====================

  /// 保存用户角色
  Future<void> saveRole(String role) async {
    await _prefs.setString(_keyRole, role);
  }

  /// 获取用户角色
  String? getRole() {
    return _prefs.getString(_keyRole);
  }

  // ==================== 认证相关 ====================

  /// 清除所有认证信息
  Future<void> clearAuth() async {
    await _authBox.delete(_keyToken);
    await _authBox.delete(_keyUser);
    await _prefs.remove(_keyRole);
  }

  /// 检查是否已登录
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ==================== 应用配置相关 ====================

  /// 检查是否首次启动
  bool isFirstLaunch() {
    return _prefs.getBool(_keyIsFirstLaunch) ?? true;
  }

  /// 标记已启动过
  Future<void> setFirstLaunchDone() async {
    await _prefs.setBool(_keyIsFirstLaunch, false);
  }

  // ==================== 推送相关 ====================

  /// 保存设备ID（用于推送）
  Future<void> saveDeviceId(String deviceId) async {
    await _prefs.setString(_keyDeviceId, deviceId);
  }

  /// 获取设备ID
  String? getDeviceId() {
    return _prefs.getString(_keyDeviceId);
  }

  /// 保存推送Token
  Future<void> savePushToken(String token) async {
    await _prefs.setString(_keyPushToken, token);
  }

  /// 获取推送Token
  String? getPushToken() {
    return _prefs.getString(_keyPushToken);
  }

  // ==================== 缓存相关 ====================

  /// 保存缓存数据
  Future<void> saveCache(String key, dynamic value) async {
    if (value is Map || value is List) {
      await _cacheBox.put(key, jsonEncode(value));
    } else {
      await _cacheBox.put(key, value);
    }
  }

  /// 获取缓存数据
  dynamic getCache(String key) {
    final value = _cacheBox.get(key);
    if (value is String) {
      try {
        return jsonDecode(value);
      } catch (_) {
        return value;
      }
    }
    return value;
  }

  /// 删除缓存数据
  Future<void> removeCache(String key) async {
    await _cacheBox.delete(key);
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    await _cacheBox.clear();
  }

  // ==================== 地址缓存 ====================

  /// 缓存用户地址列表
  Future<void> cacheAddresses(List<Map<String, dynamic>> addresses) async {
    await saveCache('user_addresses', addresses);
  }

  /// 获取缓存的地址列表
  List<Map<String, dynamic>>? getCachedAddresses() {
    final data = getCache('user_addresses');
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }

  // ==================== 服务项目缓存 ====================

  /// 缓存服务项目列表
  Future<void> cacheServices(List<Map<String, dynamic>> services) async {
    await saveCache('service_items', services);
  }

  /// 获取缓存的服务项目列表
  List<Map<String, dynamic>>? getCachedServices() {
    final data = getCache('service_items');
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }

  /// 缓存订单列表（按状态维度）
  Future<void> cacheOrders(
    List<Map<String, dynamic>> orders, {
    String statusKey = 'all',
  }) async {
    await saveCache('orders_$statusKey', orders);
  }

  /// 获取缓存订单列表（按状态维度）
  List<Map<String, dynamic>>? getCachedOrders({String statusKey = 'all'}) {
    final data = getCache('orders_$statusKey');
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }

  /// 缓存服务项目列表（按分类维度）
  Future<void> cacheServicesByCategory(
    List<Map<String, dynamic>> services, {
    String categoryKey = 'all',
  }) async {
    await saveCache('service_items_$categoryKey', services);
  }

  /// 获取缓存服务项目列表（按分类维度）
  List<Map<String, dynamic>>? getCachedServicesByCategory({
    String categoryKey = 'all',
  }) {
    final data = getCache('service_items_$categoryKey');
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return null;
  }
}
