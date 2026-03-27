import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../../core/network/http_client.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/error_mapper.dart';
import '../models/address_model.dart';

/// 地址仓库
///
/// 处理地址相关的API请求
class AddressRepository {
  final HttpClient _http;
  final Logger _logger = Logger();

  AddressRepository(this._http);

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _buildAddressText(Map<String, dynamic> raw) {
    final province = raw['province']?.toString() ?? '';
    final city = raw['city']?.toString() ?? '';
    final district = raw['district']?.toString() ?? '';
    final detail =
        raw['detail_address']?.toString() ??
        raw['detail']?.toString() ??
        raw['address']?.toString() ??
        '';
    final merged = '$province$city$district$detail'.trim();
    return merged.isEmpty ? detail : merged;
  }

  Map<String, dynamic> _normalizeAddress(Map<String, dynamic> raw) {
    return {
      'id': _toInt(raw['id']) ?? 0,
      'user_id': _toInt(raw['user_id']) ?? 0,
      'address': _buildAddressText(raw),
      'contact_name': raw['contact_name']?.toString() ?? '',
      'contact_phone': raw['contact_phone']?.toString() ?? '',
      'is_default': _toInt(raw['is_default']) ?? 0,
      'latitude': _toDouble(raw['latitude']),
      'longitude': _toDouble(raw['longitude']),
      'province': raw['province']?.toString(),
      'city': raw['city']?.toString(),
      'district': raw['district']?.toString(),
      'detail': raw['detail']?.toString() ?? raw['detail_address']?.toString(),
      'created_at':
          raw['created_at']?.toString() ?? raw['create_time']?.toString(),
    };
  }

  Map<String, dynamic> _buildBackendPayload(AddressRequest request) {
    final payload = request.toJson();
    payload['detail_address'] = request.detail?.trim().isNotEmpty == true
        ? request.detail
        : request.address;
    payload.remove('address');
    payload.remove('detail');
    return payload;
  }

  /// 获取地址列表
  Future<List<AddressModel>> getAddresses() async {
    try {
      final response = await _http.get('/user/address/list');
      final result = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );
      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }
      final addresses = result.data!
          .map(
            (item) => AddressModel.fromJson(
              _normalizeAddress(Map<String, dynamic>.from(item as Map)),
            ),
          )
          .toList();
      await StorageService.instance.cacheAddresses(
        addresses.map((e) => e.toJson()).toList(),
      );
      return addresses;
    } on DioException catch (e) {
      _logger.e('获取地址列表失败', error: e);
      final cached = StorageService.instance.getCachedAddresses();
      if (cached != null && cached.isNotEmpty) {
        return cached.map(AddressModel.fromJson).toList();
      }
      throw Exception(normalizeErrorMessage(e, fallback: '加载地址列表失败'));
    }
  }

  /// 获取单个地址
  Future<AddressModel?> getAddress(int addressId) async {
    try {
      final list = await getAddresses();
      for (final item in list) {
        if (item.id == addressId) return item;
      }
      return null;
    } on DioException catch (e) {
      _logger.e('获取地址失败', error: e);
      return null;
    }
  }

  /// 获取默认地址
  Future<AddressModel?> getDefaultAddress() async {
    try {
      final list = await getAddresses();
      for (final item in list) {
        if (item.isDefaultAddress) {
          return item;
        }
      }
      return list.isNotEmpty ? list.first : null;
    } on DioException catch (e) {
      _logger.e('获取默认地址失败', error: e);
      return null;
    }
  }

  /// 添加地址
  Future<AddressModel?> addAddress(AddressRequest request) async {
    try {
      final response = await _http.post(
        '/user/address/add',
        data: _buildBackendPayload(request),
      );
      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }
      return AddressModel.fromJson(_normalizeAddress(result.data!));
    } on DioException catch (e) {
      _logger.e('添加地址失败', error: e);
      throw Exception(normalizeErrorMessage(e, fallback: '添加地址失败'));
    }
  }

  /// 更新地址
  Future<bool> updateAddress(int addressId, AddressRequest request) async {
    try {
      final response = await _http.put(
        '/user/address/update/$addressId',
        data: _buildBackendPayload(request),
      );
      final result = ApiResponse.fromJson(response.data, null);
      return result.isSuccess;
    } on DioException catch (e) {
      _logger.e('更新地址失败', error: e);
      return false;
    }
  }

  /// 删除地址
  Future<bool> deleteAddress(int addressId) async {
    try {
      final response = await _http.delete('/user/address/delete/$addressId');
      final result = ApiResponse.fromJson(response.data, null);
      return result.isSuccess;
    } on DioException catch (e) {
      _logger.e('删除地址失败', error: e);
      return false;
    }
  }

  /// 设为默认地址
  Future<bool> setDefault(int addressId) async {
    try {
      final response = await _http.post('/user/address/setDefault/$addressId');
      final result = ApiResponse.fromJson(response.data, null);
      return result.isSuccess;
    } on DioException catch (e) {
      _logger.e('设置默认地址失败', error: e);
      return false;
    }
  }
}

/// AddressRepository Provider
final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepository(HttpClient.instance);
});
