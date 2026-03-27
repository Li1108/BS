import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/order_repository.dart';

class EvaluationHistoryPage extends ConsumerStatefulWidget {
  const EvaluationHistoryPage({super.key});

  @override
  ConsumerState<EvaluationHistoryPage> createState() =>
      _EvaluationHistoryPageState();
}

class _EvaluationHistoryPageState extends ConsumerState<EvaluationHistoryPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(orderRepositoryProvider);
      final records = await repo.getMyEvaluationHistory(page: 1, pageSize: 100);
      if (!mounted) return;
      setState(() {
        _items = records;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatTime(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return '-';
    final dt = DateTime.tryParse(text);
    if (dt == null) return text;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的评价'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: TextStyle(fontSize: 13.sp, color: AppTheme.errorColor),
              ),
            )
          : _items.isEmpty
          ? const Center(child: Text('暂无评价记录'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: EdgeInsets.all(16.w),
                itemCount: _items.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final rating = (item['rating'] as num?)?.toInt() ?? 0;
                  final content = item['content']?.toString() ?? '';
                  final orderNo =
                      (item['orderNo'] ??
                              item['order_no'] ??
                              item['order_number'])
                          ?.toString()
                          .trim();
                  final orderId = (item['orderId'] ?? item['order_id'])
                      ?.toString()
                      .trim();
                  final orderDisplay = (orderNo != null && orderNo.isNotEmpty)
                      ? orderNo
                      : ((orderId != null && orderId.isNotEmpty)
                            ? 'ID:$orderId'
                            : '-');
                  return Container(
                    padding: EdgeInsets.all(14.w),
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
                            Expanded(
                              child: Text(
                                '订单号：$orderDisplay',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ),
                            Text(
                              _formatTime(item['createTime']),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppTheme.textHintColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: List.generate(
                            5,
                            (star) => Icon(
                              star < rating ? Icons.star : Icons.star_border,
                              size: 18.sp,
                              color: Colors.amber,
                            ),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          content.isEmpty ? '暂无评价内容' : content,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppTheme.textPrimaryColor,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
