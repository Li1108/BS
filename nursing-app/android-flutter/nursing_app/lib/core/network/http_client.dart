import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../services/storage_service.dart';
import '../utils/error_mapper.dart';

/// API 基础配置
class ApiConfig {
  /// 后端API基础URL
  static const String _definedBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static bool get hasCustomBaseUrl => _definedBaseUrl.trim().isNotEmpty;

  static String get baseUrl {
    final customBaseUrl = _definedBaseUrl.trim();
    if (customBaseUrl.isNotEmpty) return customBaseUrl;
    if (kIsWeb) return 'http://localhost:8081/api/v1';
    if (Platform.isAndroid) return 'http://10.0.2.2:8081/api/v1';
    return 'http://localhost:8081/api/v1';
  }

  static String? get realDeviceBaseUrlHint {
    if (hasCustomBaseUrl || kIsWeb) return null;
    if (Platform.isAndroid || Platform.isIOS) {
      return '检测到未配置 API_BASE_URL。真机请使用：flutter run --dart-define=API_BASE_URL=http://<电脑局域网IP>:8081/api/v1';
    }
    return null;
  }

  /// 连接超时时间
  static const Duration connectTimeout = Duration(seconds: 30);

  /// 接收超时时间
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// 发送超时时间
  static const Duration sendTimeout = Duration(seconds: 30);
}

/// 网络请求客户端
///
/// 基于 Dio 封装，支持 JWT Token 认证
/// 统一处理请求拦截、响应拦截、错误处理
class HttpClient {
  static HttpClient? _instance;
  late Dio _dio;
  final Logger _logger = Logger();

  HttpClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        validateStatus: (status) => true,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 添加拦截器
    _dio.interceptors.add(AuthInterceptor());
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => _logger.d(obj.toString()),
      ),
    );
  }

  static HttpClient get instance {
    _instance ??= HttpClient._internal();
    return _instance!;
  }

  Dio get dio => _dio;

  /// GET 请求
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// POST 请求
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PUT 请求
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// DELETE 请求
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// 上传文件
  Future<Response<T>> uploadFile<T>(
    String path, {
    required String filePath,
    String fileKey = 'file',
    Map<String, dynamic>? data,
  }) async {
    final formData = FormData.fromMap({
      fileKey: await MultipartFile.fromFile(filePath),
      if (data != null) ...data,
    });

    return _dio.post<T>(
      path,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }
}

String _snakeToCamel(String input) {
  if (!input.contains('_')) return input;
  final parts = input.split('_');
  if (parts.isEmpty) return input;
  final buffer = StringBuffer(parts.first);
  for (var i = 1; i < parts.length; i++) {
    final part = parts[i];
    if (part.isEmpty) continue;
    buffer.write(part[0].toUpperCase());
    if (part.length > 1) {
      buffer.write(part.substring(1));
    }
  }
  return buffer.toString();
}

String _camelToSnake(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
    if (isUpper && i > 0) {
      buffer.write('_');
    }
    buffer.write(char.toLowerCase());
  }
  return buffer.toString();
}

dynamic _convertKeys(dynamic value, String Function(String) keyMapper) {
  if (value is Map) {
    final mapped = <String, dynamic>{};
    value.forEach((k, v) {
      final key = k is String ? keyMapper(k) : k.toString();
      mapped[key] = _convertKeys(v, keyMapper);
    });
    return mapped;
  }
  if (value is List) {
    return value.map((e) => _convertKeys(e, keyMapper)).toList();
  }
  return value;
}

/// 认证拦截器
///
/// 自动添加 JWT Token 到请求头
/// 处理 Token 过期和刷新
class AuthInterceptor extends Interceptor {
  final StorageService _storage = StorageService.instance;
  final Logger _logger = Logger();

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 获取 Token
    final token = await _storage.getToken();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    if (options.data is Map || options.data is List) {
      options.data = _convertKeys(options.data, _snakeToCamel);
    }
    if (options.queryParameters.isNotEmpty) {
      options.queryParameters =
          (_convertKeys(options.queryParameters, _snakeToCamel) as Map)
              .cast<String, dynamic>();
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // 检查业务状态码
    final data = response.data;
    if (data is Map) {
      if (data['msg'] != null && data['message'] == null) {
        data['message'] = data['msg'];
      }
      if (data['message'] != null && data['msg'] == null) {
        data['msg'] = data['message'];
      }

      final code = _toInt(data['code']);
      if (code != null && code != 200 && code != 0) {
        if (code == 401 || code == 40100) {
          _storage.clearAuth();
        }
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            message: normalizeApiErrorMessage(
              businessCode: code,
              backendMessage: (data['msg'] ?? data['message'])?.toString(),
              fallback: '请求失败',
            ),
          ),
        );
        return;
      }
      if (data.containsKey('data')) {
        data['data'] = _convertKeys(data['data'], _camelToSnake);
      }
    }

    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final responseData = err.response?.data;
    int? businessCode;
    String? backendMessage;
    if (responseData is Map) {
      businessCode = _toInt(responseData['code']);
      backendMessage = (responseData['msg'] ?? responseData['message'])
          ?.toString();
    }

    if (businessCode == 401 ||
        businessCode == 40100 ||
        err.response?.statusCode == 401) {
      // Token 过期，清除认证信息
      await _storage.clearAuth();
    }

    final normalizedMessage = normalizeApiErrorMessage(
      businessCode: businessCode,
      statusCode: err.response?.statusCode,
      backendMessage: backendMessage,
      fallback: err.message,
    );
    _logger.e('请求错误: $normalizedMessage', error: err);

    final normalizedError = DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: err.error,
      stackTrace: err.stackTrace,
      message: normalizedMessage,
    );

    handler.next(normalizedError);
  }
}

/// API 响应封装
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;

  ApiResponse({required this.code, required this.message, this.data});

  bool get isSuccess => code == 200 || code == 0;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse(
      code: json['code'] ?? 0,
      message: (json['msg'] ?? json['message'] ?? '').toString(),
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'],
    );
  }
}

/// 分页响应封装
class PageResponse<T> {
  final List<T> records;
  final int total;
  final int current;
  final int size;
  final int pages;

  PageResponse({
    required this.records,
    required this.total,
    required this.current,
    required this.size,
    required this.pages,
  });

  bool get hasMore => current < pages;

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PageResponse(
      records:
          (json['records'] as List?)
              ?.map((e) => fromJsonT(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] ?? 0,
      current: json['current'] ?? 1,
      size: json['size'] ?? 10,
      pages: json['pages'] ?? 0,
    );
  }
}

/// HttpClient Provider
final httpClientProvider = Provider<HttpClient>((ref) {
  return HttpClient.instance;
});
