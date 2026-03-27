import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/commercial_ui_widgets.dart';
import '../../data/models/service_model.dart';
import '../../providers/service_provider.dart';

/// 服务列表页面
///
/// 展示护理服务项目列表（至少6项：静脉采血、留置导尿、压疮换药、肌肉注射、血糖监测、产后通乳）
/// 支持分类筛选：基础护理、产后护理等
/// 使用 ListView 展示服务卡片
@RoutePage()
class ServiceListPage extends ConsumerStatefulWidget {
  const ServiceListPage({super.key});

  @override
  ConsumerState<ServiceListPage> createState() => _ServiceListPageState();
}

class _ServiceListPageState extends ConsumerState<ServiceListPage> {
  final RefreshController _refreshController = RefreshController();

  /// 本地服务数据（用于离线或API未返回时的备用数据）
  final List<ServiceModel> _defaultServices = [
    ServiceModel(
      id: 1,
      name: '静脉采血',
      price: 50.0,
      description: '专业护士上门采血，需自备采血管或备注说明',
      category: '基础护理',
      status: 1,
    ),
    ServiceModel(
      id: 2,
      name: '留置导尿',
      price: 120.0,
      description: '包含导尿管更换及尿道口护理',
      category: '基础护理',
      status: 1,
    ),
    ServiceModel(
      id: 3,
      name: '压疮换药',
      price: 80.0,
      description: '针对I-III期压疮进行清洗换药',
      category: '基础护理',
      status: 1,
    ),
    ServiceModel(
      id: 4,
      name: '肌肉注射',
      price: 45.0,
      description: '皮下/肌肉注射，需提供正规医嘱',
      category: '基础护理',
      status: 1,
    ),
    ServiceModel(
      id: 5,
      name: '血糖监测',
      price: 30.0,
      description: '快速指尖血糖检测',
      category: '基础护理',
      status: 1,
    ),
    ServiceModel(
      id: 6,
      name: '产后通乳',
      price: 200.0,
      description: '专业手法疏通，缓解涨奶疼痛',
      category: '产后护理',
      status: 1,
    ),
    ServiceModel(
      id: 7,
      name: '新生儿护理',
      price: 180.0,
      description: '新生儿脐带护理、沐浴、抚触等专业护理',
      category: '产后护理',
      status: 1,
    ),
    ServiceModel(
      id: 8,
      name: '伤口换药',
      price: 60.0,
      description: '普通伤口清创换药，促进愈合',
      category: '基础护理',
      status: 1,
    ),
  ];

  final List<String> _fallbackCategories = ['全部', '基础护理', '产后护理'];

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  /// 根据分类筛选服务
  List<ServiceModel> _filterServices(
    List<ServiceModel> services,
    String category,
  ) {
    if (category == '全部') {
      return services.where((s) => s.isAvailable).toList();
    }
    return services
        .where((s) => s.category == category && s.isAvailable)
        .toList();
  }

  /// 获取服务图标
  IconData _getServiceIcon(String? name) {
    switch (name) {
      case '静脉采血':
        return Icons.bloodtype;
      case '留置导尿':
        return Icons.medical_services;
      case '压疮换药':
        return Icons.healing;
      case '肌肉注射':
        return Icons.vaccines;
      case '血糖监测':
        return Icons.monitor_heart;
      case '产后通乳':
        return Icons.child_friendly;
      case '新生儿护理':
        return Icons.baby_changing_station;
      case '伤口换药':
        return Icons.local_hospital;
      default:
        return Icons.medical_services;
    }
  }

  /// 获取分类颜色
  Color _getCategoryColor(String? category) {
    switch (category) {
      case '基础护理':
        return Colors.blue;
      case '产后护理':
        return Colors.pink;
      default:
        return Colors.orange;
    }
  }

  /// 下拉刷新
  void _onRefresh() async {
    // 刷新服务列表
    ref.invalidate(serviceListProvider);
    ref.invalidate(serviceCategoriesProvider);
    await Future.delayed(const Duration(milliseconds: 500));
    _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final categoriesAsync = ref.watch(serviceCategoriesProvider);
    final servicesAsync = ref.watch(serviceListProvider(selectedCategory));
    final categories = categoriesAsync.valueOrNull?.isNotEmpty == true
        ? categoriesAsync.valueOrNull!
        : _fallbackCategories;
    final baseServices = servicesAsync.valueOrNull?.isNotEmpty == true
        ? servicesAsync.valueOrNull!
        : _defaultServices;
    final searchableServices = _filterServices(baseServices, '全部');
    final effectiveCategory = categories.contains(selectedCategory)
        ? selectedCategory
        : '全部';

    return Scaffold(
      appBar: AppBar(
        title: const Text('护理服务'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(searchableServices),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          servicesAsync.when(
            data: (services) {
              final list = _filterServices(
                services.isNotEmpty ? services : _defaultServices,
                effectiveCategory,
              );
              return _buildTopBanner(list, effectiveCategory, categories);
            },
            loading: () => _buildTopBanner(
              _filterServices(_defaultServices, effectiveCategory),
              effectiveCategory,
              categories,
            ),
            error: (error, stackTrace) => _buildTopBanner(
              _filterServices(_defaultServices, effectiveCategory),
              effectiveCategory,
              categories,
            ),
          ),

          // 分类筛选标签
          _buildCategoryTabs(categories),

          // 服务列表
          Expanded(
            child: servicesAsync.when(
              data: (services) {
                final filteredServices = _filterServices(
                  services.isNotEmpty ? services : _defaultServices,
                  effectiveCategory,
                );
                return _buildServiceList(filteredServices);
              },
              loading: () => AppListSkeleton(
                itemCount: 6,
                itemHeight: 132,
                padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
              ),
              error: (error, stack) => AppRetryGuide(
                title: '服务加载失败',
                message: '网络波动或服务暂不可用，请稍后重试。',
                onRetry: _onRefresh,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBanner(
    List<ServiceModel> services,
    String selectedCategory,
    List<String> categories,
  ) {
    final count = services.length;
    final minPrice = _getMinPrice(services);

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.84),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedCategory == '全部' ? '精选上门护理服务' : '$selectedCategory 服务',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '专业护士上门，流程可追踪，服务更安心',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildTopMetric('服务数', '$count'),
              SizedBox(height: 4.h),
              _buildTopMetric('低至', '¥${minPrice.toStringAsFixed(0)}'),
              SizedBox(height: 4.h),
              _buildTopMetric('分类', '${(categories.length - 1).clamp(0, 99)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopMetric(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.85)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  double _getMinPrice(List<ServiceModel> services) {
    if (services.isEmpty) return 0;
    var minPrice = services.first.price;
    for (final service in services.skip(1)) {
      if (service.price < minPrice) {
        minPrice = service.price;
      }
    }
    return minPrice;
  }

  /// 构建分类标签栏
  Widget _buildCategoryTabs(List<String> categories) {
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Container(
      height: 54.h,
      margin: EdgeInsets.only(bottom: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;

          return GestureDetector(
            onTap: () {
              ref.read(selectedCategoryProvider.notifier).state = category;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: 12.w),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(999.r),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Center(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimaryColor,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 构建服务列表
  Widget _buildServiceList(List<ServiceModel> services) {
    if (services.isEmpty) {
      return Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 28.w),
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 18.h),
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
              Icon(
                Icons.medical_services_outlined,
                size: 60.sp,
                color: Colors.grey.shade300,
              ),
              SizedBox(height: 12.h),
              Text(
                '暂无可用服务',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                '可切换分类或稍后再试',
                style: TextStyle(fontSize: 13.sp, color: AppTheme.textHintColor),
              ),
            ],
          ),
        ),
      );
    }

    return SmartRefresher(
      controller: _refreshController,
      onRefresh: _onRefresh,
      header: const WaterDropHeader(),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
        itemCount: services.length,
        itemBuilder: (context, index) {
          final service = services[index];
          return _buildServiceCard(service);
        },
      ),
    );
  }

  /// 构建服务卡片
  Widget _buildServiceCard(ServiceModel service) {
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
        onTap: () => context.router.push(ServiceOrderRoute(serviceId: service.id)),
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildServiceLeading(service),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                service.name,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimaryColor,
                                ),
                              ),
                            ),
                            _buildCategoryBadge(service.category),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          service.description?.isNotEmpty == true
                              ? service.description!
                              : '专业护士上门服务，流程规范，安全放心',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppTheme.textSecondaryColor,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 6.w,
                          runSpacing: 6.h,
                          children: [
                            _buildMetaPill(
                              icon: Icons.schedule_outlined,
                              text: '约${_estimateDurationMinute(service)}分钟',
                            ),
                            _buildMetaPill(
                              icon: Icons.local_fire_department_outlined,
                              text: '月服务${_estimateMonthlyCount(service)}次',
                            ),
                            _buildMetaPill(
                              icon: Icons.star_outline_rounded,
                              text: '满意度${_estimateSatisfaction(service)}%',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '¥',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: service.price.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 22.sp,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: '/次',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.textHintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.flash_on_rounded, size: 14.sp, color: Colors.white),
                        SizedBox(width: 2.w),
                        Text(
                          '立即预约',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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

  Widget _buildServiceLeading(ServiceModel service) {
    final color = _getCategoryColor(service.category);
    final iconUrl = service.iconUrl?.trim() ?? '';

    if (iconUrl.isNotEmpty && iconUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Image.network(
          iconUrl,
          width: 70.w,
          height: 70.w,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackIcon(color, service.name),
        ),
      );
    }

    return _buildFallbackIcon(color, service.name);
  }

  Widget _buildFallbackIcon(Color color, String name) {
    return Container(
      width: 70.w,
      height: 70.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.26),
            color.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Icon(_getServiceIcon(name), size: 34.sp, color: color),
    );
  }

  Widget _buildCategoryBadge(String? category) {
    final color = _getCategoryColor(category);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        category ?? '其他',
        style: TextStyle(
          fontSize: 10.sp,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMetaPill({required IconData icon, required String text}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: AppTheme.textSecondaryColor),
          SizedBox(width: 3.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.sp,
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  int _estimateDurationMinute(ServiceModel service) {
    final map = <String, int>{
      '静脉采血': 30,
      '留置导尿': 45,
      '压疮换药': 40,
      '肌肉注射': 25,
      '血糖监测': 20,
      '产后通乳': 60,
      '新生儿护理': 80,
      '伤口换药': 35,
    };
    return map[service.name] ?? (30 + service.id % 4 * 10);
  }

  int _estimateMonthlyCount(ServiceModel service) {
    return 80 + (service.id * 17 % 140);
  }

  int _estimateSatisfaction(ServiceModel service) {
    return 95 + (service.id % 4);
  }

  /// 显示搜索对话框
  void _showSearchDialog(List<ServiceModel> services) {
    showSearch(
      context: context,
      delegate: ServiceSearchDelegate(
        services: services,
        onServiceSelected: (service) {
          context.router.push(ServiceOrderRoute(serviceId: service.id));
        },
      ),
    );
  }
}

/// 服务搜索代理
class ServiceSearchDelegate extends SearchDelegate<ServiceModel?> {
  final List<ServiceModel> services;
  final Function(ServiceModel) onServiceSelected;

  ServiceSearchDelegate({
    required this.services,
    required this.onServiceSelected,
  });

  @override
  String get searchFieldLabel => '搜索护理服务';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = services
        .where((s) => s.isAvailable)
        .where(
          (s) =>
              s.name.toLowerCase().contains(query.toLowerCase()) ||
              (s.description?.toLowerCase().contains(query.toLowerCase()) ??
                  false) ||
              (s.category?.toLowerCase().contains(query.toLowerCase()) ??
                  false),
        )
        .toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60.sp, color: Colors.grey.shade300),
            SizedBox(height: 16.h),
            Text(
              '未找到相关服务',
              style: TextStyle(
                fontSize: 16.sp,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final service = results[index];
        return Container(
          margin: EdgeInsets.only(bottom: 10.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            leading: Icon(Icons.medical_services, color: AppTheme.primaryColor),
            title: Text(
              service.name,
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              service.description?.isNotEmpty == true
                  ? service.description!
                  : '专业上门护理服务',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '¥${service.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                  ),
                ),
                Text(
                  service.category ?? '',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
            onTap: () {
              close(context, service);
              onServiceSelected(service);
            },
          ),
        );
      },
    );
  }
}
