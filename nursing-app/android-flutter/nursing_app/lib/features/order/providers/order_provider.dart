import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/alipay_service.dart';
import '../../../core/utils/error_mapper.dart';
import '../data/models/order_model.dart';
import '../data/repositories/order_repository.dart';

/// 订单列表状态
class OrderListState {
  final List<OrderModel> orders;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;
  final int? statusFilter;

  const OrderListState({
    this.orders = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
    this.statusFilter,
  });

  OrderListState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
    int? statusFilter,
  }) {
    return OrderListState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

/// 订单列表状态管理
class OrderListNotifier extends StateNotifier<OrderListState> {
  final OrderRepository _repository;

  OrderListNotifier(this._repository) : super(const OrderListState());

  /// 加载订单列表
  Future<void> loadOrders({int? status, bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 1 : state.currentPage;

    state = state.copyWith(isLoading: true, error: null, statusFilter: status);

    try {
      final orders = await _repository.getOrderList(status: status, page: page);

      state = state.copyWith(
        orders: refresh ? orders : [...state.orders, ...orders],
        isLoading: false,
        hasMore: orders.length >= 10,
        currentPage: page + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: normalizeErrorMessage(e, fallback: '加载订单失败'),
      );
    }
  }

  /// 刷新订单列表
  Future<void> refresh() async {
    await loadOrders(status: state.statusFilter, refresh: true);
  }

  /// 加载更多
  Future<void> loadMore() async {
    if (state.hasMore && !state.isLoading) {
      await loadOrders(status: state.statusFilter);
    }
  }

  /// 更新单个订单状态
  void updateOrder(OrderModel order) {
    final index = state.orders.indexWhere((o) => o.id == order.id);
    if (index != -1) {
      final newOrders = List<OrderModel>.from(state.orders);
      newOrders[index] = order;
      state = state.copyWith(orders: newOrders);
    }
  }

  /// 移除订单
  void removeOrder(int orderId) {
    final newOrders = state.orders.where((o) => o.id != orderId).toList();
    state = state.copyWith(orders: newOrders);
  }
}

/// 订单详情状态
class OrderDetailState {
  final OrderModel? order;
  final bool isLoading;
  final String? error;

  const OrderDetailState({this.order, this.isLoading = false, this.error});

  OrderDetailState copyWith({
    OrderModel? order,
    bool? isLoading,
    String? error,
  }) {
    return OrderDetailState(
      order: order ?? this.order,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 订单详情状态管理
class OrderDetailNotifier extends StateNotifier<OrderDetailState> {
  final OrderRepository _repository;

  OrderDetailNotifier(this._repository) : super(const OrderDetailState());

  /// 加载订单详情
  Future<void> loadOrder(int orderId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final order = await _repository.getOrderDetail(orderId);
      state = state.copyWith(order: order, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: normalizeErrorMessage(e, fallback: '加载订单详情失败'),
      );
    }
  }

  /// 更新订单
  void updateOrder(OrderModel order) {
    state = state.copyWith(order: order);
  }
}

/// 支付状态
enum OrderPaymentStatus { initial, processing, success, failed, cancelled }

/// 支付页面状态
class PaymentState {
  final OrderModel? order;
  final OrderPaymentStatus status;
  final String? message;
  final bool isLoading;
  final int remainingCancelSeconds;
  final String? paymentOrderString;

  const PaymentState({
    this.order,
    this.status = OrderPaymentStatus.initial,
    this.message,
    this.isLoading = false,
    this.remainingCancelSeconds = 30 * 60,
    this.paymentOrderString,
  });

  PaymentState copyWith({
    OrderModel? order,
    OrderPaymentStatus? status,
    String? message,
    bool? isLoading,
    int? remainingCancelSeconds,
    String? paymentOrderString,
  }) {
    return PaymentState(
      order: order ?? this.order,
      status: status ?? this.status,
      message: message,
      isLoading: isLoading ?? this.isLoading,
      remainingCancelSeconds:
          remainingCancelSeconds ?? this.remainingCancelSeconds,
      paymentOrderString: paymentOrderString ?? this.paymentOrderString,
    );
  }
}

/// 支付状态管理
class PaymentNotifier extends StateNotifier<PaymentState> {
  final OrderRepository _repository;
  final AlipayService _alipayService;
  Timer? _cancelTimer;
  bool _payInFlight = false;

  PaymentNotifier(this._repository, this._alipayService)
    : super(const PaymentState());

  @override
  void dispose() {
    _cancelTimer?.cancel();
    super.dispose();
  }

  /// 初始化支付页面
  Future<void> initPayment(int orderId) async {
    state = state.copyWith(isLoading: true);

    try {
      // 获取订单详情
      final order = await _repository.getOrderDetail(orderId);
      state = state.copyWith(
        order: order,
        isLoading: false,
        remainingCancelSeconds: order.remainingCancelSeconds,
      );

      // 如果已支付，启动取消倒计时
      if (order.payStatus == 1 && order.canCancel) {
        _startCancelCountdown(order);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        status: OrderPaymentStatus.failed,
        message: normalizeErrorMessage(e, fallback: '加载支付信息失败'),
      );
    }
  }

  /// 启动取消倒计时
  void _startCancelCountdown(OrderModel order) {
    _cancelTimer?.cancel();
    state = state.copyWith(
      remainingCancelSeconds: order.remainingCancelSeconds,
    );

    _cancelTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final latestOrder = state.order ?? order;
      final remaining = latestOrder.remainingCancelSeconds;
      if (remaining <= 0) {
        timer.cancel();
        state = state.copyWith(remainingCancelSeconds: 0);
      } else {
        state = state.copyWith(remainingCancelSeconds: remaining);
      }
    });
  }

  bool _shouldRetryMerchantOrderError(PaymentResultInfo result) {
    if (result.resultCode != '4000') return false;
    final message = (result.message ?? '').toLowerCase();
    if (message.contains('appid 无效') ||
        message.contains('appid') && message.contains('无效') ||
        message.contains('invalid-app-id')) {
      return false;
    }
    return message.contains('商家订单参数异常') ||
        message.contains('订单参数异常') ||
        message.contains('merchant order parameter');
  }

  String _extractTradeNo(PaymentResultInfo result) {
    final raw = result.rawResult;
    if (raw == null) return '';

    final directTradeNo = (raw['trade_no'] ?? raw['tradeNo'])?.toString();
    if (directTradeNo != null && directTradeNo.isNotEmpty) {
      return directTradeNo;
    }

    final detailResult = raw['result']?.toString() ?? '';
    if (detailResult.isEmpty) return '';

    try {
      final decoded = jsonDecode(detailResult);
      if (decoded is Map<String, dynamic>) {
        final response = decoded['alipay_trade_app_pay_response'];
        if (response is Map<String, dynamic>) {
          final tradeNo = response['trade_no']?.toString() ?? '';
          if (tradeNo.isNotEmpty) {
            return tradeNo;
          }
        }
      }
    } catch (_) {
      // Ignore and fallback to regex parse.
    }

    final tradeNoMatch = RegExp(
      r'(^|[&;])trade_no=([^&]+)',
    ).firstMatch(detailResult);
    if (tradeNoMatch != null && tradeNoMatch.groupCount >= 2) {
      return Uri.decodeComponent(tradeNoMatch.group(2) ?? '');
    }
    return '';
  }

  Future<bool> _waitUntilPaymentSettled(
    int orderId, {
    int maxAttempts = 6,
  }) async {
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        final paymentResult = await _repository.queryPaymentResult(orderId);
        final dynamic rawPayStatus = paymentResult['pay_status'];
        final int payStatus = rawPayStatus is int
            ? rawPayStatus
            : int.tryParse(rawPayStatus?.toString() ?? '') ?? 0;
        if (payStatus == 1) {
          final tradeNo = (paymentResult['trade_no'] ?? '').toString();
          await _repository.confirmPayment(orderId, tradeNo);
          return true;
        }
      } catch (_) {
        // Continue polling until timeout.
      }
    }
    return false;
  }

  /// 执行支付
  Future<bool> pay() async {
    if (state.order == null) return false;
    if (_payInFlight ||
        state.isLoading ||
        state.status == OrderPaymentStatus.processing) {
      return false;
    }

    _payInFlight = true;

    state = state.copyWith(
      status: OrderPaymentStatus.processing,
      isLoading: true,
    );

    try {
      // 1. 获取支付信息
      final paymentInfo = await _repository.getPaymentInfo(state.order!.id);

      // 2. 调用支付宝支付
      var result = await _alipayService.pay(paymentInfo.payInfo);

      // 避免重复拉起支付宝：参数异常时仅提示刷新后重试，不在一次点击中二次调起。
      if (_shouldRetryMerchantOrderError(result)) {
        state = state.copyWith(
          status: OrderPaymentStatus.failed,
          message: '支付参数已过期，请返回后重新点击支付',
          isLoading: false,
        );
        return false;
      }

      if (result.isSuccess) {
        // 支付成功
        // 3. 确认支付结果
        final tradeNo = _extractTradeNo(result);
        bool confirmed = false;
        try {
          confirmed = await _repository.confirmPayment(
            state.order!.id,
            tradeNo,
          );
        } catch (_) {
          confirmed = await _waitUntilPaymentSettled(state.order!.id);
        }

        if (!confirmed) {
          state = state.copyWith(
            status: OrderPaymentStatus.processing,
            message: '支付结果确认中，请稍后在订单页刷新状态',
            isLoading: false,
          );
          return false;
        }

        // 4. 刷新订单详情
        final updatedOrder = await _repository.getOrderDetail(state.order!.id);
        state = state.copyWith(
          order: updatedOrder,
          status: OrderPaymentStatus.success,
          message: '支付成功',
          isLoading: false,
          remainingCancelSeconds: updatedOrder.remainingCancelSeconds,
        );

        // 启动取消倒计时
        _startCancelCountdown(updatedOrder);

        return true;
      } else if (result.status == PaymentStatus.processing) {
        state = state.copyWith(message: '支付处理中，正在确认支付结果...');

        final settled = await _waitUntilPaymentSettled(state.order!.id);
        if (settled) {
          final updatedOrder = await _repository.getOrderDetail(
            state.order!.id,
          );
          state = state.copyWith(
            order: updatedOrder,
            status: OrderPaymentStatus.success,
            message: '支付成功',
            isLoading: false,
            remainingCancelSeconds: updatedOrder.remainingCancelSeconds,
          );
          _startCancelCountdown(updatedOrder);
          return true;
        }

        state = state.copyWith(
          status: OrderPaymentStatus.processing,
          message: '支付处理中，请稍后在订单页刷新状态',
          isLoading: false,
        );
        return false;
      } else if (result.isCancelled) {
        // 用户取消
        state = state.copyWith(
          status: OrderPaymentStatus.cancelled,
          message: '已取消支付',
          isLoading: false,
        );
        return false;
      } else {
        // 支付失败
        final isMerchantOrderError = _shouldRetryMerchantOrderError(result);
        state = state.copyWith(
          status: OrderPaymentStatus.failed,
          message: (result.message ?? '').contains('AppID 无效')
              ? '支付宝沙箱配置错误：请在后端设置正确的 ALIPAY_APP_ID，并确保与私钥、公钥属于同一应用'
              : isMerchantOrderError
              ? '支付宝返回订单参数异常，请检查沙箱账号与密钥配置后重试'
              : (result.message ?? '支付失败'),
          isLoading: false,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: OrderPaymentStatus.failed,
        message: normalizeErrorMessage(e, fallback: '支付失败，请稍后重试'),
        isLoading: false,
      );
      return false;
    } finally {
      _payInFlight = false;
    }
  }

  /// 取消订单
  Future<CancelOrderResponse> cancelOrder(String reason) async {
    if (state.order == null) {
      return CancelOrderResponse(success: false, message: '订单不存在');
    }

    if (!state.order!.canCancel) {
      return CancelOrderResponse(success: false, message: '订单已超过可取消时间');
    }

    state = state.copyWith(isLoading: true);

    try {
      final request = CancelOrderRequest(
        orderId: state.order!.id,
        reason: reason,
      );

      final response = await _repository.cancelOrder(request);

      if (response.success) {
        // 刷新订单详情
        final updatedOrder = await _repository.getOrderDetail(state.order!.id);
        state = state.copyWith(order: updatedOrder, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }

      return response;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return CancelOrderResponse(
        success: false,
        message: normalizeErrorMessage(e, fallback: '取消订单失败'),
      );
    }
  }

  /// 申请退款
  Future<RefundResponse> requestRefund(String reason) async {
    if (state.order == null) {
      return RefundResponse(success: false, message: '订单不存在');
    }

    if (!state.order!.canRefund) {
      return RefundResponse(success: false, message: '订单不符合退款条件');
    }

    state = state.copyWith(isLoading: true);

    try {
      final request = RefundRequest(orderId: state.order!.id, reason: reason);

      final response = await _repository.requestRefund(request);

      if (response.success) {
        // 刷新订单详情
        final updatedOrder = await _repository.getOrderDetail(state.order!.id);
        state = state.copyWith(order: updatedOrder, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }

      return response;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return RefundResponse(
        success: false,
        message: normalizeErrorMessage(e, fallback: '退款申请失败'),
      );
    }
  }
}

/// 订单取消/退款操作状态
class OrderOperationState {
  final bool isLoading;
  final String? error;
  final bool success;
  final String? message;

  const OrderOperationState({
    this.isLoading = false,
    this.error,
    this.success = false,
    this.message,
  });

  OrderOperationState copyWith({
    bool? isLoading,
    String? error,
    bool? success,
    String? message,
  }) {
    return OrderOperationState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success ?? this.success,
      message: message,
    );
  }
}

/// 订单操作状态管理（用于订单详情页的操作）
class OrderOperationNotifier extends StateNotifier<OrderOperationState> {
  final OrderRepository _repository;

  OrderOperationNotifier(this._repository) : super(const OrderOperationState());

  /// 重置状态
  void reset() {
    state = const OrderOperationState();
  }

  /// 取消订单
  Future<bool> cancelOrder(int orderId, String reason) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final request = CancelOrderRequest(orderId: orderId, reason: reason);

      final response = await _repository.cancelOrder(request);

      state = state.copyWith(
        isLoading: false,
        success: response.success,
        message: response.message,
        error: response.success ? null : response.message,
      );

      return response.success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: normalizeErrorMessage(e, fallback: '取消订单失败'),
      );
      return false;
    }
  }

  /// 申请退款
  Future<bool> requestRefund(int orderId, String reason) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final request = RefundRequest(orderId: orderId, reason: reason);

      final response = await _repository.requestRefund(request);

      state = state.copyWith(
        isLoading: false,
        success: response.success,
        message: response.message,
        error: response.success ? null : response.message,
      );

      return response.success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: normalizeErrorMessage(e, fallback: '申请退款失败'),
      );
      return false;
    }
  }

  /// 提交评价
  Future<bool> submitEvaluation(
    int orderId,
    int rating,
    String? comment,
  ) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final request = EvaluationRequest(
        orderId: orderId,
        rating: rating,
        comment: comment,
      );

      final success = await _repository.submitEvaluation(request);

      state = state.copyWith(
        isLoading: false,
        success: success,
        message: success ? '评价成功' : '评价失败',
        error: success ? null : '评价提交失败',
      );

      return success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: normalizeErrorMessage(e, fallback: '提交评价失败'),
      );
      return false;
    }
  }

  /// 提交追评
  Future<bool> submitFollowupEvaluation(int orderId, String content) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _repository.submitFollowupEvaluation(
        orderId,
        content,
      );
      state = state.copyWith(
        isLoading: false,
        success: success,
        message: success ? '追评成功' : '追评失败',
        error: success ? null : '追评提交失败',
      );
      return success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: normalizeErrorMessage(e, fallback: '追评提交失败'),
      );
      return false;
    }
  }

  /// 发送 SOS 紧急呼叫
  Future<bool> triggerSos(int orderId, {String? description}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _repository.triggerSos(
        orderId,
        description: description,
      );

      state = state.copyWith(
        isLoading: false,
        success: success,
        message: success ? 'SOS已发送，平台正在紧急处理' : 'SOS发送失败',
        error: success ? null : 'SOS发送失败',
      );
      return success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: normalizeErrorMessage(e, fallback: 'SOS发送失败'),
      );
      return false;
    }
  }
}

// ============= Providers =============

/// 订单列表状态 Provider
final orderListProvider =
    StateNotifierProvider<OrderListNotifier, OrderListState>((ref) {
      final repository = ref.watch(orderRepositoryProvider);
      return OrderListNotifier(repository);
    });

/// 订单详情状态 Provider
final orderDetailProvider =
    StateNotifierProvider.family<OrderDetailNotifier, OrderDetailState, int>((
      ref,
      orderId,
    ) {
      final repository = ref.watch(orderRepositoryProvider);
      final notifier = OrderDetailNotifier(repository);
      notifier.loadOrder(orderId);
      return notifier;
    });

/// 支付状态 Provider
final paymentProvider =
    StateNotifierProvider.family<PaymentNotifier, PaymentState, int>((
      ref,
      orderId,
    ) {
      final repository = ref.watch(orderRepositoryProvider);
      final alipayService = ref.watch(alipayServiceProvider);
      final notifier = PaymentNotifier(repository, alipayService);
      notifier.initPayment(orderId);
      return notifier;
    });

/// 订单操作状态 Provider
final orderOperationProvider =
    StateNotifierProvider<OrderOperationNotifier, OrderOperationState>((ref) {
      final repository = ref.watch(orderRepositoryProvider);
      return OrderOperationNotifier(repository);
    });

/// 检查订单是否可取消
final canCancelOrderProvider = FutureProvider.family<bool, int>((
  ref,
  orderId,
) async {
  final repository = ref.watch(orderRepositoryProvider);
  try {
    final order = await repository.getOrderDetail(orderId);
    return order.canCancel;
  } catch (e) {
    return false;
  }
});

/// 获取剩余取消时间
final remainingCancelTimeProvider = Provider.family<int, OrderModel?>((
  ref,
  order,
) {
  if (order == null) return 0;
  return order.remainingCancelMinutes;
});

/// 订单分类状态（用于 TabBar 订单管理页面）
enum OrderTab {
  toPay, // 待支付（0）
  pending, // 待服务（待接单1、已接单2）
  inProgress, // 进行中（已到达3、服务中4）
  completed, // 已完成/售后（待评价5、已完成6、已取消/退款7）
}

/// 分类订单列表状态
class CategorizedOrderListState {
  final List<OrderModel> orders;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;
  final OrderTab currentTab;

  const CategorizedOrderListState({
    this.orders = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
    this.currentTab = OrderTab.pending,
  });

  CategorizedOrderListState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
    OrderTab? currentTab,
  }) {
    return CategorizedOrderListState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
      currentTab: currentTab ?? this.currentTab,
    );
  }

  /// 获取当前 Tab 对应的状态值列表
  List<int> get statusList {
    switch (currentTab) {
      case OrderTab.toPay:
        return [0]; // 待支付
      case OrderTab.pending:
        return [1, 2]; // 待接单、已接单
      case OrderTab.inProgress:
        return [3, 4]; // 已到达、服务中
      case OrderTab.completed:
        return [5, 6, 7]; // 待评价、已完成、已取消/退款
    }
  }
}

/// 分类订单列表状态管理
class CategorizedOrderListNotifier
    extends StateNotifier<CategorizedOrderListState> {
  final OrderRepository _repository;

  CategorizedOrderListNotifier(this._repository)
    : super(const CategorizedOrderListState());

  /// 切换 Tab
  void switchTab(OrderTab tab) {
    if (state.currentTab != tab) {
      state = CategorizedOrderListState(currentTab: tab);
      loadOrders(refresh: true);
    }
  }

  /// 加载订单列表
  Future<void> loadOrders({bool refresh = false}) async {
    if (state.isLoading) return;

    final page = refresh ? 1 : state.currentPage;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // 根据当前 Tab 获取对应状态的订单
      final statusList = state.statusList;
      List<OrderModel> allOrders = [];

      // 获取多个状态的订单
      for (final status in statusList) {
        final orders = await _repository.getOrderList(
          status: status,
          page: page,
        );
        allOrders.addAll(orders);
      }

      // 按创建时间排序（最新的在前）
      allOrders.sort((a, b) {
        final aTime = a.createdAt ?? '';
        final bTime = b.createdAt ?? '';
        return bTime.compareTo(aTime);
      });

      state = state.copyWith(
        orders: refresh ? allOrders : [...state.orders, ...allOrders],
        isLoading: false,
        hasMore: allOrders.length >= 10,
        currentPage: page + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: normalizeErrorMessage(e, fallback: '加载订单失败'),
      );
    }
  }

  /// 刷新订单列表
  Future<void> refresh() async {
    await loadOrders(refresh: true);
  }

  /// 加载更多
  Future<void> loadMore() async {
    if (state.hasMore && !state.isLoading) {
      await loadOrders();
    }
  }

  /// 更新单个订单状态（用于推送通知更新）
  void updateOrder(OrderModel order) {
    final index = state.orders.indexWhere((o) => o.id == order.id);
    if (index != -1) {
      final newOrders = List<OrderModel>.from(state.orders);
      newOrders[index] = order;
      state = state.copyWith(orders: newOrders);
    }
  }

  /// 根据订单ID刷新单个订单
  Future<void> refreshOrder(int orderId) async {
    try {
      final order = await _repository.getOrderDetail(orderId);
      updateOrder(order);
    } catch (e) {
      // 忽略错误
    }
  }

  /// 移除订单（用于订单状态变更后不再属于当前 Tab）
  void removeOrder(int orderId) {
    final newOrders = state.orders.where((o) => o.id != orderId).toList();
    state = state.copyWith(orders: newOrders);
  }
}

/// 分类订单列表 Provider
final categorizedOrderListProvider =
    StateNotifierProvider<
      CategorizedOrderListNotifier,
      CategorizedOrderListState
    >((ref) {
      final repository = ref.watch(orderRepositoryProvider);
      return CategorizedOrderListNotifier(repository);
    });
