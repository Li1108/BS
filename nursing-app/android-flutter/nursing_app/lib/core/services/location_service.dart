import 'dart:async';
import 'dart:convert';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// 位置信息模型
class LocationInfo {
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? district;
  final String? street;
  final String? streetNumber;
  final String? poiName;
  final String? aoiName;
  final int? errorCode;
  final String? errorInfo;

  LocationInfo({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
    this.district,
    this.street,
    this.streetNumber,
    this.poiName,
    this.aoiName,
    this.errorCode,
    this.errorInfo,
  });

  /// 从高德定位结果构造
  factory LocationInfo.fromAMapLocation(Map<String, Object> result) {
    return LocationInfo(
      latitude: result['latitude'] as double? ?? 0.0,
      longitude: result['longitude'] as double? ?? 0.0,
      address: result['address'] as String?,
      city: result['city'] as String?,
      district: result['district'] as String?,
      street: result['street'] as String?,
      streetNumber: result['streetNumber'] as String?,
      poiName: result['poiName'] as String?,
      aoiName: result['aoiName'] as String?,
      errorCode: result['errorCode'] as int?,
      errorInfo: result['errorInfo'] as String?,
    );
  }

  /// 是否定位成功
  bool get isSuccess => errorCode == null || errorCode == 0;

  /// 获取完整地址
  String get fullAddress {
    if (address != null && address!.isNotEmpty) {
      return address!;
    }
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (district != null && district!.isNotEmpty) parts.add(district!);
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (streetNumber != null && streetNumber!.isNotEmpty) {
      parts.add(streetNumber!);
    }
    return parts.join('');
  }

  /// 获取简短地址
  String get shortAddress {
    if (poiName != null && poiName!.isNotEmpty) {
      return poiName!;
    }
    if (aoiName != null && aoiName!.isNotEmpty) {
      return aoiName!;
    }
    if (street != null && street!.isNotEmpty) {
      return '$street${streetNumber ?? ''}';
    }
    return district ?? city ?? '未知位置';
  }

  @override
  String toString() {
    return 'LocationInfo(lat: $latitude, lng: $longitude, address: $address)';
  }
}

/// 高德地图位置服务
///
/// 提供以下功能：
/// - 获取当前位置
/// - 持续定位
/// - 地理编码（地址转坐标）
/// - 逆地理编码（坐标转地址）
class LocationService {
  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();

  LocationService._();

  final AMapFlutterLocation _locationPlugin = AMapFlutterLocation();
  final Dio _amapDio = Dio(
    BaseOptions(
      baseUrl: 'https://restapi.amap.com',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );
  StreamSubscription<Map<String, Object>>? _locationListener;

  /// 当前位置信息
  LocationInfo? _currentLocation;
  LocationInfo? get currentLocation => _currentLocation;

  /// 位置更新流
  final StreamController<LocationInfo> _locationStreamController =
      StreamController<LocationInfo>.broadcast();
  Stream<LocationInfo> get locationStream => _locationStreamController.stream;

  /// 是否正在定位
  bool _isLocating = false;
  bool get isLocating => _isLocating;

  /// 高德地图 API Key
  static const String _androidKey = String.fromEnvironment(
    'AMAP_ANDROID_KEY',
    defaultValue: '27099005ec372959e5e03ad1faa54fa1',
  );
  static const String _iosKey = String.fromEnvironment(
    'AMAP_IOS_KEY',
    defaultValue: '',
  );
  static const String _webKey = String.fromEnvironment(
    'AMAP_WEB_KEY',
    defaultValue: 'df22b248a42376a336b45793da8e9d96',
  );
  static const String _webSecurityCode = String.fromEnvironment(
    'AMAP_WEB_SECURITY_CODE',
    defaultValue: '',
  );

  String get _effectiveWebKey {
    final key = _webKey.trim();
    if (key.isNotEmpty) return key;
    return _androidKey.trim();
  }

  String get _effectiveWebSecurityCode => _webSecurityCode.trim();

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String? _toText(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  Map<String, dynamic> _withSecuritySignature(Map<String, dynamic> query) {
    final securityCode = _effectiveWebSecurityCode;
    if (securityCode.isEmpty) return query;

    final sortedKeys = query.keys.toList()..sort();
    final buffer = StringBuffer();
    for (var i = 0; i < sortedKeys.length; i++) {
      final key = sortedKeys[i];
      final value = query[key];
      if (value == null) continue;
      if (buffer.isNotEmpty) {
        buffer.write('&');
      }
      buffer.write('$key=$value');
    }
    buffer.write(securityCode);

    final sig = md5.convert(utf8.encode(buffer.toString())).toString();
    return {...query, 'sig': sig};
  }

  /// 初始化定位服务
  Future<void> init() async {
    // 设置 API Key
    if (_androidKey.isNotEmpty || _iosKey.isNotEmpty) {
      AMapFlutterLocation.setApiKey(_androidKey, _iosKey);
    }

    // 设置隐私政策
    AMapFlutterLocation.updatePrivacyAgree(true);
    AMapFlutterLocation.updatePrivacyShow(true, true);

    // 监听定位结果
    _locationListener = _locationPlugin.onLocationChanged().listen((
      Map<String, Object> result,
    ) {
      final locationInfo = LocationInfo.fromAMapLocation(result);
      _currentLocation = locationInfo;
      _locationStreamController.add(locationInfo);
      debugPrint('LocationService: 定位结果 - ${locationInfo.fullAddress}');
    });
  }

  /// 请求定位权限
  Future<bool> requestPermission() async {
    // 检查定位服务是否开启
    final serviceStatus = await Permission.location.serviceStatus;
    if (!serviceStatus.isEnabled) {
      debugPrint('LocationService: 定位服务未开启');
      return false;
    }

    // 请求权限
    var status = await Permission.location.status;
    if (status.isDenied) {
      status = await Permission.location.request();
    }

    if (status.isPermanentlyDenied) {
      debugPrint('LocationService: 定位权限被永久拒绝');
      // 可以引导用户去设置页面开启
      return false;
    }

    return status.isGranted;
  }

  /// 获取当前位置（单次定位）
  Future<LocationInfo?> getCurrentLocation({bool needAddress = true}) async {
    // 请求权限
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('LocationService: 没有定位权限');
      return null;
    }

    _isLocating = true;

    // 设置定位参数
    _setLocationOption(onceLocation: true, needAddress: needAddress);

    // 开始定位
    _locationPlugin.startLocation();

    // 等待定位结果
    try {
      final result = await _locationStreamController.stream.first.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('定位超时');
        },
      );
      _locationPlugin.stopLocation();
      _isLocating = false;
      return result;
    } catch (e) {
      debugPrint('LocationService: 定位失败 - $e');
      _locationPlugin.stopLocation();
      _isLocating = false;
      return null;
    }
  }

  /// 开始持续定位
  void startContinuousLocation({
    int interval = 2000,
    bool needAddress = true,
  }) async {
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      debugPrint('LocationService: 没有定位权限');
      return;
    }

    _isLocating = true;
    _setLocationOption(
      onceLocation: false,
      needAddress: needAddress,
      interval: interval,
    );
    _locationPlugin.startLocation();
  }

  /// 停止持续定位
  void stopContinuousLocation() {
    _locationPlugin.stopLocation();
    _isLocating = false;
  }

  /// 设置定位参数
  void _setLocationOption({
    required bool onceLocation,
    bool needAddress = true,
    int interval = 2000,
  }) {
    final option = AMapLocationOption();

    // 是否单次定位
    option.onceLocation = onceLocation;

    // 是否需要返回逆地理信息
    option.needAddress = needAddress;

    // 定位间隔（毫秒）
    option.locationInterval = interval;

    // 定位精度（高精度模式）
    option.locationMode = AMapLocationMode.Hight_Accuracy;

    // Android 参数设置
    option.desiredAccuracy = DesiredAccuracy.Best;
    option.desiredLocationAccuracyAuthorizationMode =
        AMapLocationAccuracyAuthorizationMode.FullAccuracy;

    // iOS 参数设置
    option.distanceFilter = -1;
    option.geoLanguage = GeoLanguage.DEFAULT;

    _locationPlugin.setLocationOption(option);
  }

  /// 销毁定位服务
  void dispose() {
    _locationListener?.cancel();
    _locationPlugin.destroy();
    _locationStreamController.close();
  }

  /// 获取当前位置（简化版，返回Map）
  Future<Map<String, dynamic>?> getCurrentLocationMap() async {
    final location = await getCurrentLocation(needAddress: true);
    if (location == null) return null;

    return {
      'latitude': location.latitude,
      'longitude': location.longitude,
      'address': location.fullAddress,
      'province': null, // 高德定位SDK不直接返回省份
      'city': location.city,
      'district': location.district,
    };
  }

  /// 根据经纬度获取地址信息（逆地理编码）
  Future<Map<String, dynamic>?> getAddressFromLocation(
    double latitude,
    double longitude,
  ) async {
    final key = _effectiveWebKey;
    if (key.isEmpty) {
      debugPrint('LocationService: 逆地理编码失败，未配置 AMAP_WEB_KEY');
      return null;
    }

    try {
      final response = await _amapDio.get<Map<String, dynamic>>(
        '/v3/geocode/regeo',
        queryParameters: _withSecuritySignature({
          'key': key,
          'location': '$longitude,$latitude',
          'extensions': 'base',
          'radius': 200,
          'output': 'json',
        }),
      );

      final data = response.data;
      final status = data?['status']?.toString() == '1';
      if (!status) {
        debugPrint('LocationService: 逆地理编码失败 - ${data?['info']}');
        return null;
      }

      final regeocode = data?['regeocode'];
      if (regeocode is! Map) return null;
      final component = regeocode['addressComponent'];
      final formattedAddress =
          _toText(regeocode['formatted_address']) ??
          _toText(regeocode['formattedAddress']);

      String? province;
      String? city;
      String? district;
      if (component is Map) {
        province = _toText(component['province']);
        city = _toText(component['city']);
        district = _toText(component['district']);
      }

      return {
        'latitude': latitude,
        'longitude': longitude,
        'address': formattedAddress,
        'province': province,
        'city': city,
        'district': district,
      };
    } catch (e) {
      debugPrint('LocationService: 逆地理编码异常 - $e');
      return null;
    }
  }

  /// 地址搜索（地理编码）
  Future<List<Map<String, dynamic>>> searchAddress(String keyword) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) return [];

    final key = _effectiveWebKey;
    if (key.isEmpty) {
      debugPrint('LocationService: 地址搜索失败，未配置 AMAP_WEB_KEY');
      return [];
    }

    try {
      final response = await _amapDio.get<Map<String, dynamic>>(
        '/v3/assistant/inputtips',
        queryParameters: _withSecuritySignature({
          'key': key,
          'keywords': trimmedKeyword,
          'datatype': 'all',
          'citylimit': false,
          'output': 'json',
        }),
      );

      final data = response.data;
      final status = data?['status']?.toString() == '1';
      if (!status) {
        final info = data?['info']?.toString() ?? '未知错误';
        final infocode = data?['infocode']?.toString() ?? 'UNKNOWN';
        final detail = '高德地址搜索失败：$info（$infocode）';
        debugPrint('LocationService: $detail');
        throw Exception(detail);
      }

      final tips = data?['tips'];
      if (tips is! List) return [];

      final results = <Map<String, dynamic>>[];
      for (final item in tips) {
        if (item is! Map) continue;
        final location = _toText(item['location']);
        if (location == null || !location.contains(',')) continue;

        final parts = location.split(',');
        if (parts.length != 2) continue;

        final lng = _toDouble(parts[0]);
        final lat = _toDouble(parts[1]);
        if (lng == null || lat == null) continue;

        final name = _toText(item['name']) ?? trimmedKeyword;
        final district = _toText(item['district']);
        final addressPart = _toText(item['address']);

        String address = '';
        if (district != null) {
          address = district;
        }
        if (addressPart != null && addressPart != '[]') {
          address = address.isEmpty ? addressPart : '$address$addressPart';
        }
        if (address.isEmpty) {
          address = name;
        }

        results.add({
          'name': name,
          'address': address,
          'latitude': lat,
          'longitude': lng,
          'province': null,
          'city': null,
          'district': district,
        });
      }

      return results;
    } catch (e) {
      debugPrint('LocationService: 地址搜索异常 - $e');
      return [];
    }
  }
}

/// 位置服务 Provider
final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService.instance;
  service.init();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// 当前位置 Provider
final currentLocationProvider = FutureProvider<LocationInfo?>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return await service.getCurrentLocation();
});

/// 持续位置流 Provider
final locationStreamProvider = StreamProvider<LocationInfo>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.locationStream;
});
