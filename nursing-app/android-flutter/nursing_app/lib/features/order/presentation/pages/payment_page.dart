import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_route/auto_route.dart';

import '../../../../core/router/app_router.dart';
import '../../data/models/order_model.dart';
import '../../providers/order_provider.dart';

/// 支付页面
///
/// 功能：
/// 1. 显示订单信息和支付金额
/// 2. 集成支付宝支付
/// 3. 显示支付结果
/// 4. 支持30分钟内取消/退款
@RoutePage()
class PaymentPage extends ConsumerStatefulWidget {
  final int orderId;
  final double? amount;

  const PaymentPage({
    super.key,
    @PathParam('orderId') required this.orderId,
    this.amount,
  });

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  final _reasonController = TextEditingController();
  bool _showCancelDialog = false;
  bool _showRefundDialog = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('订单支付'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: paymentState.isLoading && paymentState.order == null
          ? const Center(child: CircularProgressIndicator())
          : paymentState.order == null
          ? _buildErrorView(paymentState.message ?? '加载失败')
          : _buildContent(paymentState),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(paymentProvider(widget.orderId).notifier)
                  .initPayment(widget.orderId);
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(PaymentState state) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 支付状态卡片
              _buildStatusCard(state),
              const SizedBox(height: 16),

              // 订单信息卡片
              _buildOrderInfoCard(state.order!),
              const SizedBox(height: 16),

              // 支付金额卡片
              _buildAmountCard(state.order!),
              const SizedBox(height: 16),

              // 支付方式卡片
              if (state.order!.orderStatus == OrderStatus.pendingPayment)
                _buildPaymentMethodCard(),

              // 取消/退款信息
              if (state.order!.canCancel || state.order!.canRefund)
                _buildCancelInfoCard(state),

              const SizedBox(height: 100),
            ],
          ),
        ),

        // 底部操作按钮
        _buildBottomButtons(state),

        // 加载遮罩
        if (state.isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(child: CircularProgressIndicator()),
          ),

        // 取消对话框
        if (_showCancelDialog) _buildCancelDialog(),

        // 退款对话框
        if (_showRefundDialog) _buildRefundDialog(state.order!),
      ],
    );
  }

  Widget _buildStatusCard(PaymentState state) {
    IconData icon;
    Color color;
    String title;
    String? subtitle;

    switch (state.status) {
      case OrderPaymentStatus.processing:
        icon = Icons.hourglass_top;
        color = Colors.orange;
        title = '支付处理中...';
        break;
      case OrderPaymentStatus.success:
        icon = Icons.check_circle;
        color = Colors.green;
        title = '支付成功';
        subtitle = '服务人员将尽快与您联系';
        break;
      case OrderPaymentStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        title = '支付失败';
        subtitle = state.message;
        break;
      case OrderPaymentStatus.cancelled:
        icon = Icons.cancel;
        color = Colors.grey;
        title = '已取消支付';
        break;
      default:
        final orderStatus = state.order != null
            ? OrderStatus.fromValue(state.order!.status)
            : null;
        if (orderStatus == OrderStatus.pendingPayment) {
          icon = Icons.payment;
          color = Colors.blue;
          title = '待支付';
          subtitle = '请在30分钟内完成支付';
        } else if (state.order?.payStatus == 1) {
          icon = Icons.check_circle;
          color = Colors.green;
          title = '已支付';
          subtitle = _getOrderStatusSubtitle(state.order!);
        } else {
          icon = Icons.info;
          color = Colors.grey;
          title = orderStatus?.text ?? '订单状态';
        }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.white),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  String _getOrderStatusSubtitle(OrderModel order) {
    final orderStatus = OrderStatus.fromValue(order.status);
    switch (orderStatus) {
      case OrderStatus.pendingAccept:
        return '正在为您分配服务人员';
      case OrderStatus.accepted:
        return '服务人员已分配，等待上门';
      case OrderStatus.arrived:
        return '护士已到达';
      case OrderStatus.inService:
        return '服务进行中';
      case OrderStatus.pendingEvaluation:
        return '服务已完成，请评价';
      case OrderStatus.completed:
        return '服务已完成';
      case OrderStatus.cancelled:
        return '订单已取消';
      default:
        return '';
    }
  }

  Widget _buildOrderInfoCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                '订单信息',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Builder(
                builder: (context) {
                  final orderStatus = OrderStatus.fromValue(order.status);
                  final statusColor = Color(orderStatus.colorValue);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      orderStatus.text,
                      style: TextStyle(fontSize: 12, color: statusColor),
                    ),
                  );
                },
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow('订单编号', order.orderNo),
          const SizedBox(height: 12),
          _buildInfoRow('服务项目', order.serviceName),
          const SizedBox(height: 12),
          _buildInfoRow('预约时间', order.appointmentTime),
          const SizedBox(height: 12),
          _buildInfoRow('服务地址', order.address),
          if (order.nurseId != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow('联系人', order.contactName),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on, color: Colors.orange),
              const SizedBox(width: 8),
              const Text(
                '支付金额',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('服务费用', style: TextStyle(fontSize: 14)),
              Text(
                '¥${order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '实付金额',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '¥${order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.purple),
              const SizedBox(width: 8),
              const Text(
                '支付方式',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/alipay_logo.png',
                  width: 32,
                  height: 32,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: Text(
                          '支',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '支付宝支付',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                const Icon(Icons.check_circle, color: Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelInfoCard(PaymentState state) {
    final order = state.order!;
    final remainingSeconds = state.remainingCancelSeconds;
    final remainingMinutesPart = remainingSeconds ~/ 60;
    final remainingSecondsPart = remainingSeconds % 60;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Text(
                '取消/退款说明',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (order.canCancel) ...[
            Text(
              '• 支付后30分钟内可免费取消订单',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              '• 剩余取消时间：$remainingMinutesPart分$remainingSecondsPart秒',
              style: TextStyle(
                fontSize: 13,
                color: remainingSeconds <= 10 * 60
                    ? Colors.red
                    : Colors.grey[700],
                fontWeight: remainingSeconds <= 10 * 60
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
          if (order.canRefund && !order.canCancel) ...[
            Text(
              '• 订单已超过免费取消时间',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              '• 如需取消请联系客服申请退款',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
          if (order.orderRefundStatus == RefundStatus.processing) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '退款处理中',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomButtons(PaymentState state) {
    final order = state.order;
    if (order == null) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // 取消/退款按钮
              if (order.canCancel || order.canRefund) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.isLoading
                        ? null
                        : () {
                            if (order.canCancel) {
                              setState(() => _showCancelDialog = true);
                            } else {
                              setState(() => _showRefundDialog = true);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: Text(
                      order.canCancel ? '取消订单' : '申请退款',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],

              // 支付按钮 / 查看订单按钮
              Expanded(
                flex: order.canCancel || order.canRefund ? 2 : 1,
                child: ElevatedButton(
                  onPressed: state.isLoading
                      ? null
                      : () => _handlePrimaryAction(state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getPrimaryButtonColor(order),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _getPrimaryButtonText(order),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPrimaryButtonText(OrderModel order) {
    final orderStatus = OrderStatus.fromValue(order.status);
    switch (orderStatus) {
      case OrderStatus.pendingPayment:
        return '立即支付 ¥${order.totalAmount.toStringAsFixed(2)}';
      case OrderStatus.pendingEvaluation:
        return '去评价';
      default:
        return '查看订单';
    }
  }

  Color _getPrimaryButtonColor(OrderModel order) {
    final orderStatus = OrderStatus.fromValue(order.status);
    switch (orderStatus) {
      case OrderStatus.pendingPayment:
        return Colors.red;
      case OrderStatus.pendingEvaluation:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  void _handlePrimaryAction(PaymentState state) async {
    final order = state.order!;
    final orderStatus = OrderStatus.fromValue(order.status);

    switch (orderStatus) {
      case OrderStatus.pendingPayment:
        // 执行支付
        final success = await ref
            .read(paymentProvider(widget.orderId).notifier)
            .pay();
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('支付成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
        break;
      case OrderStatus.pendingEvaluation:
        // 跳转到评价页面
        if (mounted) {
          context.router.push(
            OrderDetailRoute(orderId: widget.orderId.toString()),
          );
        }
        break;
      default:
        // 跳转到订单详情
        if (mounted) {
          context.router.push(
            OrderDetailRoute(orderId: widget.orderId.toString()),
          );
        }
    }
  }

  Widget _buildCancelDialog() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              const Text(
                '确认取消订单？',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '取消后订单将关闭，支付金额将原路退回',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  hintText: '请输入取消原因（选填）',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _showCancelDialog = false);
                        _reasonController.clear();
                      },
                      child: const Text('再想想'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleCancelOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        '确认取消',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefundDialog(OrderModel order) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_balance_wallet,
                size: 48,
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              const Text(
                '申请退款',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '退款金额：¥${order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  hintText: '请输入退款原因',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              const Text(
                '提交后系统会自动原路退款至支付账户',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _showRefundDialog = false);
                        _reasonController.clear();
                      },
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleRefund,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text(
                        '提交申请',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCancelOrder() async {
    setState(() => _showCancelDialog = false);

    final reason = _reasonController.text.trim();
    final response = await ref
        .read(paymentProvider(widget.orderId).notifier)
        .cancelOrder(reason.isEmpty ? '用户主动取消' : reason);

    _reasonController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: response.success ? Colors.green : Colors.red,
        ),
      );

      if (response.success) {
        // 返回上一页并刷新订单列表
        context.router.maybePop(true);
      }
    }
  }

  void _handleRefund() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入退款原因'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _showRefundDialog = false);

    final response = await ref
        .read(paymentProvider(widget.orderId).notifier)
        .requestRefund(reason);

    _reasonController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: response.success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
