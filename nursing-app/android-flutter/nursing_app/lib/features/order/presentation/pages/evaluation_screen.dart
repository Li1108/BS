import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import '../../providers/order_provider.dart';

/// 订单评价页面
///
/// 功能：
/// 1. 5星RatingBar评分
/// 2. TextField文字评价
/// 3. 提交后不可修改
/// 4. 后端更新护士评分（服务层计算）
@RoutePage()
class EvaluationScreenPage extends ConsumerStatefulWidget {
  final int orderId;

  const EvaluationScreenPage({
    super.key,
    @PathParam('orderId') required this.orderId,
  });

  @override
  ConsumerState<EvaluationScreenPage> createState() =>
      _EvaluationScreenPageState();
}

class _EvaluationScreenPageState extends ConsumerState<EvaluationScreenPage> {
  // 评价相关状态
  double _rating = 5.0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingEvaluation = false;
  final _followupController = TextEditingController();
  Map<String, dynamic>? _evaluationDetail;

  // 预设评价标签
  final List<String> _quickTags = [
    '服务专业',
    '态度友好',
    '准时到达',
    '耐心细致',
    '技术娴熟',
    '沟通顺畅',
    '环境整洁',
    '下次还选',
  ];

  // 已选择的标签
  final Set<String> _selectedTags = {};

  @override
  void dispose() {
    _commentController.dispose();
    _followupController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadEvaluationDetail();
  }

  Future<void> _loadEvaluationDetail() async {
    if (_isLoadingEvaluation) return;
    setState(() => _isLoadingEvaluation = true);
    try {
      final repo = ref.read(orderRepositoryProvider);
      final detail = await repo.getOrderEvaluation(widget.orderId);
      if (!mounted) return;
      setState(() {
        _evaluationDetail = detail;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingEvaluation = false);
      }
    }
  }

  DateTime? _parseDateTime(String? text) {
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  bool _canFollowup(OrderModel order) {
    final raw = (_evaluationDetail?['createTime'] ?? order.evaluationTime)
        ?.toString();
    final dt = _parseDateTime(raw);
    if (dt == null) return false;
    return DateTime.now().difference(dt).inDays <= 7;
  }

  Future<void> _submitFollowup(OrderModel order) async {
    final content = _followupController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入追评内容'), backgroundColor: Colors.red),
      );
      return;
    }

    final success = await ref
        .read(orderOperationProvider.notifier)
        .submitFollowupEvaluation(order.id, content);
    if (!mounted) return;

    final state = ref.read(orderOperationProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(state.message ?? (success ? '追评成功' : '追评失败')),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      _followupController.clear();
      await _loadEvaluationDetail();
      ref
          .read(orderDetailProvider(widget.orderId).notifier)
          .loadOrder(widget.orderId);
    }
  }

  /// 获取评分描述文字
  String _getRatingText(double rating) {
    if (rating >= 5) return '非常满意';
    if (rating >= 4) return '满意';
    if (rating >= 3) return '一般';
    if (rating >= 2) return '不满意';
    return '非常不满意';
  }

  /// 获取评分颜色
  Color _getRatingColor(double rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.orange;
    return Colors.red;
  }

  /// 切换标签选择
  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  /// 生成评价内容（标签 + 自定义内容）
  String _generateComment() {
    final buffer = StringBuffer();

    // 添加选中的标签
    if (_selectedTags.isNotEmpty) {
      buffer.write(_selectedTags.join('、'));
    }

    // 添加自定义内容
    final customComment = _commentController.text.trim();
    if (customComment.isNotEmpty) {
      if (buffer.isNotEmpty) {
        buffer.write('。');
      }
      buffer.write(customComment);
    }

    return buffer.toString();
  }

  /// 提交评价
  Future<void> _submitEvaluation() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final comment = _generateComment();

      final success = await ref
          .read(orderOperationProvider.notifier)
          .submitEvaluation(widget.orderId, _rating.round(), comment);

      if (!mounted) return;

      if (success) {
        await ref
            .read(orderDetailProvider(widget.orderId).notifier)
            .loadOrder(widget.orderId);
        await _loadEvaluationDetail();
        await ref.read(orderListProvider.notifier).refresh();
        if (!mounted) return;

        // 显示成功对话框
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, size: 64.sp, color: Colors.green),
                SizedBox(height: 16.h),
                Text(
                  '评价成功',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '感谢您的评价，您的反馈将帮助我们提供更好的服务！',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // 返回上一页
                    context.router.maybePop(true);
                  },
                  child: const Text('完成'),
                ),
              ),
            ],
          ),
        );
      } else {
        // 显示错误提示
        final state = ref.read(orderOperationProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error ?? '评价提交失败，请稍后重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderDetailProvider(widget.orderId));
    // 监听操作状态以响应变化
    ref.watch(orderOperationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('服务评价'),
        centerTitle: true,
        elevation: 0,
      ),
      body: orderState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : orderState.order == null
          ? _buildErrorView(orderState.error ?? '订单不存在')
          : _buildContent(orderState.order!),
      bottomNavigationBar:
          orderState.order != null && !_isAlreadyEvaluated(orderState.order!)
          ? _buildSubmitButton()
          : null,
    );
  }

  /// 检查是否已评价（已完成状态表示已评价）
  bool _isAlreadyEvaluated(OrderModel order) {
    return order.orderStatus == OrderStatus.completed ||
        _evaluationDetail != null;
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: Colors.grey),
          SizedBox(height: 16.h),
          Text(
            error,
            style: TextStyle(color: Colors.grey, fontSize: 14.sp),
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(orderDetailProvider(widget.orderId).notifier)
                  .loadOrder(widget.orderId);
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(OrderModel order) {
    // 如果订单状态是已完成（已评价），显示已评价内容
    if (_isAlreadyEvaluated(order)) {
      return _buildAlreadyEvaluatedView(order);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 订单信息卡片
          _buildOrderInfoCard(order),
          SizedBox(height: 24.h),

          // 护士信息卡片
          if (order.nurseName != null) ...[
            _buildNurseInfoCard(order),
            SizedBox(height: 24.h),
          ],

          // 评分区域
          _buildRatingSection(),
          SizedBox(height: 24.h),

          // 快捷标签
          _buildQuickTagsSection(),
          SizedBox(height: 24.h),

          // 评价内容输入
          _buildCommentSection(),
          SizedBox(height: 24.h),

          // 评价须知
          _buildNoticeSection(),
          SizedBox(height: 100.h),
        ],
      ),
    );
  }

  Widget _buildAlreadyEvaluatedView(OrderModel order) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 订单信息卡片
          _buildOrderInfoCard(order),
          SizedBox(height: 24.h),

          // 已评价提示
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle, size: 64.sp, color: Colors.green),
                SizedBox(height: 16.h),
                Text(
                  '您已完成评价',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '感谢您的反馈，评价提交后不可修改',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // 显示评价内容（如果有）
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
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
                Text(
                  '我的评价',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final ratingValue =
                            (_evaluationDetail?['rating'] as num?)
                                ?.toDouble() ??
                            (order.rating?.toDouble() ?? 5.0);
                        return RatingBarIndicator(
                          rating: ratingValue,
                          itemCount: 5,
                          itemSize: 24.sp,
                          itemBuilder: (context, _) =>
                              const Icon(Icons.star, color: Colors.amber),
                        );
                      },
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${(_evaluationDetail?['rating'] ?? order.rating ?? 5)}分',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                if (_isLoadingEvaluation)
                  const LinearProgressIndicator(minHeight: 2)
                else
                  Text(
                    (_evaluationDetail?['content']
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                            true)
                        ? _evaluationDetail!['content'].toString()
                        : (order.evaluationContent?.isNotEmpty == true
                              ? order.evaluationContent!
                              : '暂无评价内容'),
                    style: TextStyle(fontSize: 14.sp),
                  ),
              ],
            ),
          ),
          if (_canFollowup(order)) ...[
            SizedBox(height: 16.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
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
                  Text(
                    '追加评价（7天内）',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  TextField(
                    controller: _followupController,
                    maxLines: 3,
                    maxLength: 200,
                    decoration: InputDecoration(
                      hintText: '请输入追评内容',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => _submitFollowup(order),
                      child: const Text('提交追评'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(OrderModel order) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  Icons.medical_services,
                  size: 24.sp,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.serviceName,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '服务时间：${_formatDateTime(order.appointmentTime)}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (e) {
      return dateTime;
    }
  }

  Widget _buildNurseInfoCard(OrderModel order) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
          Text(
            '服务护士',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              CircleAvatar(
                radius: 28.r,
                backgroundColor: Colors.blue.withValues(alpha: 0.1),
                child: Icon(Icons.person, size: 32.sp, color: Colors.blue),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.nurseName!,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    if (order.nurseRating != null)
                      Row(
                        children: [
                          Icon(Icons.star, size: 16.sp, color: Colors.amber),
                          SizedBox(width: 4.w),
                          Text(
                            '${order.nurseRating!.toStringAsFixed(1)} 分',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '请对本次服务进行评分',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 20.h),
          RatingBar.builder(
            initialRating: _rating,
            minRating: 1,
            direction: Axis.horizontal,
            allowHalfRating: false,
            itemCount: 5,
            itemSize: 48.sp,
            itemPadding: EdgeInsets.symmetric(horizontal: 8.w),
            unratedColor: Colors.grey.shade300,
            itemBuilder: (context, index) =>
                Icon(Icons.star_rounded, color: Colors.amber),
            onRatingUpdate: (rating) {
              setState(() {
                _rating = rating;
              });
            },
          ),
          SizedBox(height: 16.h),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _getRatingText(_rating),
              key: ValueKey(_rating),
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: _getRatingColor(_rating),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTagsSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
          Text(
            '快捷评价（可多选）',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: _quickTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () => _toggleTag(tag),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '详细评价（选填）',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              Text(
                '${_commentController.text.length}/200',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _commentController,
            maxLines: 5,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: '请分享您的服务体验，帮助其他用户了解...',
              hintStyle: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey.shade400,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              counterText: '',
              contentPadding: EdgeInsets.all(12.w),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18.sp, color: Colors.orange),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              '评价提交后将不可修改，请确认后再提交。您的真实评价将帮助护士改进服务质量。',
              style: TextStyle(fontSize: 13.sp, color: Colors.orange.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: EdgeInsets.all(16.w),
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
        child: SizedBox(
          width: double.infinity,
          height: 48.h,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitEvaluation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
              ),
            ),
            child: _isSubmitting
                ? SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    '提交评价',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
