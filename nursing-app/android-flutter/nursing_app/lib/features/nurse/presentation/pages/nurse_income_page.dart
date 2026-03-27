import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/commercial_ui_widgets.dart';
import '../../data/models/nurse_profile_model.dart';
import '../../providers/nurse_provider.dart';

/// 护士收入页面
///
/// 功能：
/// 1. 展示账户余额和收入统计
/// 2. 展示订单收入明细（扣除平台费率后的实际收入）
/// 3. 申请提现（后端线下处理）
/// 4. 查看提现记录
@RoutePage()
class NurseIncomePage extends ConsumerStatefulWidget {
  const NurseIncomePage({super.key});

  @override
  ConsumerState<NurseIncomePage> createState() => _NurseIncomePageState();
}

class _NurseIncomePageState extends ConsumerState<NurseIncomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RefreshController _refreshController = RefreshController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 初始化加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(incomeProvider.notifier).init();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  /// 下拉刷新
  void _onRefresh() async {
    await ref.read(incomeProvider.notifier).refresh();
    _refreshController.refreshCompleted();
  }

  /// 加载更多
  void _onLoadMore() async {
    await ref.read(incomeProvider.notifier).loadMoreLogs();
    final state = ref.read(incomeProvider);
    if (state.hasMore) {
      _refreshController.loadComplete();
    } else {
      _refreshController.loadNoData();
    }
  }

  /// 显示提现对话框
  void _showWithdrawDialog() {
    final state = ref.read(incomeProvider);
    final amountController = TextEditingController();
    final alipayController = TextEditingController();
    final nameController = TextEditingController();

    // 预填充真实姓名
    if (state.profile != null) {
      nameController.text = state.profile!.realName;
    }

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final amount = double.tryParse(amountController.text) ?? 0;
          final amountValid =
              amount >= state.minWithdrawAmount &&
              amount <= state.availableBalance;
          final alipayValid = alipayController.text.trim().isNotEmpty;
          final nameValid = nameController.text.trim().isNotEmpty;

          return AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              left: 16.w,
              right: 16.w,
              top: 16.h,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16.h,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 拖动指示条
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // 标题
                  Text(
                    '申请提现',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),

                  // 可提现余额
                  Row(
                    children: [
                      Text(
                        '可提现余额：',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      Text(
                        '¥${state.availableBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '最低提现金额：¥${state.minWithdrawAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.textHintColor,
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // 提现金额输入
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: '提现金额',
                      hintText: '请输入提现金额',
                      prefixText: '¥ ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      suffixIcon: TextButton(
                        onPressed: () {
                          amountController.text = state.availableBalance
                              .toStringAsFixed(2);
                          setSheetState(() {});
                        },
                        child: const Text('全部提现'),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  SizedBox(height: 4.h),
                  _buildFieldHint(
                    valid: amountValid,
                    validText: '金额可提现',
                    invalidText:
                        '提现金额需在 ¥${state.minWithdrawAmount.toStringAsFixed(2)} - ¥${state.availableBalance.toStringAsFixed(2)} 之间',
                  ),
                  SizedBox(height: 12.h),

                  // 支付宝账号输入
                  TextField(
                    controller: alipayController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: '支付宝账号',
                      hintText: '请输入支付宝账号（手机号或邮箱）',
                      prefixIcon: const Icon(Icons.account_balance_wallet),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  SizedBox(height: 4.h),
                  _buildFieldHint(
                    valid: alipayValid,
                    validText: '账号已填写',
                    invalidText: '请输入支付宝账号',
                  ),
                  SizedBox(height: 12.h),

                  // 真实姓名输入
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '真实姓名',
                      hintText: '请输入支付宝账号对应的真实姓名',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  SizedBox(height: 4.h),
                  _buildFieldHint(
                    valid: nameValid,
                    validText: '姓名已填写',
                    invalidText: '请输入真实姓名',
                  ),
                  SizedBox(height: 24.h),

                  // 提交按钮
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amount =
                            double.tryParse(amountController.text) ?? 0;
                        final alipay = alipayController.text.trim();
                        final name = nameController.text.trim();

                        final confirm = await AppConfirmSheet.show(
                          context: context,
                          title: '确认提现申请',
                          message:
                              '提现金额：¥${amount.toStringAsFixed(2)}\n支付宝账号：$alipay\n真实姓名：$name',
                          confirmText: '确认提现',
                          cancelText: '再检查',
                          icon: Icons.account_balance_wallet_outlined,
                        );
                        if (!confirm) return;

                        final response = await ref
                            .read(incomeProvider.notifier)
                            .requestWithdraw(
                              amount: amount,
                              alipayAccount: alipay,
                              realName: name,
                            );

                        if (!context.mounted) return;

                        Navigator.of(context).pop();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(response.message),
                            backgroundColor: response.success
                                ? Colors.green
                                : Colors.red,
                          ),
                        );

                        if (!response.success) {
                          final retry = await AppConfirmSheet.show(
                            context: context,
                            title: '提现申请失败',
                            message: response.message,
                            confirmText: '重试',
                            cancelText: '稍后',
                            icon: Icons.error_outline_rounded,
                            iconBgColor: const Color(0x33F44336),
                            iconColor: Colors.redAccent,
                          );
                          if (retry) {
                            _showWithdrawDialog();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: Text(
                        '确认提现',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // 提示文字
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '提现将在1-3个工作日内到账',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.textHintColor,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '实际提现由平台线下处理',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.textHintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 显示提现记录
  void _showWithdrawHistory() {
    ref.read(incomeProvider.notifier).loadWithdrawals();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(incomeProvider);

              return Column(
                children: [
                  // 标题栏
                  Container(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '提现记录',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // 列表
                  Expanded(
                    child: state.isLoadingWithdrawals
                        ? const Center(child: CircularProgressIndicator())
                        : state.withdrawals.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64.w,
                                  color: Colors.grey.shade300,
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  '暂无提现记录',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: EdgeInsets.all(16.w),
                            itemCount: state.withdrawals.length,
                            itemBuilder: (context, index) {
                              final withdraw = state.withdrawals[index];
                              return _buildWithdrawItem(withdraw);
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildWithdrawItem(WithdrawModel withdraw) {
    final status = withdraw.withdrawStatus;
    final statusColor = Color(status.colorValue);

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: () => _showWithdrawDetail(withdraw),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '¥${withdraw.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Text(
                      status.text,
                      style: TextStyle(fontSize: 12.sp, color: statusColor),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                '支付宝：${withdraw.alipayAccount}',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '申请时间：${withdraw.createdAt ?? '-'}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.textHintColor,
                ),
              ),
              if (withdraw.rejectReason != null &&
                  withdraw.rejectReason!.isNotEmpty) ...[
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16.w, color: Colors.red),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          withdraw.rejectReason!,
                          style: TextStyle(fontSize: 12.sp, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incomeProvider);

    bool hasParentTabs = false;
    try {
      AutoTabsRouter.of(context);
      hasParentTabs = true;
    } catch (_) {
      hasParentTabs = false;
    }

    return Scaffold(
      appBar: hasParentTabs
          ? null
          : AppBar(
              title: const Text('我的收入'),
              centerTitle: true,
              actions: [
                TextButton(
                  onPressed: _showWithdrawHistory,
                  child: const Text('提现记录'),
                ),
              ],
            ),
      body: state.isLoading
          ? AppListSkeleton(
              itemCount: 6,
              itemHeight: 92,
              padding: EdgeInsets.all(16.w),
            )
          : state.error != null && state.walletLogs.isEmpty
          ? AppRetryGuide(
              title: '收入数据加载失败',
              message: state.error!,
              onRetry: () => ref.read(incomeProvider.notifier).init(),
            )
          : SmartRefresher(
              controller: _refreshController,
              enablePullDown: true,
              enablePullUp: true,
              onRefresh: _onRefresh,
              onLoading: _onLoadMore,
              child: CustomScrollView(
                slivers: [
                  // 余额卡片
                  SliverToBoxAdapter(child: _buildBalanceCard(state)),

                  // 收入统计
                  SliverToBoxAdapter(child: _buildStatisticsCard(state)),

                  // 标签栏和列表
                  SliverToBoxAdapter(child: _buildTabBar(state)),

                  // 流水列表
                  SliverToBoxAdapter(child: _buildWalletLogList(state)),
                ],
              ),
            ),
    );
  }

  /// 构建余额卡片
  Widget _buildBalanceCard(IncomeState state) {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '账户余额（元）',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              SizedBox(width: 8.w),
              Tooltip(
                message: '平台服务费：${state.feeRateText}\n收入 = 订单金额 × (1 - 费率)',
                child: Icon(
                  Icons.info_outline,
                  size: 16.w,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            '¥${state.availableBalance.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 40.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: state.availableBalance >= state.minWithdrawAmount
                ? _showWithdrawDialog
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.green,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
              disabledForegroundColor: Colors.green.withValues(alpha: 0.5),
              padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
              ),
            ),
            child: Text(
              '申请提现',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
          ),
          if (state.availableBalance < state.minWithdrawAmount) ...[
            SizedBox(height: 8.h),
            Text(
              '余额不足${state.minWithdrawAmount.toStringAsFixed(0)}元，暂无法提现',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建收入统计卡片
  Widget _buildStatisticsCard(IncomeState state) {
    final statistics = state.statistics ?? IncomeStatisticsModel();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
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
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              '今日收入',
              '¥${statistics.todayIncome.toStringAsFixed(2)}',
              '${statistics.todayOrders}单',
            ),
          ),
          Container(width: 1, height: 50.h, color: Colors.grey.shade200),
          Expanded(
            child: _buildStatItem(
              '本月收入',
              '¥${statistics.monthIncome.toStringAsFixed(2)}',
              '${statistics.monthOrders}单',
            ),
          ),
          Container(width: 1, height: 50.h, color: Colors.grey.shade200),
          Expanded(
            child: _buildStatItem(
              '累计收入',
              '¥${statistics.totalIncome.toStringAsFixed(2)}',
              '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12.sp, color: AppTheme.textSecondaryColor),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          SizedBox(height: 2.h),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11.sp, color: AppTheme.textHintColor),
          ),
        ],
      ],
    );
  }

  /// 构建标签栏
  Widget _buildTabBar(IncomeState state) {
    return Container(
      margin: EdgeInsets.only(top: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '收支明细',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14.w,
                color: AppTheme.textHintColor,
              ),
              SizedBox(width: 4.w),
              Text(
                '平台服务费：${state.feeRateText}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建流水列表
  Widget _buildWalletLogList(IncomeState state) {
    if (state.walletLogs.isEmpty) {
      return Container(
        padding: EdgeInsets.all(40.w),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64.w,
                color: Colors.grey.shade300,
              ),
              SizedBox(height: 16.h),
              Text(
                '暂无收支记录',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(16.w),
      itemCount: state.walletLogs.length,
      itemBuilder: (context, index) {
        final log = state.walletLogs[index];
        return _buildWalletLogItem(log);
      },
    );
  }

  Widget _buildWalletLogItem(WalletLogModel log) {
    final isIncome = log.isIncome;
    final typeColor = Color(log.logType.colorValue);

    return Card(
      margin: EdgeInsets.only(bottom: 8.h),
      elevation: 1,
      child: ListTile(
        onTap: () => _showWalletLogDetail(log),
        leading: Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(
            isIncome ? Icons.add_circle_outline : Icons.remove_circle_outline,
            color: typeColor,
            size: 24.w,
          ),
        ),
        title: Text(
          log.description ?? log.logType.text,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (log.refId != null && log.refId!.isNotEmpty) ...[
              SizedBox(height: 2.h),
              Text(
                '订单号：${log.refId}',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppTheme.textHintColor,
                ),
              ),
            ],
            SizedBox(height: 2.h),
            Text(
              log.createdAt ?? '',
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
        trailing: Text(
          '${isIncome ? '+' : ''}${log.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: typeColor,
          ),
        ),
      ),
    );
  }

  void _showWalletLogDetail(WalletLogModel log) {
    final isIncome = log.isIncome;
    final typeColor = Color(log.logType.colorValue);
    final amountText =
        '${isIncome ? '+' : ''}${log.amount.toStringAsFixed(2)} 元';

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '流水详情',
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12.h),
              _buildDetailRow('类型', log.logType.text),
              _buildDetailRow('金额', amountText, valueColor: typeColor),
              _buildDetailRow('说明', log.description ?? '-'),
              _buildDetailRow('时间', log.createdAt ?? '-'),
              if (log.refId != null && log.refId!.isNotEmpty)
                _buildDetailRow('关联单号', log.refId!),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('关闭'),
                    ),
                  ),
                  if (log.refId != null && log.refId!.isNotEmpty) ...[
                    SizedBox(width: 10.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: log.refId!));
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('关联单号已复制')),
                          );
                        },
                        child: const Text('复制单号'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWithdrawDetail(WithdrawModel withdraw) {
    final status = withdraw.withdrawStatus;
    final statusColor = Color(status.colorValue);

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '提现详情',
                style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 12.h),
              _buildDetailRow('提现金额', '¥${withdraw.amount.toStringAsFixed(2)}'),
              _buildDetailRow('提现账号', withdraw.alipayAccount),
              _buildDetailRow('真实姓名', withdraw.realName),
              _buildDetailRow('申请时间', withdraw.createdAt ?? '-'),
              if (withdraw.auditTime != null && withdraw.auditTime!.isNotEmpty)
                _buildDetailRow('审核时间', withdraw.auditTime!),
              _buildDetailRow('状态', status.text, valueColor: statusColor),
              if (withdraw.rejectReason != null &&
                  withdraw.rejectReason!.trim().isNotEmpty)
                _buildDetailRow('驳回原因', withdraw.rejectReason!),
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('关闭'),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: withdraw.alipayAccount),
                        );
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('支付宝账号已复制')),
                        );
                      },
                      child: const Text('复制账号'),
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

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                color: valueColor ?? AppTheme.textPrimaryColor,
                fontWeight: valueColor != null
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldHint({
    required bool valid,
    required String validText,
    required String invalidText,
  }) {
    return Row(
      children: [
        Icon(
          valid
              ? Icons.check_circle_outline_rounded
              : Icons.info_outline_rounded,
          size: 14.sp,
          color: valid ? Colors.green : AppTheme.textHintColor,
        ),
        SizedBox(width: 4.w),
        Expanded(
          child: Text(
            valid ? validText : invalidText,
            style: TextStyle(
              fontSize: 12.sp,
              color: valid ? Colors.green : AppTheme.textHintColor,
            ),
          ),
        ),
      ],
    );
  }
}
