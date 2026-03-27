import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/push_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/commercial_ui_widgets.dart';
import '../../data/models/order_model.dart';
import '../../providers/order_provider.dart';

/// 订单管理页面
///
/// 功能：
/// 1. TabBar 分"待服务"、"进行中"、"已完成"三个维度
/// 2. 支持分页加载和下拉刷新（PullToRefresh）
/// 3. 查看接单护士的姓名与联系电话
/// 4. 集成阿里云移动推送接收订单更新通知
@RoutePage()
class OrdersScreenPage extends ConsumerStatefulWidget {
  const OrdersScreenPage({super.key});

  @override
  ConsumerState<OrdersScreenPage> createState() => _OrdersScreenPageState();
}

class _OrdersScreenPageState extends ConsumerState<OrdersScreenPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final List<RefreshController> _refreshControllers = [];
  Timer? _syncTimer;
  Timer? _countdownTickTimer;
  final TextEditingController _serviceKeywordController =
      TextEditingController();
  DateTimeRange? _historyDateRange;
  int? _historyStatusFilter;

  // Tab 配置
  final List<Map<String, dynamic>> _tabs = [
    {'label': '待支付', 'tab': OrderTab.toPay},
    {'label': '待服务', 'tab': OrderTab.pending},
    {'label': '进行中', 'tab': OrderTab.inProgress},
    {'label': '已完成/售后', 'tab': OrderTab.completed},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: _tabs.length, vsync: this);

    // 为每个 Tab 创建 RefreshController
    for (var i = 0; i < _tabs.length; i++) {
      _refreshControllers.add(RefreshController());
    }

    // 监听 Tab 切换
    _tabController.addListener(_onTabChanged);

    // 初始加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
      _initPushService();
      _startStatusSync();
      _startCountdownTick();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _countdownTickTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    for (var controller in _refreshControllers) {
      controller.dispose();
    }
    _serviceKeywordController.dispose();
    super.dispose();
  }

  bool _withinDateRange(OrderModel order) {
    if (_historyDateRange == null) return true;
    final createdAt = order.createdAt;
    if (createdAt == null || createdAt.isEmpty) return false;
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return false;
    final start = DateTime(
      _historyDateRange!.start.year,
      _historyDateRange!.start.month,
      _historyDateRange!.start.day,
    );
    final end = DateTime(
      _historyDateRange!.end.year,
      _historyDateRange!.end.month,
      _historyDateRange!.end.day,
      23,
      59,
      59,
    );
    return !dt.isBefore(start) && !dt.isAfter(end);
  }

  List<OrderModel> _applyFilters(List<OrderModel> source) {
    final keyword = _serviceKeywordController.text.trim();
    return source.where((order) {
      if (_historyStatusFilter != null &&
          order.status != _historyStatusFilter) {
        return false;
      }
      if (keyword.isNotEmpty && !order.serviceName.contains(keyword)) {
        return false;
      }
      if (!_withinDateRange(order)) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _openFilterSheet() async {
    final statuses = <Map<String, dynamic>>[
      {'label': '全部状态', 'value': null},
      {'label': '待支付', 'value': 0},
      {'label': '待服务', 'value': 1},
      {'label': '已接单', 'value': 2},
      {'label': '服务中', 'value': 4},
      {'label': '已完成/售后', 'value': 7},
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        int? tempStatus = _historyStatusFilter;
        DateTimeRange? tempRange = _historyDateRange;
        final tempController = TextEditingController(
          text: _serviceKeywordController.text,
        );

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '历史订单筛选',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: tempController,
                    decoration: const InputDecoration(
                      labelText: '服务类型关键字',
                      hintText: '如：静脉采血、血糖监测',
                    ),
                  ),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<int?>(
                    initialValue: tempStatus,
                    decoration: const InputDecoration(labelText: '订单状态'),
                    items: statuses
                        .map(
                          (e) => DropdownMenuItem<int?>(
                            value: e['value'] as int?,
                            child: Text(e['label'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setModalState(() => tempStatus = val),
                  ),
                  SizedBox(height: 12.h),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tempRange == null
                          ? '选择时间范围'
                          : '${DateFormat('yyyy-MM-dd').format(tempRange!.start)} ~ ${DateFormat('yyyy-MM-dd').format(tempRange!.end)}',
                    ),
                    trailing: const Icon(Icons.date_range),
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDateRange: tempRange,
                      );
                      if (range != null) {
                        setModalState(() => tempRange = range);
                      }
                    },
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempStatus = null;
                            tempRange = null;
                            tempController.clear();
                          });
                        },
                        child: const Text('清空条件'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _historyStatusFilter = tempStatus;
                            _historyDateRange = tempRange;
                            _serviceKeywordController.text =
                                tempController.text;
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('应用筛选'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 初始化推送服务
  void _initPushService() {
    final pushService = PushService.instance;

    // 设置推送通知回调
    pushService.setNotificationCallback(
      onReceived: _handlePushNotification,
      onOpened: _handlePushNotificationOpened,
    );
  }

  /// 处理收到的推送通知
  void _handlePushNotification(Map<String, dynamic> notification) {
    // 解析通知类型
    final type = notification['type'] as int?;
    final orderId = notification['order_id'] as int?;

    if (type == 1 && orderId != null) {
      // 订单更新通知，刷新订单数据
      ref.read(categorizedOrderListProvider.notifier).refreshOrder(orderId);

      // 显示 SnackBar 提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notification['content'] ?? '订单状态已更新'),
            action: SnackBarAction(
              label: '查看',
              onPressed: () {
                context.router.push(
                  OrderDetailRoute(orderId: orderId.toString()),
                );
              },
            ),
          ),
        );
      }
    }
  }

  /// 处理推送通知点击
  void _handlePushNotificationOpened(Map<String, dynamic> notification) {
    final orderId = notification['order_id'] as int?;
    if (orderId != null && mounted) {
      context.router.push(OrderDetailRoute(orderId: orderId.toString()));
    }
  }

  /// Tab 切换回调
  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    final tab = _tabs[_tabController.index]['tab'] as OrderTab;
    ref.read(categorizedOrderListProvider.notifier).switchTab(tab);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadOrders();
    }
  }

  void _startStatusSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      _loadOrders();
    });
  }

  void _startCountdownTick() {
    _countdownTickTimer?.cancel();
    _countdownTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  /// 加载订单
  void _loadOrders() {
    ref.read(categorizedOrderListProvider.notifier).loadOrders(refresh: true);
  }

  /// 下拉刷新
  Future<void> _onRefresh() async {
    await ref.read(categorizedOrderListProvider.notifier).refresh();
    _refreshControllers[_tabController.index].refreshCompleted();
  }

  /// 上拉加载更多
  Future<void> _onLoading() async {
    await ref.read(categorizedOrderListProvider.notifier).loadMore();
    final state = ref.read(categorizedOrderListProvider);
    if (state.hasMore) {
      _refreshControllers[_tabController.index].loadComplete();
    } else {
      _refreshControllers[_tabController.index].loadNoData();
    }
  }

  /// 拨打电话
  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(categorizedOrderListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的订单'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '筛选',
            onPressed: _openFilterSheet,
            icon: const Icon(Icons.filter_alt_outlined),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTopSummary(orderState),
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
            child: Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                tabs: _tabs
                    .map((t) => Tab(text: t['label'] as String))
                    .toList(),
                indicator: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Theme.of(context).primaryColor,
                unselectedLabelColor: AppTheme.textSecondaryColor,
                labelStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _tabs.asMap().entries.map((entry) {
                final index = entry.key;
                final tab = entry.value['tab'] as OrderTab;
                return _buildOrderList(
                  orderState,
                  tab,
                  _refreshControllers[index],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(
    CategorizedOrderListState state,
    OrderTab tab,
    RefreshController refreshController,
  ) {
    // 过滤当前 Tab 的订单
    final orders = _applyFilters(
      state.orders.where((order) {
        final statusList = _getStatusListForTab(tab);
        return statusList.contains(order.status);
      }).toList(),
    );

    if (state.isLoading && orders.isEmpty) {
      return AppListSkeleton(
        itemCount: 5,
        itemHeight: 142,
        padding: EdgeInsets.all(16.w),
      );
    }

    if (state.error != null && orders.isEmpty) {
      return _buildErrorView(state.error!);
    }

    if (orders.isEmpty) {
      return _buildEmptyView(tab);
    }

    return SmartRefresher(
      controller: refreshController,
      enablePullDown: true,
      enablePullUp: true,
      header: const WaterDropHeader(),
      footer: ClassicFooter(
        loadingText: '加载中...',
        noDataText: '没有更多订单了',
        idleText: '上拉加载更多',
        failedText: '加载失败，点击重试',
        canLoadingText: '松开加载更多',
      ),
      onRefresh: _onRefresh,
      onLoading: _onLoading,
      child: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  List<int> _getStatusListForTab(OrderTab tab) {
    switch (tab) {
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

  int _countByStatuses(CategorizedOrderListState state, List<int> statuses) {
    return state.orders.where((o) => statuses.contains(o.status)).length;
  }

  Widget _buildTopSummary(CategorizedOrderListState state) {
    final toPayCount = _countByStatuses(state, [0]);
    final pendingCount = _countByStatuses(state, [1, 2]);
    final progressCount = _countByStatuses(state, [3, 4]);
    final completedCount = _countByStatuses(state, [5, 6, 7]);

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.26),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildSummaryItem('待支付', toPayCount),
          _buildSummaryDivider(),
          _buildSummaryItem('待服务', pendingCount),
          _buildSummaryDivider(),
          _buildSummaryItem('进行中', progressCount),
          _buildSummaryDivider(),
          _buildSummaryItem('已完成/售后', completedCount),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22.sp,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDivider() {
    return Container(
      width: 1,
      height: 26.h,
      color: Colors.white.withValues(alpha: 0.28),
      margin: EdgeInsets.symmetric(horizontal: 4.w),
    );
  }

  Widget _buildEmptyView(OrderTab tab) {
    String message;
    IconData icon;

    switch (tab) {
      case OrderTab.toPay:
        message = '暂无待支付订单';
        icon = Icons.account_balance_wallet_outlined;
        break;
      case OrderTab.pending:
        message = '暂无待服务订单';
        icon = Icons.schedule;
        break;
      case OrderTab.inProgress:
        message = '暂无进行中订单';
        icon = Icons.play_circle_outline;
        break;
      case OrderTab.completed:
        message = '暂无已完成订单';
        icon = Icons.check_circle_outline;
        break;
    }

    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 24.w),
        padding: EdgeInsets.fromLTRB(20.w, 26.h, 20.w, 20.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72.sp, color: Colors.grey.shade300),
            SizedBox(height: 14.h),
            Text(
              message,
              style: TextStyle(
                fontSize: 16.sp,
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '下单后可在这里查看进度与服务记录',
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            SizedBox(height: 18.h),
            ElevatedButton.icon(
              onPressed: () => context.router.pushNamed('/user-home/services'),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('去预约服务'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return AppRetryGuide(
      title: '订单加载失败',
      message: error,
      onRetry: _loadOrders,
      retryText: '重新加载',
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final orderStatus = order.orderStatus;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: () =>
            context.router.push(OrderDetailRoute(orderId: order.id.toString())),
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 14.sp,
                    color: AppTheme.textHintColor,
                  ),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      order.orderNo,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.textSecondaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Color(
                        orderStatus.colorValue,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      order.displayStatusText,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Color(orderStatus.colorValue),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Container(
                    width: 52.w,
                    height: 52.w,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.medical_services_rounded,
                      size: 26.sp,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.serviceName,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '预约：${_formatAppointmentTime(order.appointmentTime)}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '¥${order.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16.sp,
                      color: AppTheme.textSecondaryColor,
                    ),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        order.address,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.textSecondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (order.orderStatus == OrderStatus.pendingPayment)
                Padding(
                  padding: EdgeInsets.only(top: 8.h),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14.sp,
                        color: order.remainingPayMinutes <= 5
                            ? Colors.redAccent
                            : Colors.orange,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        order.isPaymentExpired
                            ? '支付保留已超时，请重新下单'
                            : '订单保留中：剩余约${order.remainingPayMinutes}分钟',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: order.remainingPayMinutes <= 5
                              ? Colors.redAccent
                              : AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (order.nurseName != null) ...[
                SizedBox(height: 10.h),
                _buildNurseInfo(order),
              ],
              SizedBox(height: 10.h),
              _buildActionButtons(order),
            ],
          ),
        ),
      ),
    );
  }

  String _formatAppointmentTime(String time) {
    try {
      final dateTime = DateTime.parse(time);
      return DateFormat('MM-dd HH:mm').format(dateTime);
    } catch (e) {
      return time;
    }
  }

  Widget _buildNurseInfo(OrderModel order) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          // 护士头像
          CircleAvatar(
            radius: 20.r,
            backgroundColor: Colors.blue.withValues(alpha: 0.2),
            child: Icon(Icons.person, size: 24.sp, color: Colors.blue),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.nurseName!,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (order.nurseRating != null) ...[
                      SizedBox(width: 8.w),
                      Icon(Icons.star, size: 14.sp, color: Colors.amber),
                      SizedBox(width: 2.w),
                      Text(
                        order.nurseRating!.toStringAsFixed(1),
                        style: TextStyle(fontSize: 12.sp, color: Colors.orange),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  '护士',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          // 电话按钮
          if (order.nursePhone != null)
            IconButton(
              onPressed: () => _makePhoneCall(order.nursePhone!),
              icon: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Icon(Icons.phone, size: 20.sp, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(OrderModel order) {
    final orderStatus = order.orderStatus;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 根据订单状态显示不同按钮
        if (orderStatus == OrderStatus.pendingPayment) ...[
          OutlinedButton(
            onPressed: () {
              // 取消订单
              _showCancelConfirmDialog(order);
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            ),
            child: Text(
              '取消订单',
              style: TextStyle(color: Colors.grey, fontSize: 13.sp),
            ),
          ),
          SizedBox(width: 12.w),
          ElevatedButton(
            onPressed: order.isPaymentExpired
                ? null
                : () {
                    context.router.push(PaymentRoute(orderId: order.id));
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            ),
            child: Text(
              '去支付',
              style: TextStyle(color: Colors.white, fontSize: 13.sp),
            ),
          ),
        ],
        if (orderStatus == OrderStatus.pendingEvaluation)
          ElevatedButton(
            onPressed: () {
              context.router.push(
                OrderDetailRoute(orderId: order.id.toString()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            ),
            child: Text(
              '去评价',
              style: TextStyle(color: Colors.white, fontSize: 13.sp),
            ),
          ),
        if (orderStatus == OrderStatus.completed)
          OutlinedButton(
            onPressed: () {
              context.router.push(
                OrderDetailRoute(orderId: order.id.toString()),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            ),
            child: Text('查看详情', style: TextStyle(fontSize: 13.sp)),
          ),
        if (orderStatus == OrderStatus.pendingAccept ||
            orderStatus == OrderStatus.accepted)
          OutlinedButton(
            onPressed: () {
              context.router.push(
                OrderDetailRoute(orderId: order.id.toString()),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            ),
            child: Text('查看详情', style: TextStyle(fontSize: 13.sp)),
          ),
        if (orderStatus == OrderStatus.arrived ||
            orderStatus == OrderStatus.inService)
          ElevatedButton(
            onPressed: () {
              context.router.push(
                OrderDetailRoute(orderId: order.id.toString()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            ),
            child: Text(
              '查看进度',
              style: TextStyle(color: Colors.white, fontSize: 13.sp),
            ),
          ),
      ],
    );
  }

  void _showCancelConfirmDialog(OrderModel order) {
    final rootContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('取消订单'),
        content: const Text('确定要取消该订单吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('再想想'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              // 执行取消订单
              final success = await ref
                  .read(orderOperationProvider.notifier)
                  .cancelOrder(order.id, '用户主动取消');

              if (!mounted) return;
              if (!rootContext.mounted) return;
              if (success) {
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(
                    content: Text('订单已取消'),
                    backgroundColor: Colors.green,
                  ),
                );
                // 刷新订单列表
                ref.read(categorizedOrderListProvider.notifier).refresh();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认取消', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
