import '../../../../core/network/http_client.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/error_mapper.dart';
import '../models/service_model.dart';

/// 服务仓库
///
/// 处理护理服务相关的 API 请求
class ServiceRepository {
  final HttpClient _http = HttpClient.instance;
  final Map<int, String> _orderNoCache = {};

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

  Future<Map<int, String>> _loadCategoryNameMap() async {
    final response = await _http.get('/service/category/list');
    final result = ApiResponse<List<dynamic>>.fromJson(
      response.data,
      (data) => data as List<dynamic>,
    );
    final map = <int, String>{};
    if (!result.isSuccess || result.data == null) return map;
    for (final item in result.data!) {
      final raw = Map<String, dynamic>.from(item as Map);
      final id = _toInt(raw['id']);
      final name = raw['category_name']?.toString();
      if (id != null && name != null) {
        map[id] = name;
      }
    }
    return map;
  }

  Future<int?> _resolveCategoryIdByName(String categoryName) async {
    final response = await _http.get('/service/category/list');
    final result = ApiResponse<List<dynamic>>.fromJson(
      response.data,
      (data) => data as List<dynamic>,
    );
    if (!result.isSuccess || result.data == null) return null;
    for (final item in result.data!) {
      final raw = Map<String, dynamic>.from(item as Map);
      if (raw['category_name']?.toString() == categoryName) {
        return _toInt(raw['id']);
      }
    }
    return null;
  }

  Map<String, dynamic> _normalizeService(
    Map<String, dynamic> raw,
    Map<int, String> categoryMap,
  ) {
    final categoryId = _toInt(raw['category_id']);
    return {
      'id': _toInt(raw['id']) ?? 0,
      'name': raw['name']?.toString() ?? raw['service_name']?.toString() ?? '',
      'price': _toDouble(raw['price']) ?? 0,
      'description':
          raw['description']?.toString() ??
          raw['service_desc']?.toString() ??
          '',
      'icon_url':
          raw['icon_url']?.toString() ?? raw['cover_image_url']?.toString(),
      'status': _toInt(raw['status']) ?? 0,
      'category':
          raw['category']?.toString() ??
          (categoryId != null ? categoryMap[categoryId] : null),
      'created_at':
          raw['created_at']?.toString() ?? raw['create_time']?.toString(),
    };
  }

  Future<String> _resolveOrderNo(int orderId) async {
    final cached = _orderNoCache[orderId];
    if (cached != null && cached.isNotEmpty) return cached;

    final response = await _http.get(
      '/order/list',
      queryParameters: {'page_no': 1, 'page_size': 200},
    );
    final result = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data,
      (data) => data as Map<String, dynamic>,
    );
    if (!result.isSuccess || result.data == null) {
      throw Exception(result.message);
    }
    final records = (result.data!['records'] as List?) ?? const [];
    for (final item in records) {
      final raw = Map<String, dynamic>.from(item as Map);
      final id = _toInt(raw['id']);
      final orderNo = raw['order_no']?.toString();
      if (id != null && orderNo != null && orderNo.isNotEmpty) {
        _orderNoCache[id] = orderNo;
      }
    }
    final found = _orderNoCache[orderId];
    if (found == null || found.isEmpty) {
      throw Exception('未找到订单号');
    }
    return found;
  }

  Future<int> _ensureAddressId(CreateOrderRequest request) async {
    if (request.addressId != null) return request.addressId!;

    // 优先尝试按当前下单信息自动创建地址，避免页面未选中 addressId 导致下单失败。
    try {
      final createResp = await _http.post(
        '/user/address/add',
        data: {
          'contact_name': request.contactName,
          'contact_phone': request.contactPhone,
          'detail_address': request.address,
          'latitude': request.latitude,
          'longitude': request.longitude,
          'is_default': 1,
        },
      );
      final createResult = ApiResponse<Map<String, dynamic>>.fromJson(
        createResp.data,
        (data) => data as Map<String, dynamic>,
      );
      if (createResult.isSuccess && createResult.data != null) {
        final createdId = _toInt(createResult.data!['id']);
        if (createdId != null) return createdId;
      }
    } catch (_) {}

    // 创建失败时回退使用已有默认地址/第一条地址。
    final listResp = await _http.get('/user/address/list');
    final listResult = ApiResponse<List<dynamic>>.fromJson(
      listResp.data,
      (data) => data as List<dynamic>,
    );
    if (!listResult.isSuccess || listResult.data == null) {
      throw Exception('请选择服务地址');
    }
    final list = listResult.data!
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    if (list.isEmpty) {
      throw Exception('请先添加服务地址');
    }
    list.sort(
      (a, b) => (_toInt(b['is_default']) ?? 0) - (_toInt(a['is_default']) ?? 0),
    );
    final resolvedId = _toInt(list.first['id']);
    if (resolvedId == null) {
      throw Exception('请选择服务地址');
    }
    return resolvedId;
  }

  /// 获取服务列表
  ///
  /// [category] 分类筛选（可选）
  Future<List<ServiceModel>> getServiceList({String? category}) async {
    final categoryKey = (category == null || category == '全部')
        ? 'all'
        : category;
    try {
      final params = <String, dynamic>{};
      if (category != null && category != '全部') {
        final categoryId = await _resolveCategoryIdByName(category);
        if (categoryId != null) {
          params['category_id'] = categoryId;
        }
      }

      final response = await _http.get(
        '/service/item/list',
        queryParameters: params,
      );
      final result = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      final categoryMap = await _loadCategoryNameMap();
      final services = result.data!
          .map(
            (e) => _normalizeService(
              Map<String, dynamic>.from(e as Map),
              categoryMap,
            ),
          )
          .map(ServiceModel.fromJson)
          .toList();
      await StorageService.instance.cacheServicesByCategory(
        services.map((e) => e.toJson()).toList(),
        categoryKey: categoryKey,
      );
      if (categoryKey == 'all') {
        await StorageService.instance.cacheServices(
          services.map((e) => e.toJson()).toList(),
        );
      }
      return services;
    } catch (e) {
      final cached = StorageService.instance.getCachedServicesByCategory(
        categoryKey: categoryKey,
      );
      if (cached != null && cached.isNotEmpty) {
        return cached.map(ServiceModel.fromJson).toList();
      }
      throw Exception(normalizeErrorMessage(e, fallback: '加载服务列表失败'));
    }
  }

  /// 获取服务详情
  Future<ServiceModel> getServiceDetail(int serviceId) async {
    try {
      final response = await _http.get('/service/item/detail/$serviceId');

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      final categoryMap = await _loadCategoryNameMap();
      return ServiceModel.fromJson(
        _normalizeService(result.data!, categoryMap),
      );
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '加载服务详情失败'));
    }
  }

  /// 获取服务分类列表
  Future<List<String>> getCategories() async {
    try {
      final response = await _http.get('/service/category/list');

      final result = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => data as List<dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        return ['全部', '基础护理', '产后护理']; // 默认分类
      }

      final names = result.data!
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((e) => e['category_name']?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      return ['全部', ...names];
    } catch (e) {
      // 返回默认分类
      return ['全部', '基础护理', '产后护理'];
    }
  }

  /// 创建订单
  Future<CreateOrderResponse> createOrder(CreateOrderRequest request) async {
    try {
      final resolvedAddressId = await _ensureAddressId(request);
      final response = await _http.post(
        '/order/create',
        data: {
          'service_id': request.serviceId,
          'address_id': resolvedAddressId,
          // Backend expects ISO-8601 LocalDateTime (e.g. 2026-02-13T10:00:00).
          'appointment_time': request.appointmentTime.replaceFirst(' ', 'T'),
          if (request.remark != null && request.remark!.isNotEmpty)
            'remark': request.remark,
          'option_ids': <int>[],
        },
      );

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      final data = Map<String, dynamic>.from(result.data!);
      final normalized = <String, dynamic>{
        'order_id': _toInt(data['order_id'] ?? data['id']) ?? 0,
        'order_no': data['order_no']?.toString() ?? '',
        'total_amount': _toDouble(data['total_amount']) ?? 0,
        'pay_info': data['pay_info']?.toString(),
      };
      final created = CreateOrderResponse.fromJson(normalized);
      if (created.orderNo.isNotEmpty) {
        _orderNoCache[created.orderId] = created.orderNo;
      }
      return created;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '创建订单失败'));
    }
  }

  /// 获取支付信息
  ///
  /// 获取支付宝支付所需的orderString
  Future<String> getPayInfo(int orderId) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.post(
        '/payment/pay',
        data: {'order_no': orderNo, 'pay_method': 1},
      );

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      return 'SIMULATED_PAY_SUCCESS::$orderNo';
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '获取支付信息失败'));
    }
  }

  /// 查询支付结果
  Future<PaymentResult> queryPayResult(int orderId) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.get('/payment/query/$orderNo');

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        return PaymentResult(success: false, message: result.message);
      }

      final data = result.data!;
      final payStatus = _toInt(data['pay_status']) ?? 0;

      return PaymentResult(
        success: payStatus == 1,
        message: payStatus == 1 ? '支付成功' : '未支付',
        outTradeNo: data['trade_no']?.toString(),
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        message: normalizeErrorMessage(e, fallback: '查询支付结果失败'),
      );
    }
  }

  /// 取消订单
  Future<bool> cancelOrder(int orderId, {String? reason}) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.post(
        '/order/cancel/$orderNo',
        data: {'cancel_reason': reason ?? '用户取消'},
      );

      final result = ApiResponse.fromJson(response.data, null);
      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '取消订单失败'));
    }
  }
}
