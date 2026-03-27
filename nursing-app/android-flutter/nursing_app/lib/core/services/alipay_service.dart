import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tobias/tobias.dart';

/// 支付结果
enum PaymentStatus {
  /// 支付成功
  success,

  /// 支付取消
  cancelled,

  /// 支付失败
  failed,

  /// 支付处理中（等待确认）
  processing,
}

/// 支付结果信息
class PaymentResultInfo {
  final PaymentStatus status;
  final String? resultCode;
  final String? message;
  final String? orderId;
  final Map<String, dynamic>? rawResult;

  PaymentResultInfo({
    required this.status,
    this.resultCode,
    this.message,
    this.orderId,
    this.rawResult,
  });

  /// 是否支付成功
  bool get isSuccess => status == PaymentStatus.success;

  /// 是否支付取消
  bool get isCancelled => status == PaymentStatus.cancelled;

  /// 是否支付失败
  bool get isFailed => status == PaymentStatus.failed;

  /// 从支付宝结果解析
  factory PaymentResultInfo.fromAlipayResult(Map<dynamic, dynamic>? result) {
    if (result == null) {
      return PaymentResultInfo(
        status: PaymentStatus.failed,
        message: '支付返回结果为空',
      );
    }

    final resultStatus = result['resultStatus']?.toString();
    final memo = result['memo']?.toString();
    final detailResult = result['result']?.toString();

    String? subCode;
    String? subMsg;
    if (detailResult != null && detailResult.isNotEmpty) {
      try {
        final decoded = jsonDecode(detailResult);
        if (decoded is Map<String, dynamic>) {
          final response = decoded['alipay_trade_app_pay_response'];
          if (response is Map<String, dynamic>) {
            subCode = response['sub_code']?.toString();
            subMsg = response['sub_msg']?.toString();
          }
        }
      } catch (_) {
        // 忽略解析失败，回退到 memo。
      }
    }

    // 解析结果状态
    // 9000: 成功
    // 8000: 正在处理中
    // 4000: 失败
    // 6001: 用户取消
    // 6002: 网络连接出错

    PaymentStatus status;
    String message;

    switch (resultStatus) {
      case '9000':
        status = PaymentStatus.success;
        message = '支付成功';
        break;
      case '8000':
        status = PaymentStatus.processing;
        message = '支付处理中，请稍后查询订单状态';
        break;
      case '6001':
        status = PaymentStatus.cancelled;
        message = '支付已取消';
        break;
      case '6002':
        status = PaymentStatus.failed;
        message = '网络连接出错，请稍后重试';
        break;
      case '4000':
      default:
        status = PaymentStatus.failed;
        if (subCode == 'isv.invalid-app-id') {
          message = '支付宝配置错误：AppID 无效，请检查后端 alipay.app-id 与密钥是否同一应用';
        } else {
          message = subMsg ?? memo ?? '支付失败，请稍后重试';
        }
        break;
    }

    return PaymentResultInfo(
      status: status,
      resultCode: resultStatus,
      message: message,
      rawResult: Map<String, dynamic>.from(result),
    );
  }

  @override
  String toString() {
    return 'PaymentResultInfo(status: $status, code: $resultCode, message: $message)';
  }
}

/// 支付宝支付服务
///
/// 集成 tobias 插件实现支付宝支付
/// 支持沙箱环境和生产环境
class AlipayService {
  static AlipayService? _instance;
  static AlipayService get instance => _instance ??= AlipayService._();

  AlipayService._();

  /// tobias 实例
  final Tobias _tobias = Tobias();

  /// 是否沙箱模式
  bool _isSandbox = true;
  bool get isSandbox => _isSandbox;

  /// 设置沙箱模式
  void setSandboxMode(bool sandbox) {
    _isSandbox = sandbox;
    debugPrint('AlipayService: 沙箱模式 = $sandbox');
  }

  /// 调起支付宝支付
  ///
  /// [orderInfo] 从服务端获取的支付信息字符串
  ///
  /// 返回支付结果
  Future<PaymentResultInfo> pay(String orderInfo) async {
    try {
      final normalizedOrderInfo = orderInfo.trim();

      // 后端使用模拟支付时，直接返回成功，避免依赖真实支付宝签名串。
      if (normalizedOrderInfo.startsWith('SIMULATED_PAY_SUCCESS::') ||
          normalizedOrderInfo.startsWith('SIMULATED:')) {
        return PaymentResultInfo(
          status: PaymentStatus.success,
          resultCode: '9000',
          message: '支付成功',
          rawResult: {'resultStatus': '9000', 'memo': '模拟支付成功'},
        );
      }

      if (!normalizedOrderInfo.contains('app_id=') ||
          !normalizedOrderInfo.contains('sign=')) {
        return PaymentResultInfo(
          status: PaymentStatus.failed,
          resultCode: '4000',
          message: '支付参数不完整，请重新发起支付',
        );
      }

      final sanitizedOrderInfo = normalizedOrderInfo
          .replaceAll('\r', '')
          .replaceAll('\n', '');

      debugPrint('AlipayService: 开始支付');
      debugPrint('AlipayService: 沙箱模式 = $_isSandbox');

      // 调起支付宝
      final result = await _tobias.pay(
        sanitizedOrderInfo,
        evn: _isSandbox ? AliPayEvn.sandbox : AliPayEvn.online,
      );

      debugPrint('AlipayService: 支付结果 = $result');

      return PaymentResultInfo.fromAlipayResult(result);
    } catch (e) {
      debugPrint('AlipayService: 支付异常 - $e');
      return PaymentResultInfo(
        status: PaymentStatus.failed,
        message: '支付发生异常: $e',
      );
    }
  }

  /// 检查是否安装了支付宝
  Future<bool> isAlipayInstalled() async {
    try {
      final installed = await _tobias.isAliPayInstalled;
      debugPrint('AlipayService: 支付宝已安装 = $installed');
      return installed;
    } catch (e) {
      debugPrint('AlipayService: 检查支付宝安装状态异常 - $e');
      return false;
    }
  }

  /// 支付宝授权登录
  ///
  /// [authInfo] 从服务端获取的授权信息字符串
  Future<Map<dynamic, dynamic>?> auth(String authInfo) async {
    try {
      debugPrint('AlipayService: 开始授权');
      final result = await _tobias.auth(authInfo);
      debugPrint('AlipayService: 授权结果 = $result');
      return result;
    } catch (e) {
      debugPrint('AlipayService: 授权异常 - $e');
      return null;
    }
  }
}

/// 支付宝服务 Provider
final alipayServiceProvider = Provider<AlipayService>((ref) {
  return AlipayService.instance;
});

/// 支付宝安装状态 Provider
final alipayInstalledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(alipayServiceProvider);
  return await service.isAlipayInstalled();
});

/// 支付状态 Notifier
class PaymentNotifier extends StateNotifier<AsyncValue<PaymentResultInfo?>> {
  final AlipayService _alipayService;

  PaymentNotifier(this._alipayService) : super(const AsyncValue.data(null));

  /// 发起支付
  Future<PaymentResultInfo> pay(String orderInfo) async {
    state = const AsyncValue.loading();
    try {
      final result = await _alipayService.pay(orderInfo);
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// 重置状态
  void reset() {
    state = const AsyncValue.data(null);
  }
}

/// 支付状态 Provider
final paymentNotifierProvider =
    StateNotifierProvider<PaymentNotifier, AsyncValue<PaymentResultInfo?>>((
      ref,
    ) {
      final alipayService = ref.watch(alipayServiceProvider);
      return PaymentNotifier(alipayService);
    });
