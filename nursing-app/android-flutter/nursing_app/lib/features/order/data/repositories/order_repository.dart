import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/http_client.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/error_mapper.dart';
import '../models/order_model.dart';

/// 订单仓库
///
/// 提供订单相关的 API 调用
/// 包括：订单列表、订单详情、取消订单、申请退款、支付、评价
class OrderRepository {
  final HttpClient _http;
  final Map<int, String> _orderNoCache = {};

  OrderRepository(this._http);

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

  int _mapBackendStatusToAppStatus(int backendStatus) {
    switch (backendStatus) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 1;
      case 3:
        return 2;
      case 4:
        return 3;
      case 5:
        return 4;
      case 6:
        return 5;
      case 7:
        return 6;
      case 8:
      case 9:
      case 10:
        return 7;
      default:
        return 0;
    }
  }

  List<int> _mapAppStatusToBackendStatuses(int appStatus) {
    switch (appStatus) {
      case 0:
        return [0];
      case 1:
        return [1, 2];
      case 2:
        return [3];
      case 3:
        return [4];
      case 4:
        return [5];
      case 5:
        return [6];
      case 6:
        return [7];
      case 7:
        return [8, 9, 10];
      default:
        return [];
    }
  }

  Map<String, String> _extractContact(String snapshot) {
    final text = snapshot.trim();
    if (text.isEmpty) {
      return {'address': '', 'contact_name': '', 'contact_phone': ''};
    }
    final parts = text.split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      return {
        'address': parts.sublist(0, parts.length - 2).join(' '),
        'contact_name': parts[parts.length - 2],
        'contact_phone': parts.last,
      };
    }
    return {'address': text, 'contact_name': '', 'contact_phone': ''};
  }

  Map<String, dynamic> _normalizeOrder(Map<String, dynamic> raw) {
    final backendStatus =
        _toInt(raw['order_status'] ?? raw['orderStatus'] ?? raw['status']) ?? 0;
    final appStatus = _mapBackendStatusToAppStatus(backendStatus);
    final totalAmount =
        _toDouble(raw['total_amount'] ?? raw['totalAmount']) ?? 0;
    final id = _toInt(raw['id']) ?? 0;
    final orderNo = (raw['order_no'] ?? raw['orderNo'])?.toString() ?? '';
    final snapshot = raw['address_snapshot']?.toString() ?? '';
    final contact = _extractContact(snapshot);
    if (orderNo.isNotEmpty) {
      _orderNoCache[id] = orderNo;
    }

    final refundStatus = switch (backendStatus) {
      9 => 1,
      10 => 2,
      _ => 0,
    };

    return {
      'id': id,
      'order_no': orderNo,
      'user_id': _toInt(raw['user_id']) ?? 0,
      'nurse_id': _toInt(raw['nurse_user_id']),
      'service_id': _toInt(raw['service_id']) ?? 0,
      'service_name':
          raw['service_name']?.toString() ??
          raw['serviceName']?.toString() ??
          raw['service_name_snapshot']?.toString() ??
          raw['serviceNameSnapshot']?.toString() ??
          '护理服务',
      'service_price':
          _toDouble(raw['service_price']) ??
          _toDouble(raw['servicePrice']) ??
          _toDouble(raw['service_price_snapshot']) ??
          _toDouble(raw['servicePriceSnapshot']) ??
          0,
      'total_amount': totalAmount,
      'platform_fee': totalAmount * 0.2,
      'nurse_income': totalAmount * 0.8,
      'contact_name':
          raw['contact_name']?.toString() ?? contact['contact_name'],
      'contact_phone':
          raw['contact_phone']?.toString() ?? contact['contact_phone'],
      'address': raw['address']?.toString() ?? contact['address'] ?? snapshot,
      'appointment_time':
          raw['appointment_time']?.toString() ??
          raw['service_time']?.toString() ??
          '',
      'remark': raw['remark']?.toString(),
      'latitude': _toDouble(raw['latitude'] ?? raw['address_latitude']),
      'longitude': _toDouble(raw['longitude'] ?? raw['address_longitude']),
      'status': appStatus,
      'pay_status': _toInt(raw['pay_status']) ?? 0,
      'pay_time':
          raw['pay_time']?.toString() ??
          raw['payTime']?.toString() ??
          raw['paid_time']?.toString(),
      'out_trade_no': (raw['trade_no'] ?? raw['tradeNo'])?.toString(),
      'arrival_time':
          raw['arrival_time']?.toString() ??
          raw['arrive_time']?.toString() ??
          raw['arrivalTime']?.toString(),
      'arrival_photo':
          raw['arrival_photo']?.toString() ?? raw['arrivalPhoto']?.toString(),
      'start_time':
          raw['start_time']?.toString() ??
          raw['service_start_time']?.toString() ??
          raw['serviceBeginTime']?.toString() ??
          raw['startTime']?.toString(),
      'start_photo':
          raw['start_photo']?.toString() ?? raw['startPhoto']?.toString(),
      'finish_time':
          raw['finish_time']?.toString() ??
          raw['service_finish_time']?.toString() ??
          raw['serviceEndTime']?.toString() ??
          raw['finishTime']?.toString(),
      'finish_photo':
          raw['finish_photo']?.toString() ?? raw['finishPhoto']?.toString(),
      'cancel_time': raw['cancel_time']?.toString(),
      'cancel_reason': raw['cancel_reason']?.toString(),
      'refund_amount': _toDouble(raw['refund_amount']),
      'refund_status': _toInt(raw['refund_status']) ?? refundStatus,
      'nurse_name': raw['nurse_name']?.toString(),
      'nurse_phone': raw['nurse_phone']?.toString(),
      'nurse_rating': _toDouble(raw['nurse_rating']),
      'rating': _toInt(raw['rating']),
      'evaluation_content':
          raw['evaluation_content']?.toString() ?? raw['content']?.toString(),
      'evaluation_time': raw['evaluation_time']?.toString(),
      'created_at':
          raw['created_at']?.toString() ?? raw['create_time']?.toString(),
      'updated_at':
          raw['updated_at']?.toString() ?? raw['update_time']?.toString(),
    };
  }

  Future<String> _resolveOrderNo(int orderId) async {
    final cached = _orderNoCache[orderId];
    if (cached != null && cached.isNotEmpty) return cached;
    await getOrderList(page: 1, pageSize: 200);
    final resolved = _orderNoCache[orderId];
    if (resolved == null || resolved.isEmpty) {
      throw Exception('未找到订单号');
    }
    return resolved;
  }

  /// 获取订单列表
  ///
  /// [status] 订单状态筛选，null 表示全部
  /// [page] 页码
  /// [pageSize] 每页数量
  Future<List<OrderModel>> getOrderList({
    int? status,
    int page = 1,
    int pageSize = 10,
  }) async {
    final statusKey = status?.toString() ?? 'all';
    try {
      final backendStatuses = status == null
          ? <int?>[null]
          : _mapAppStatusToBackendStatuses(status).cast<int?>();

      final responses = await Future.wait(
        backendStatuses.map((backendStatus) {
          final queryParameters = <String, dynamic>{
            'pageNo': page,
            'pageSize': pageSize,
            'status': backendStatus,
          }..removeWhere((_, value) => value == null);
          return _http.get('/order/list', queryParameters: queryParameters);
        }),
      );

      final all = <OrderModel>[];
      final seen = <int>{};
      for (final response in responses) {
        final result = ApiResponse<Map<String, dynamic>>.fromJson(
          response.data,
          (data) => data as Map<String, dynamic>,
        );
        if (!result.isSuccess || result.data == null) continue;
        final records = (result.data!['records'] as List?) ?? const [];
        for (final item in records) {
          final normalized = _normalizeOrder(
            Map<String, dynamic>.from(item as Map),
          );
          final model = OrderModel.fromJson(normalized);
          if (seen.add(model.id)) {
            all.add(model);
          }
        }
      }
      all.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      if (page == 1) {
        await StorageService.instance.cacheOrders(
          all.map((e) => e.toJson()).toList(),
          statusKey: statusKey,
        );
      }
      return all;
    } catch (e) {
      if (page == 1) {
        final cached = StorageService.instance.getCachedOrders(
          statusKey: statusKey,
        );
        if (cached != null && cached.isNotEmpty) {
          return cached.map(OrderModel.fromJson).toList();
        }
      }
      throw Exception(normalizeErrorMessage(e, fallback: '加载订单列表失败'));
    }
  }

  /// 获取订单详情
  Future<OrderModel> getOrderDetail(int orderId) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.get('/order/detail/$orderNo');

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      return OrderModel.fromJson(_normalizeOrder(result.data!));
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '加载订单详情失败'));
    }
  }

  /// 获取支付信息
  ///
  /// 返回支付宝支付所需的 orderString
  Future<PaymentInfoResponse> getPaymentInfo(int orderId) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.post(
        '/payment/pay',
        data: {'orderNo': orderNo, 'payMethod': 1},
      );

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      final data = Map<String, dynamic>.from(result.data!);
      final payInfo = (data['pay_info'] ?? data['payInfo'] ?? '').toString();
      if (payInfo.isEmpty) {
        throw Exception('服务端未返回可用的支付信息');
      }
      if (payInfo.startsWith('MOCK_PAY_FORM_')) {
        throw Exception('服务端未配置支付宝沙箱密钥，无法拉起沙箱支付');
      }

      return PaymentInfoResponse.fromJson({
        'order_id': orderId,
        'order_no': orderNo,
        'total_amount': _toDouble(data['pay_amount'] ?? data['payAmount']) ?? 0,
        'pay_info': payInfo,
        'expire_time': (data['expire_time'] ?? data['expireTime'])?.toString(),
      });
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '获取支付信息失败'));
    }
  }

  /// 确认支付结果
  ///
  /// 前端支付完成后通知后端确认
  Future<bool> confirmPayment(int orderId, String tradeNo) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.post(
        '/payment/confirm',
        data: {'orderNo': orderNo, if (tradeNo.isNotEmpty) 'tradeNo': tradeNo},
      );
      final result = ApiResponse.fromJson(response.data, null);
      if (!result.isSuccess) {
        throw Exception(result.message);
      }
      return true;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '确认支付结果失败'));
    }
  }

  /// 查询支付结果
  Future<Map<String, dynamic>> queryPaymentResult(int orderId) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.get('/payment/query/$orderNo');

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      final data = result.data!;
      return {
        'order_no':
            (data['order_no'] ?? data['orderNo'])?.toString() ?? orderNo,
        'trade_no': (data['trade_no'] ?? data['tradeNo'])?.toString(),
        'pay_status': _toInt(data['pay_status'] ?? data['payStatus']) ?? 0,
        'pay_time': (data['pay_time'] ?? data['payTime'])?.toString(),
      };
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '查询支付结果失败'));
    }
  }

  /// 取消订单
  ///
  /// 支持取消未支付订单或支付后30分钟内的订单
  Future<CancelOrderResponse> cancelOrder(CancelOrderRequest request) async {
    try {
      final orderNo = await _resolveOrderNo(request.orderId);
      final response = await _http.post(
        '/order/cancel/$orderNo',
        data: {'cancel_reason': request.reason},
      );

      final result = ApiResponse.fromJson(response.data, null);

      if (!result.isSuccess) {
        return CancelOrderResponse(success: false, message: result.message);
      }

      return CancelOrderResponse(
        success: true,
        message: result.message.isNotEmpty ? result.message : '取消成功',
      );
    } catch (e) {
      return CancelOrderResponse(
        success: false,
        message: normalizeErrorMessage(e, fallback: '取消订单失败'),
      );
    }
  }

  /// 申请退款
  ///
  /// 针对已支付订单申请退款（30分钟内）
  Future<RefundResponse> requestRefund(RefundRequest request) async {
    try {
      final cancel = await cancelOrder(
        CancelOrderRequest(orderId: request.orderId, reason: request.reason),
      );
      return RefundResponse(
        success: cancel.success,
        message: cancel.message,
        refundAmount: cancel.refundAmount,
        refundStatus: cancel.refundStatus,
      );
    } catch (e) {
      return RefundResponse(
        success: false,
        message: normalizeErrorMessage(e, fallback: '申请退款失败'),
      );
    }
  }

  /// 查询退款状态
  Future<RefundResponse> queryRefundStatus(int orderId) async {
    try {
      final order = await getOrderDetail(orderId);
      return RefundResponse(
        success: true,
        message: 'ok',
        refundAmount: order.refundAmount,
        refundStatus: order.refundStatus,
      );
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '查询退款状态失败'));
    }
  }

  /// 提交评价
  Future<bool> submitEvaluation(EvaluationRequest request) async {
    try {
      final orderNo = await _resolveOrderNo(request.orderId);
      final response = await _http.post(
        '/evaluation/submit',
        data: {
          'orderNo': orderNo,
          'rating': request.rating,
          'content': request.comment ?? '',
        },
      );

      final result = ApiResponse.fromJson(response.data, null);

      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '提交评价失败'));
    }
  }

  /// 获取订单评价详情
  Future<Map<String, dynamic>?> getOrderEvaluation(int orderId) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.get('/evaluation/order/$orderNo');
      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
      if (!result.isSuccess || result.data == null) return null;
      return result.data;
    } catch (_) {
      return null;
    }
  }

  /// 提交追评（7天窗口）
  Future<bool> submitFollowupEvaluation(int orderId, String content) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.post(
        '/evaluation/followup',
        data: {'orderNo': orderNo, 'content': content},
      );
      final result = ApiResponse.fromJson(response.data, null);
      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '追评提交失败'));
    }
  }

  /// 我的评价历史
  Future<List<Map<String, dynamic>>> getMyEvaluationHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _http.get(
        '/evaluation/my/list',
        queryParameters: {'pageNo': page, 'pageSize': pageSize},
      );
      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
      if (!result.isSuccess || result.data == null) return const [];
      final records = (result.data!['records'] as List?) ?? const [];
      return records.map((item) {
        final row = Map<String, dynamic>.from(item as Map);

        final orderId = _toInt(row['orderId'] ?? row['order_id']);
        final orderNo =
            (row['orderNo'] ?? row['order_no'] ?? row['order_number'])
                ?.toString()
                .trim();

        if (orderId != null && orderId > 0) {
          row['orderId'] = orderId;
          row['order_id'] = orderId;
          final cached = _orderNoCache[orderId];
          if ((orderNo == null || orderNo.isEmpty) &&
              cached != null &&
              cached.isNotEmpty) {
            row['orderNo'] = cached;
            row['order_no'] = cached;
          }
        }

        if (orderNo != null && orderNo.isNotEmpty) {
          row['orderNo'] = orderNo;
          row['order_no'] = orderNo;
        }

        return row;
      }).toList();
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '加载评价历史失败'));
    }
  }

  /// 获取订单状态时间轴
  Future<List<Map<String, dynamic>>> getOrderTimeline(int orderId) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.get('/order/timeline/$orderNo');
      final result = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => (data as List?) ?? const [],
      );
      if (!result.isSuccess || result.data == null) {
        return const [];
      }
      return result.data!
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 获取订单打卡照片
  Future<List<Map<String, dynamic>>> getOrderCheckinPhotos(int orderId) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.get('/order/checkinPhotos/$orderNo');
      final result = ApiResponse<List<dynamic>>.fromJson(
        response.data,
        (data) => (data as List?) ?? const [],
      );
      if (!result.isSuccess || result.data == null) {
        return const [];
      }
      return result.data!
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 获取订单全链路数据（状态流/支付退款/SOS）
  Future<Map<String, dynamic>> getOrderFlow(int orderId) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.get('/order/flow/$orderNo');
      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }
      return Map<String, dynamic>.from(result.data!);
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '加载订单全链路数据失败'));
    }
  }

  /// 服务中紧急呼叫（SOS）
  Future<bool> triggerSos(
    int orderId, {
    String? description,
    int emergencyType = 1,
  }) async {
    try {
      final response = await _http.post(
        '/sos/trigger',
        data: {
          'orderId': orderId,
          'emergencyType': emergencyType,
          'description': description ?? '',
        },
      );
      final result = ApiResponse.fromJson(response.data, null);
      if (!result.isSuccess) {
        throw Exception(result.message);
      }
      return true;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: 'SOS发送失败'));
    }
  }
}

/// 订单仓库 Provider
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final http = ref.watch(httpClientProvider);
  return OrderRepository(http);
});
