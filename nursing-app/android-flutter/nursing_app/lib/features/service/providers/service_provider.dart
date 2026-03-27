import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/error_mapper.dart';
import '../data/models/service_model.dart';
import '../data/repositories/service_repository.dart';

/// 服务仓库 Provider
final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return ServiceRepository();
});

/// 服务列表 Provider
///
/// 根据分类获取服务列表
final serviceListProvider = FutureProvider.family<List<ServiceModel>, String?>((
  ref,
  category,
) async {
  final repository = ref.read(serviceRepositoryProvider);
  return repository.getServiceList(category: category);
});

/// 服务分类 Provider
final serviceCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.read(serviceRepositoryProvider);
  return repository.getCategories();
});

/// 服务详情 Provider
final serviceDetailProvider = FutureProvider.family<ServiceModel, int>((
  ref,
  serviceId,
) async {
  final repository = ref.read(serviceRepositoryProvider);
  return repository.getServiceDetail(serviceId);
});

/// 当前选中分类 Provider
final selectedCategoryProvider = StateProvider<String>((ref) => '全部');

/// 订单创建状态
enum OrderCreateStatus { initial, loading, success, error }

/// 订单创建状态类
class OrderCreateState {
  final OrderCreateStatus status;
  final CreateOrderResponse? response;
  final String? errorMessage;

  const OrderCreateState({
    this.status = OrderCreateStatus.initial,
    this.response,
    this.errorMessage,
  });

  OrderCreateState copyWith({
    OrderCreateStatus? status,
    CreateOrderResponse? response,
    String? errorMessage,
  }) {
    return OrderCreateState(
      status: status ?? this.status,
      response: response ?? this.response,
      errorMessage: errorMessage,
    );
  }
}

/// 订单创建 Notifier
class OrderCreateNotifier extends StateNotifier<OrderCreateState> {
  final ServiceRepository _repository;

  OrderCreateNotifier(this._repository) : super(const OrderCreateState());

  /// 创建订单
  Future<CreateOrderResponse?> createOrder(CreateOrderRequest request) async {
    state = state.copyWith(status: OrderCreateStatus.loading);

    try {
      final response = await _repository.createOrder(request);
      state = state.copyWith(
        status: OrderCreateStatus.success,
        response: response,
      );
      return response;
    } catch (e) {
      state = state.copyWith(
        status: OrderCreateStatus.error,
        errorMessage: normalizeErrorMessage(e, fallback: '创建订单失败'),
      );
      return null;
    }
  }

  /// 重置状态
  void reset() {
    state = const OrderCreateState();
  }
}

/// 订单创建 Provider
final orderCreateProvider =
    StateNotifierProvider<OrderCreateNotifier, OrderCreateState>((ref) {
      final repository = ref.read(serviceRepositoryProvider);
      return OrderCreateNotifier(repository);
    });

/// 支付状态
enum PaymentStatus { initial, loading, success, failed, cancelled }

/// 支付状态类
class PaymentState {
  final PaymentStatus status;
  final String? message;
  final String? outTradeNo;

  const PaymentState({
    this.status = PaymentStatus.initial,
    this.message,
    this.outTradeNo,
  });

  PaymentState copyWith({
    PaymentStatus? status,
    String? message,
    String? outTradeNo,
  }) {
    return PaymentState(
      status: status ?? this.status,
      message: message,
      outTradeNo: outTradeNo ?? this.outTradeNo,
    );
  }
}

/// 支付 Notifier
class PaymentNotifier extends StateNotifier<PaymentState> {
  final ServiceRepository _repository;

  PaymentNotifier(this._repository) : super(const PaymentState());

  /// 设置支付状态
  void setStatus(PaymentStatus status, {String? message, String? outTradeNo}) {
    state = state.copyWith(
      status: status,
      message: message,
      outTradeNo: outTradeNo,
    );
  }

  /// 查询支付结果
  Future<bool> queryPayResult(int orderId) async {
    try {
      final result = await _repository.queryPayResult(orderId);
      if (result.success) {
        state = state.copyWith(
          status: PaymentStatus.success,
          outTradeNo: result.outTradeNo,
        );
        return true;
      } else {
        state = state.copyWith(
          status: PaymentStatus.failed,
          message: result.message,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: PaymentStatus.failed,
        message: normalizeErrorMessage(e, fallback: '查询支付结果失败'),
      );
      return false;
    }
  }

  /// 重置状态
  void reset() {
    state = const PaymentState();
  }
}

/// 支付 Provider
final paymentProvider = StateNotifierProvider<PaymentNotifier, PaymentState>((
  ref,
) {
  final repository = ref.read(serviceRepositoryProvider);
  return PaymentNotifier(repository);
});
