import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/location_service.dart';
import '../../../core/utils/error_mapper.dart';
import '../data/models/nurse_profile_model.dart';
import '../data/repositories/nurse_repository.dart';

/// 护士档案状态
class NurseProfileState {
  final NurseProfileModel? profile;
  final bool isLoading;
  final String? error;

  const NurseProfileState({this.profile, this.isLoading = false, this.error});

  NurseProfileState copyWith({
    NurseProfileModel? profile,
    bool? isLoading,
    String? error,
  }) {
    return NurseProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 护士档案状态管理
class NurseProfileNotifier extends StateNotifier<NurseProfileState> {
  final NurseRepository _repository;

  NurseProfileNotifier(this._repository) : super(const NurseProfileState());

  /// 加载护士档案
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final profile = await _repository.getProfile();
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: normalizeErrorMessage(e, fallback: '加载护士资料失败'),
      );
    }
  }

  /// 切换工作模式
  Future<bool> toggleWorkMode(bool workMode) async {
    try {
      final success = await _repository.toggleWorkMode(workMode);
      if (success && state.profile != null) {
        state = state.copyWith(
          profile: state.profile!.copyWith(workModeValue: workMode ? 1 : 0),
        );
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// 上报位置
  Future<bool> reportLocation(double latitude, double longitude) async {
    try {
      final request = LocationReportRequest(
        latitude: latitude,
        longitude: longitude,
      );
      final success = await _repository.reportLocation(request);
      if (success && state.profile != null) {
        state = state.copyWith(
          profile: state.profile!.copyWith(
            locationLat: latitude,
            locationLng: longitude,
          ),
        );
      }
      return success;
    } catch (e) {
      debugPrint('位置上报失败: $e');
      return false;
    }
  }

  /// 更新档案
  void updateProfile(NurseProfileModel profile) {
    state = state.copyWith(profile: profile);
  }
}

/// 护士档案 Provider
final nurseProfileProvider =
    StateNotifierProvider<NurseProfileNotifier, NurseProfileState>((ref) {
      final repository = ref.watch(nurseRepositoryProvider);
      return NurseProfileNotifier(repository);
    });

/// 今日任务列表状态
class NurseTaskListState {
  final List<NurseTaskModel> tasks;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final int? statusFilter;

  const NurseTaskListState({
    this.tasks = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.statusFilter,
  });

  NurseTaskListState copyWith({
    List<NurseTaskModel>? tasks,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    Object? statusFilter = _noValue,
  }) {
    return NurseTaskListState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      statusFilter: identical(statusFilter, _noValue)
          ? this.statusFilter
          : statusFilter as int?,
    );
  }
}

const Object _noValue = Object();

/// 今日任务列表状态管理
class NurseTaskListNotifier extends StateNotifier<NurseTaskListState> {
  final NurseRepository _repository;

  NurseTaskListNotifier(this._repository) : super(const NurseTaskListState());

  /// 加载今日任务
  Future<void> loadTodayTasks({int? status}) async {
    state = state.copyWith(isLoading: true, error: null, statusFilter: status);

    try {
      final tasks = await _repository.getTodayTasks(status: status);
      state = state.copyWith(tasks: tasks, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: normalizeErrorMessage(e, fallback: '加载任务失败'),
      );
    }
  }

  /// 刷新任务列表
  Future<void> refresh({int? status}) async {
    state = state.copyWith(isRefreshing: true);

    try {
      final targetStatus = status ?? state.statusFilter;
      final tasks = await _repository.getTodayTasks(status: targetStatus);
      state = state.copyWith(tasks: tasks, isRefreshing: false);
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: normalizeErrorMessage(e, fallback: '刷新任务失败'),
      );
    }
  }

  /// 更新任务状态
  Future<bool> updateTaskStatus(
    int orderId,
    int newStatus, {
    String? photo,
    File? photoFile,
  }) async {
    try {
      final success = await _repository.updateTaskStatus(
        orderId,
        newStatus,
        photoFile: photoFile,
      );

      if (success) {
        // 更新本地状态
        final updatedTasks = state.tasks.map((task) {
          if (task.id == orderId) {
            return task.copyWith(
              status: newStatus,
              // 使用本地占位：此处不强依赖后端返回的照片URL
              arrivalPhoto: newStatus == 3
                  ? (photo ?? task.arrivalPhoto)
                  : task.arrivalPhoto,
              startPhoto: newStatus == 4
                  ? (photo ?? task.startPhoto)
                  : task.startPhoto,
              finishPhoto: newStatus == 5
                  ? (photo ?? task.finishPhoto)
                  : task.finishPhoto,
            );
          }
          return task;
        }).toList();

        state = state.copyWith(tasks: updatedTasks);
      }

      return success;
    } catch (e) {
      debugPrint('更新任务状态失败: $e');
      return false;
    }
  }

  /// 接单（待接单 -> 待服务）
  Future<bool> acceptOrder(int orderId) async {
    try {
      final success = await _repository.acceptOrder(orderId);
      if (!success) return false;

      // 本地先行更新，随后刷新列表与服务端对齐
      final updatedTasks = state.tasks.map((task) {
        if (task.id == orderId) {
          return task.copyWith(status: 2);
        }
        return task;
      }).toList();
      state = state.copyWith(tasks: updatedTasks);

      // 刷新一遍，确保状态与服务端一致
      await refresh();
      return true;
    } catch (e) {
      debugPrint('接单失败: $e');
      return false;
    }
  }

  /// 拒单（已派单 -> 待接单）
  Future<bool> rejectOrder(int orderId) async {
    try {
      final success = await _repository.rejectOrder(orderId);
      if (!success) return false;

      final updatedTasks = state.tasks
          .where((task) => task.id != orderId)
          .toList();
      state = state.copyWith(tasks: updatedTasks);
      await refresh();
      return true;
    } catch (e) {
      debugPrint('拒单失败: $e');
      return false;
    }
  }

  /// 上传照片并更新状态
  Future<bool> uploadPhotoAndUpdateStatus(
    int orderId,
    int newStatus,
    File photoFile,
  ) async {
    try {
      // 直接走后端 /nurse/orders/{id}/arrival|start|finish 的 multipart 上传
      return await updateTaskStatus(orderId, newStatus, photoFile: photoFile);
    } catch (e) {
      debugPrint('上传照片失败: $e');
      return false;
    }
  }
}

/// 今日任务列表 Provider
final nurseTaskListProvider =
    StateNotifierProvider<NurseTaskListNotifier, NurseTaskListState>((ref) {
      final repository = ref.watch(nurseRepositoryProvider);
      return NurseTaskListNotifier(repository);
    });

/// 位置上报服务状态
class LocationReportState {
  final bool isReporting;
  final DateTime? lastReportTime;
  final LocationInfo? lastLocation;

  const LocationReportState({
    this.isReporting = false,
    this.lastReportTime,
    this.lastLocation,
  });

  LocationReportState copyWith({
    bool? isReporting,
    DateTime? lastReportTime,
    LocationInfo? lastLocation,
  }) {
    return LocationReportState(
      isReporting: isReporting ?? this.isReporting,
      lastReportTime: lastReportTime ?? this.lastReportTime,
      lastLocation: lastLocation ?? this.lastLocation,
    );
  }
}

/// 位置上报服务
///
/// 定时上报护士位置（每10分钟）
class LocationReportNotifier extends StateNotifier<LocationReportState> {
  final NurseRepository _repository;
  Timer? _reportTimer;
  static const Duration _reportInterval = Duration(minutes: 10);

  LocationReportNotifier(this._repository) : super(const LocationReportState());

  /// 开始位置上报
  Future<void> startReporting() async {
    if (state.isReporting) return;

    state = state.copyWith(isReporting: true);

    // 立即上报一次
    await _reportLocation();

    // 启动定时器
    _reportTimer?.cancel();
    _reportTimer = Timer.periodic(_reportInterval, (_) {
      _reportLocation();
    });

    debugPrint('LocationReport: 开始位置上报，间隔 ${_reportInterval.inMinutes} 分钟');
  }

  /// 停止位置上报
  void stopReporting() {
    _reportTimer?.cancel();
    _reportTimer = null;
    state = state.copyWith(isReporting: false);
    debugPrint('LocationReport: 停止位置上报');
  }

  /// 执行一次位置上报
  Future<void> _reportLocation() async {
    try {
      // 获取当前位置
      final locationService = LocationService.instance;
      final hasPermission = await locationService.requestPermission();

      if (!hasPermission) {
        debugPrint('LocationReport: 无定位权限');
        return;
      }

      final location = await locationService.getCurrentLocation();

      if (location != null && location.isSuccess) {
        // 上报到服务器
        final request = LocationReportRequest(
          latitude: location.latitude,
          longitude: location.longitude,
        );

        await _repository.reportLocation(request);

        state = state.copyWith(
          lastReportTime: DateTime.now(),
          lastLocation: location,
        );

        debugPrint(
          'LocationReport: 位置上报成功 - (${location.latitude}, ${location.longitude})',
        );
      }
    } catch (e) {
      debugPrint('LocationReport: 位置上报失败 - $e');
    }
  }

  /// 手动触发一次上报
  Future<void> reportNow() async {
    await _reportLocation();
  }

  @override
  void dispose() {
    _reportTimer?.cancel();
    super.dispose();
  }
}

/// 位置上报 Provider
final locationReportProvider =
    StateNotifierProvider<LocationReportNotifier, LocationReportState>((ref) {
      final repository = ref.watch(nurseRepositoryProvider);
      return LocationReportNotifier(repository);
    });

/// 护士注册状态
class NurseRegisterState {
  final bool isSubmitting;
  final bool isSuccess;
  final String? error;

  // 表单数据
  final String? realName;
  final String? idCardNo;
  final String? licenseNo;
  final String? hospital;
  final int? workYears;
  final String? skillDesc;
  final String? idCardPhotoFront;
  final String? idCardPhotoBack;
  final String? certificatePhoto;
  final String? nursePhoto;

  const NurseRegisterState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.error,
    this.realName,
    this.idCardNo,
    this.licenseNo,
    this.hospital,
    this.workYears,
    this.skillDesc,
    this.idCardPhotoFront,
    this.idCardPhotoBack,
    this.certificatePhoto,
    this.nursePhoto,
  });

  NurseRegisterState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    String? error,
    String? realName,
    String? idCardNo,
    String? licenseNo,
    String? hospital,
    int? workYears,
    String? skillDesc,
    String? idCardPhotoFront,
    String? idCardPhotoBack,
    String? certificatePhoto,
    String? nursePhoto,
  }) {
    return NurseRegisterState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      error: error,
      realName: realName ?? this.realName,
      idCardNo: idCardNo ?? this.idCardNo,
      licenseNo: licenseNo ?? this.licenseNo,
      hospital: hospital ?? this.hospital,
      workYears: workYears ?? this.workYears,
      skillDesc: skillDesc ?? this.skillDesc,
      idCardPhotoFront: idCardPhotoFront ?? this.idCardPhotoFront,
      idCardPhotoBack: idCardPhotoBack ?? this.idCardPhotoBack,
      certificatePhoto: certificatePhoto ?? this.certificatePhoto,
      nursePhoto: nursePhoto ?? this.nursePhoto,
    );
  }

  /// 是否所有必填项都已填写
  bool get isFormValid =>
      realName != null &&
      realName!.isNotEmpty &&
      idCardNo != null &&
      idCardNo!.isNotEmpty &&
      licenseNo != null &&
      licenseNo!.isNotEmpty &&
      hospital != null &&
      hospital!.isNotEmpty &&
      workYears != null &&
      idCardPhotoFront != null &&
      idCardPhotoBack != null &&
      certificatePhoto != null &&
      nursePhoto != null;
}

/// 护士注册状态管理
class NurseRegisterNotifier extends StateNotifier<NurseRegisterState> {
  final NurseRepository _repository;

  NurseRegisterNotifier(this._repository) : super(const NurseRegisterState());

  /// 更新表单字段
  void updateField({
    String? realName,
    String? idCardNo,
    String? licenseNo,
    String? hospital,
    int? workYears,
    String? skillDesc,
  }) {
    state = state.copyWith(
      realName: realName,
      idCardNo: idCardNo,
      licenseNo: licenseNo,
      hospital: hospital,
      workYears: workYears,
      skillDesc: skillDesc,
    );
  }

  /// 上传照片
  Future<String?> uploadPhoto(File file, String type) async {
    try {
      state = state.copyWith(error: null);
      final url = await _repository.uploadImage(file, type);

      // 更新对应字段
      switch (type) {
        case 'id_card_front':
          state = state.copyWith(idCardPhotoFront: url);
          break;
        case 'id_card_back':
          state = state.copyWith(idCardPhotoBack: url);
          break;
        case 'certificate':
          state = state.copyWith(certificatePhoto: url);
          break;
        case 'nurse_photo':
          state = state.copyWith(nursePhoto: url);
          break;
      }

      return url;
    } catch (e) {
      state = state.copyWith(
        error: normalizeErrorMessage(e, fallback: '图片上传失败，请稍后重试'),
      );
      return null;
    }
  }

  /// 设置照片URL（本地路径或已上传URL）
  void setPhoto(String type, String path) {
    switch (type) {
      case 'id_card_front':
        state = state.copyWith(idCardPhotoFront: path);
        break;
      case 'id_card_back':
        state = state.copyWith(idCardPhotoBack: path);
        break;
      case 'certificate':
        state = state.copyWith(certificatePhoto: path);
        break;
      case 'nurse_photo':
        state = state.copyWith(nursePhoto: path);
        break;
    }
  }

  /// 提交注册申请
  Future<bool> submit() async {
    if (!state.isFormValid) {
      state = state.copyWith(error: '请填写完整信息');
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final request = NurseRegisterRequest(
        realName: state.realName!,
        idCardNo: state.idCardNo!,
        licenseNo: state.licenseNo!,
        hospital: state.hospital!,
        workYears: state.workYears!,
        skillDesc: state.skillDesc ?? '',
        idCardPhotoFront: state.idCardPhotoFront!,
        idCardPhotoBack: state.idCardPhotoBack!,
        certificatePhoto: state.certificatePhoto!,
        nursePhoto: state.nursePhoto!,
      );

      final success = await _repository.submitRegistration(request);

      state = state.copyWith(
        isSubmitting: false,
        isSuccess: success,
        error: success ? null : '提交失败，请稍后重试',
      );

      return success;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: normalizeErrorMessage(e, fallback: '提交失败，请稍后重试'),
      );
      return false;
    }
  }

  /// 重置状态
  void reset() {
    state = const NurseRegisterState();
  }
}

/// 护士注册 Provider
final nurseRegisterProvider =
    StateNotifierProvider<NurseRegisterNotifier, NurseRegisterState>((ref) {
      final repository = ref.watch(nurseRepositoryProvider);
      return NurseRegisterNotifier(repository);
    });

// =============== 收入相关 Provider ===============

/// 收入页面状态
class IncomeState {
  final NurseProfileModel? profile;
  final PlatformConfigModel? config;
  final IncomeStatisticsModel? statistics;
  final List<WalletLogModel> walletLogs;
  final List<WithdrawModel> withdrawals;
  final bool isLoadingWithdrawals;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final String? error;

  const IncomeState({
    this.profile,
    this.config,
    this.statistics,
    this.walletLogs = const [],
    this.withdrawals = const [],
    this.isLoadingWithdrawals = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
  });

  IncomeState copyWith({
    NurseProfileModel? profile,
    PlatformConfigModel? config,
    IncomeStatisticsModel? statistics,
    List<WalletLogModel>? walletLogs,
    List<WithdrawModel>? withdrawals,
    bool? isLoadingWithdrawals,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return IncomeState(
      profile: profile ?? this.profile,
      config: config ?? this.config,
      statistics: statistics ?? this.statistics,
      walletLogs: walletLogs ?? this.walletLogs,
      withdrawals: withdrawals ?? this.withdrawals,
      isLoadingWithdrawals: isLoadingWithdrawals ?? this.isLoadingWithdrawals,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }

  /// 可提现余额
  double get availableBalance => profile?.balance ?? 0.0;

  /// 平台费率百分比
  String get feeRateText => config?.feeRateText ?? '20%';

  /// 平台费率
  double get feeRate => config?.platformFeeRate ?? 0.20;

  /// 最低提现金额
  double get minWithdrawAmount => config?.minWithdrawAmount ?? 10.0;
}

/// 收入状态管理
class IncomeNotifier extends StateNotifier<IncomeState> {
  final NurseRepository _repository;

  IncomeNotifier(this._repository) : super(const IncomeState());

  /// 初始化加载
  Future<void> init() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 并行加载所有数据
      final results = await Future.wait([
        _repository.getProfile(),
        _repository.getPlatformConfig(),
        _repository.getIncomeStatistics(),
        _repository.getWalletLogs(page: 1),
      ]);

      state = state.copyWith(
        profile: results[0] as NurseProfileModel,
        config: results[1] as PlatformConfigModel,
        statistics: results[2] as IncomeStatisticsModel,
        walletLogs: results[3] as List<WalletLogModel>,
        isLoading: false,
        currentPage: 1,
        hasMore: (results[3] as List<WalletLogModel>).length >= 20,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: normalizeErrorMessage(e, fallback: '加载收入数据失败'),
      );
    }
  }

  /// 刷新数据
  Future<void> refresh() async {
    await init();
  }

  /// 加载更多流水记录
  Future<void> loadMoreLogs() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final nextPage = state.currentPage + 1;
      final logs = await _repository.getWalletLogs(page: nextPage);

      state = state.copyWith(
        walletLogs: [...state.walletLogs, ...logs],
        isLoadingMore: false,
        currentPage: nextPage,
        hasMore: logs.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// 申请提现
  Future<WithdrawResponse> requestWithdraw({
    required double amount,
    required String alipayAccount,
    required String realName,
  }) async {
    // 验证
    if (amount <= 0) {
      return WithdrawResponse(success: false, message: '请输入有效的提现金额');
    }
    if (amount > state.availableBalance) {
      return WithdrawResponse(success: false, message: '提现金额不能超过可用余额');
    }
    if (amount < state.minWithdrawAmount) {
      return WithdrawResponse(
        success: false,
        message: '最低提现金额为¥${state.minWithdrawAmount.toStringAsFixed(2)}',
      );
    }
    if (alipayAccount.isEmpty) {
      return WithdrawResponse(success: false, message: '请输入支付宝账号');
    }
    if (realName.isEmpty) {
      return WithdrawResponse(success: false, message: '请输入真实姓名');
    }

    try {
      final request = WithdrawRequest(
        amount: amount,
        alipayAccount: alipayAccount,
        realName: realName,
      );

      final response = await _repository.requestWithdraw(request);

      if (response.success) {
        // 刷新余额和流水
        await refresh();
      }

      return response;
    } catch (e) {
      return WithdrawResponse(
        success: false,
        message: normalizeErrorMessage(e, fallback: '提现申请失败'),
      );
    }
  }

  /// 加载提现记录
  Future<void> loadWithdrawals() async {
    state = state.copyWith(isLoadingWithdrawals: true);
    try {
      final withdrawals = await _repository.getWithdrawals();
      state = state.copyWith(
        withdrawals: withdrawals,
        isLoadingWithdrawals: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingWithdrawals: false);
      debugPrint('加载提现记录失败: $e');
    }
  }
}

/// 收入 Provider
final incomeProvider = StateNotifierProvider<IncomeNotifier, IncomeState>((
  ref,
) {
  final repository = ref.watch(nurseRepositoryProvider);
  return IncomeNotifier(repository);
});
