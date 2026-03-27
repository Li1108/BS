import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/http_client.dart';
import '../../../../core/utils/error_mapper.dart';
import '../models/nurse_profile_model.dart';

/// 护士端数据仓库
///
/// 提供护士相关的 API 调用
/// 包括：档案管理、工作模式、位置上报、任务列表、订单状态更新
class NurseRepository {
  final HttpClient _http;
  final Map<int, String> _orderNoCache = {};

  NurseRepository(this._http);

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  DateTime? _parseDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  int _mapBackendOrderStatusToTaskStatus(int backendStatus) {
    switch (backendStatus) {
      case 2:
        return 1; // 已派单 -> 待接单
      case 3:
        return 2; // 已接单 -> 待服务
      case 4:
        return 3; // 已到达
      case 5:
        return 4; // 服务中
      case 6:
      case 7:
        return 6; // 已完成/已评价
      case 8:
      case 9:
      case 10:
        return 7; // 已取消/退款
      default:
        return backendStatus;
    }
  }

  int? _mapTaskStatusToBackendStatus(int? taskStatus) {
    if (taskStatus == null) return null;
    switch (taskStatus) {
      case 1:
        return null;
      case 2:
        return 3;
      case 3:
        return 4;
      case 4:
        return 5;
      case 5:
      case 6:
        return 6;
      case 7:
        return 8;
      default:
        return taskStatus;
    }
  }

  Future<String> _resolveOrderNo(int orderId) async {
    final cached = _orderNoCache[orderId];
    if (cached != null && cached.isNotEmpty) return cached;
    await getAllTasks(page: 1, pageSize: 200);
    final resolved = _orderNoCache[orderId];
    if (resolved == null || resolved.isEmpty) {
      throw Exception('未找到订单号');
    }
    return resolved;
  }

  Map<String, dynamic> _normalizeTask(Map<String, dynamic> raw) {
    final orderStatus =
        _toInt(raw['order_status'] ?? raw['orderStatus'] ?? raw['status']) ?? 0;
    final taskStatus = _mapBackendOrderStatusToTaskStatus(orderStatus);
    final data = <String, dynamic>{
      'id': _toInt(raw['id']) ?? 0,
      'order_no': (raw['order_no'] ?? raw['orderNo'])?.toString() ?? '',
      'user_id': _toInt(raw['user_id']) ?? 0,
      'nurse_id': _toInt(
        raw['nurse_user_id'] ??
            raw['nurse_id'] ??
            raw['nurseUserId'] ??
            raw['nurseId'],
      ),
      'service_id': _toInt(raw['service_id']) ?? 0,
      'service_name':
          raw['service_name']?.toString() ??
          raw['serviceName']?.toString() ??
          raw['service_name_snapshot']?.toString() ??
          '护理服务',
      'service_price':
          _toDouble(raw['service_price']) ??
          _toDouble(raw['servicePrice']) ??
          _toDouble(raw['service_price_snapshot']) ??
          0,
      'total_amount': _toDouble(raw['total_amount']) ?? 0,
      'platform_fee':
          (_toDouble(raw['total_amount']) ?? 0) * 0.2, // 护士80%，平台20%
      'nurse_income': (_toDouble(raw['total_amount']) ?? 0) * 0.8, // 护士收入估算
      'contact_name': raw['contact_name']?.toString() ?? '联系人',
      'contact_phone': raw['contact_phone']?.toString() ?? '',
      'address':
          raw['address']?.toString() ??
          raw['address_snapshot']?.toString() ??
          '',
      'appointment_time':
          raw['appointment_time']?.toString() ??
          raw['appointmentTime']?.toString() ??
          raw['create_time']?.toString() ??
          '',
      'remark': raw['remark']?.toString(),
      'latitude': _toDouble(raw['latitude'] ?? raw['address_latitude']),
      'longitude': _toDouble(raw['longitude'] ?? raw['address_longitude']),
      'status': taskStatus,
      'pay_status': _toInt(raw['pay_status']) ?? 0,
      'arrival_time':
          raw['arrival_time']?.toString() ?? raw['arrive_time']?.toString(),
      'arrival_photo': raw['arrival_photo']?.toString(),
      'start_time':
          raw['start_time']?.toString() ??
          raw['service_start_time']?.toString() ??
          raw['serviceBeginTime']?.toString(),
      'start_photo': raw['start_photo']?.toString(),
      'finish_time':
          raw['finish_time']?.toString() ??
          raw['service_finish_time']?.toString() ??
          raw['serviceEndTime']?.toString(),
      'finish_photo': raw['finish_photo']?.toString(),
      'created_at':
          raw['created_at']?.toString() ?? raw['create_time']?.toString(),
    };
    final orderNo = data['order_no']?.toString();
    final id = _toInt(data['id']);
    if (id != null && orderNo != null && orderNo.isNotEmpty) {
      _orderNoCache[id] = orderNo;
    }
    return data;
  }

  Map<String, dynamic> _normalizeWalletLog(Map<String, dynamic> raw) {
    final amount =
        _toDouble(raw['change_amount']) ?? _toDouble(raw['amount']) ?? 0;
    final type = _toInt(raw['change_type']) ?? _toInt(raw['type']) ?? 1;
    return {
      'id': _toInt(raw['id']) ?? 0,
      'nurse_id': _toInt(raw['nurse_user_id']) ?? 0,
      'amount': amount,
      'type': type,
      'ref_id': raw['order_no']?.toString() ?? raw['ref_id']?.toString(),
      'description':
          raw['remark']?.toString() ?? raw['description']?.toString(),
      'created_at':
          raw['created_at']?.toString() ?? raw['create_time']?.toString(),
    };
  }

  Map<String, dynamic> _normalizeWithdrawal(Map<String, dynamic> raw) {
    final status = _toInt(raw['status']) ?? 0;
    return {
      'id': _toInt(raw['id']) ?? 0,
      'nurse_id': _toInt(raw['nurse_user_id']) ?? 0,
      'amount': _toDouble(raw['withdraw_amount']) ?? 0,
      'alipay_account':
          raw['bank_account']?.toString() ??
          raw['alipay_account']?.toString() ??
          '',
      'real_name':
          raw['account_holder']?.toString() ??
          raw['real_name']?.toString() ??
          '',
      'status': status,
      'reject_reason':
          raw['audit_remark']?.toString() ?? raw['reject_reason']?.toString(),
      'created_at':
          raw['created_at']?.toString() ?? raw['create_time']?.toString(),
      'audit_time': raw['audit_time']?.toString(),
    };
  }

  /// 获取护士档案
  Future<NurseProfileModel> getProfile() async {
    try {
      final responses = await Future.wait([
        _http.get('/nurse/profile'),
        _http.get('/auth/me'),
        _http.get('/wallet/info'),
      ]);

      final profileResult = ApiResponse<Map<String, dynamic>>.fromJson(
        responses[0].data,
        (data) => data as Map<String, dynamic>,
      );
      if (!profileResult.isSuccess || profileResult.data == null) {
        throw Exception(profileResult.message);
      }

      final meResult = ApiResponse<Map<String, dynamic>>.fromJson(
        responses[1].data,
        (data) => data as Map<String, dynamic>,
      );
      final walletResult = ApiResponse<Map<String, dynamic>>.fromJson(
        responses[2].data,
        (data) => data as Map<String, dynamic>,
      );

      Map<String, dynamic>? locationData;
      try {
        final locationResp = await _http.get('/nurse/location/latest');
        final locationResult = ApiResponse<Map<String, dynamic>>.fromJson(
          locationResp.data,
          (data) => data as Map<String, dynamic>,
        );
        locationData = locationResult.data;
      } catch (_) {}

      final profile = profileResult.data!;
      final user = meResult.data ?? const <String, dynamic>{};
      final wallet = walletResult.data ?? const <String, dynamic>{};

      final normalized = <String, dynamic>{
        'user_id':
            _toInt(profile['user_id']) ??
            _toInt(user['user_id']) ??
            _toInt(user['userId']) ??
            _toInt(user['id']) ??
            0,
        'real_name': profile['nurse_name']?.toString() ?? '',
        'id_card_no': profile['id_card_no']?.toString(),
        'id_card_photo_front': profile['id_card_front_url']?.toString(),
        'id_card_photo_back': profile['id_card_back_url']?.toString(),
        'certificate_photo': profile['license_url']?.toString(),
        'audit_status': _toInt(profile['audit_status']) ?? 0,
        'audit_reason': profile['audit_remark']?.toString(),
        'work_mode': _toInt(profile['accept_enabled']) ?? 0,
        'balance': _toDouble(wallet['balance']) ?? 0,
        'rating':
            _toDouble(profile['rating']) ??
            _toDouble(profile['rating_avg']) ??
            5,
        'service_area':
            profile['hospital']?.toString() ??
            profile['skill_desc']?.toString(),
        'location_lat': _toDouble(locationData?['latitude']),
        'location_lng': _toDouble(locationData?['longitude']),
        'avatar':
            user['avatar_url']?.toString() ?? user['avatar']?.toString() ?? '',
        'phone':
            user['phone']?.toString() ??
            profile['phone']?.toString() ??
            profile['mobile']?.toString(),
      };
      return NurseProfileModel.fromJson(normalized);
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '加载护士档案失败'));
    }
  }

  /// 获取护士可编辑的个人资料（护士资料 + 用户资料）
  Future<Map<String, dynamic>> getPersonalProfile() async {
    try {
      final responses = await Future.wait([
        _http.get('/nurse/profile'),
        _http.get('/user/profile'),
      ]);

      final nurseResult = ApiResponse<Map<String, dynamic>>.fromJson(
        responses[0].data,
        (data) => data as Map<String, dynamic>,
      );
      final userResult = ApiResponse<Map<String, dynamic>>.fromJson(
        responses[1].data,
        (data) => data as Map<String, dynamic>,
      );

      if (!nurseResult.isSuccess || nurseResult.data == null) {
        throw Exception(nurseResult.message);
      }
      if (!userResult.isSuccess || userResult.data == null) {
        throw Exception(userResult.message);
      }

      final nurse = nurseResult.data!;
      final user = userResult.data!;
      return {
        'nickname': user['nickname']?.toString() ?? '',
        'avatarUrl': user['avatarUrl']?.toString() ?? '',
        'nurseName': nurse['nurse_name']?.toString() ?? '',
        'hospital': nurse['hospital']?.toString() ?? '',
        'workYears': _toInt(nurse['work_years']) ?? 0,
        'skillDesc': nurse['skill_desc']?.toString() ?? '',
      };
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '获取护士个人资料失败'));
    }
  }

  /// 更新护士个人资料（同步 user + nurse 两张表）
  Future<bool> updatePersonalProfile({
    required String nickname,
    required String avatarUrl,
    required String nurseName,
    required String hospital,
    required int workYears,
    required String skillDesc,
  }) async {
    try {
      final responses = await Future.wait([
        _http.put(
          '/user/profile',
          data: {'nickname': nickname, 'avatarUrl': avatarUrl},
        ),
        _http.put(
          '/nurse/profile',
          data: {
            'nurseName': nurseName,
            'hospital': hospital,
            'workYears': workYears,
            'skillDesc': skillDesc,
          },
        ),
      ]);

      final userResult = ApiResponse.fromJson(responses[0].data, null);
      final nurseResult = ApiResponse.fromJson(responses[1].data, null);
      return userResult.isSuccess && nurseResult.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '更新护士个人资料失败'));
    }
  }

  /// 申请关联医院变更（首次未设置时后端将直接写入）
  Future<bool> applyHospitalChange({
    required String newHospital,
    String? reason,
  }) async {
    try {
      final response = await _http.post(
        '/nurse/hospital/change/apply',
        data: {
          'newHospital': newHospital,
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
        },
      );
      final result = ApiResponse.fromJson(response.data, null);
      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '提交医院变更申请失败'));
    }
  }

  /// 提交护士注册申请
  Future<bool> submitRegistration(NurseRegisterRequest request) async {
    try {
      final response = await _http.post(
        '/nurse/register',
        data: {
          'nurse_name': request.realName,
          'id_card_no': request.idCardNo,
          'license_no': request.licenseNo,
          'hospital': request.hospital,
          'work_years': request.workYears,
          'skill_desc': request.skillDesc,
          'id_card_front_url': request.idCardPhotoFront,
          'id_card_back_url': request.idCardPhotoBack,
          'license_url': request.certificatePhoto,
          'nurse_photo_url': request.nursePhoto,
        },
      );

      final result = ApiResponse.fromJson(response.data, null);

      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '提交注册申请失败'));
    }
  }

  /// 上传图片
  ///
  /// [file] 图片文件
  /// [type] 图片类型：id_card_front, id_card_back, certificate, arrival, start, finish
  /// 返回图片URL
  Future<String> uploadImage(File file, String type, {String? bizId}) async {
    try {
      final response = await _http.uploadFile(
        '/upload/image',
        filePath: file.path,
        data: {
          'bizType': type,
          if (bizId != null && bizId.trim().isNotEmpty) 'bizId': bizId,
        },
      );

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      return (result.data!['file_url'] ??
              result.data!['file_path'] ??
              result.data!['fileUrl'] ??
              result.data!['filePath'] ??
              '')
          .toString();
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '上传图片失败'));
    }
  }

  /// 切换工作模式
  ///
  /// [workMode] true: 开启接单，false: 休息中
  Future<bool> toggleWorkMode(bool workMode) async {
    try {
      final response = await _http.post(
        '/nurse/acceptEnabled',
        data: {'enabled': workMode ? 1 : 0},
      );

      final result = ApiResponse.fromJson(response.data, null);

      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '切换工作模式失败'));
    }
  }

  /// 上报位置
  Future<bool> reportLocation(LocationReportRequest request) async {
    try {
      final response = await _http.post(
        '/nurse/location/report',
        data: request.toJson(),
      );

      final result = ApiResponse.fromJson(response.data, null);

      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '上报位置失败'));
    }
  }

  /// 获取今日任务列表
  ///
  /// [status] 订单状态筛选，null 表示全部
  /// 规则：
  /// - 默认：展示「我的今日任务」；待接单状态不按日期过滤，保证新单可及时接收
  /// - 指定状态（status<5）：按状态返回对应任务，不限制日期
  /// - 已完成筛选（status>=5）：展示历史已完成/已评价任务
  Future<List<NurseTaskModel>> getTodayTasks({int? status}) async {
    try {
      final all = await getAllTasks(status: status, page: 1, pageSize: 200);
      if (status != null && status < 5) {
        return all.where((task) => task.status == status).toList();
      }
      if (status != null && status >= 5) {
        return all.where((task) => task.status >= 5).toList();
      }

      // 默认视图：
      // - 待接单/待服务/服务中等进行中任务始终展示，避免接单后任务“突然消失”
      // - 已完成/已评价按“今日”过滤
      // - 已取消不在今日任务中展示
      final today = DateTime.now();
      return all.where((task) {
        if (task.status == 7) {
          return false;
        }
        if (task.status >= 1 && task.status <= 4) {
          return true;
        }
        final dt = _parseDateTime(task.appointmentTime);
        if (dt == null) return true;
        return dt.year == today.year &&
            dt.month == today.month &&
            dt.day == today.day;
      }).toList();
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '加载今日任务失败'));
    }
  }

  /// 获取全部任务列表（历史订单）
  Future<List<NurseTaskModel>> getAllTasks({
    int? status,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final params = <String, dynamic>{'pageNo': page, 'pageSize': pageSize};
      final backendStatus = _mapTaskStatusToBackendStatus(status);
      if (backendStatus != null) params['status'] = backendStatus;

      final response = await _http.get(
        '/nurse/order/list',
        queryParameters: params,
      );

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        return [];
      }

      final records = (result.data!['records'] as List?) ?? const [];
      final tasks = records
          .map((e) => _normalizeTask(Map<String, dynamic>.from(e as Map)))
          .map(NurseTaskModel.fromJson)
          .toList();

      if (status == 1 && backendStatus == null) {
        return tasks.where((task) => task.status == 1).toList();
      }

      return tasks;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '加载任务列表失败'));
    }
  }

  /// 获取任务详情
  Future<NurseTaskModel> getTaskDetail(int orderId) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.get('/nurse/order/detail/$orderNo');

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }

      return NurseTaskModel.fromJson(_normalizeTask(result.data!));
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '加载任务详情失败'));
    }
  }

  /// 获取任务全链路（状态流/支付退款/SOS）
  Future<Map<String, dynamic>> getTaskFlow(int orderId) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.get('/nurse/order/flow/$orderNo');

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }
      return Map<String, dynamic>.from(result.data!);
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '加载任务全链路失败'));
    }
  }

  /// 接单
  Future<bool> acceptOrder(int orderId) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.post('/nurse/order/accept/$orderNo');
      final result = ApiResponse.fromJson(response.data, null);

      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '接单失败'));
    }
  }

  /// 拒单（仅已派单状态可拒单）
  Future<bool> rejectOrder(int orderId) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      final response = await _http.post('/nurse/order/reject/$orderNo');
      final result = ApiResponse.fromJson(response.data, null);

      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '拒单失败'));
    }
  }

  /// 更新订单状态（到达/开始/完成）
  ///
  /// [orderId] 订单ID
  /// [status] 新状态：3到达，4开始服务，5完成服务
  /// [photoFile] 现场照片（可选，multipart 上传）
  Future<bool> updateTaskStatus(
    int orderId,
    int status, {
    File? photoFile,
  }) async {
    try {
      final orderNo = await _resolveOrderNo(orderId);
      String path;
      switch (status) {
        case 3:
          path = '/nurse/order/arrive/$orderNo';
          break;
        case 4:
          path = '/nurse/order/start/$orderNo';
          break;
        case 5:
          path = '/nurse/order/finish/$orderNo';
          break;
        default:
          return false;
      }

      if (photoFile != null) {
        final bizType = switch (status) {
          3 => 'nurse_arrive',
          4 => 'nurse_start',
          _ => 'nurse_finish',
        };
        await uploadImage(photoFile, bizType, bizId: orderNo);
      }

      final response = await _http.post(path);
      final result = ApiResponse.fromJson(response.data, null);

      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '更新任务状态失败'));
    }
  }

  /// 服务中发起 SOS 紧急呼叫
  Future<bool> triggerSos(
    int orderId, {
    String? description,
    int emergencyType = 1,
  }) async {
    try {
      final response = await _http.post(
        '/sos/trigger',
        data: {
          'orderId': orderId,
          'emergencyType': emergencyType,
          'description': description ?? '',
        },
      );
      final result = ApiResponse.fromJson(response.data, null);
      return result.isSuccess;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: 'SOS发送失败'));
    }
  }

  /// 获取附近待接单列表
  Future<List<NurseTaskModel>> getNearbyOrders({
    required double latitude,
    required double longitude,
    double radius = 10.0, // 默认10公里
  }) async {
    try {
      // 后端暂无“附近订单”独立接口，这里退化为“已派单待接单”列表
      return getAllTasks(status: 1, page: 1, pageSize: 50);
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '加载附近订单失败'));
    }
  }

  // =============== 收入相关 API ===============

  /// 获取平台配置（费率等）
  Future<PlatformConfigModel> getPlatformConfig() async {
    return PlatformConfigModel();
  }

  /// 获取收入统计
  Future<IncomeStatisticsModel> getIncomeStatistics() async {
    try {
      final logs = await getWalletLogs(page: 1, pageSize: 200);
      final now = DateTime.now();
      double todayIncome = 0;
      double monthIncome = 0;
      int todayOrders = 0;
      int monthOrders = 0;

      for (final log in logs) {
        if (!log.isIncome || log.type != 1) continue;
        final dt = _parseDateTime(log.createdAt);
        if (dt == null) continue;
        final amount = log.amount;
        if (dt.year == now.year && dt.month == now.month) {
          monthIncome += amount;
          monthOrders += 1;
          if (dt.day == now.day) {
            todayIncome += amount;
            todayOrders += 1;
          }
        }
      }

      final profile = await getProfile();
      return IncomeStatisticsModel.fromJson({
        'today_income': todayIncome,
        'month_income': monthIncome,
        'total_income':
            profile.balance +
            logs
                .where((e) => !e.isIncome && e.type == 2)
                .fold<double>(0, (sum, e) => sum + e.amount.abs()),
        'today_orders': todayOrders,
        'month_orders': monthOrders,
      });
    } catch (e) {
      return IncomeStatisticsModel();
    }
  }

  /// 获取钱包流水列表
  Future<List<WalletLogModel>> getWalletLogs({
    int? type,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final params = <String, dynamic>{'pageNo': page, 'pageSize': pageSize};

      final response = await _http.get(
        '/wallet/log/list',
        queryParameters: params,
      );

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        return [];
      }

      final records = (result.data!['records'] as List?) ?? const [];
      final list = records
          .map((e) => _normalizeWalletLog(Map<String, dynamic>.from(e as Map)))
          .where((e) => type == null || _toInt(e['type']) == type)
          .map(WalletLogModel.fromJson)
          .toList();
      return list;
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '加载钱包流水失败'));
    }
  }

  /// 获取提现记录列表
  Future<List<WithdrawModel>> getWithdrawals({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _http.get(
        '/withdraw/list',
        queryParameters: {'pageNo': page, 'pageSize': pageSize},
      );

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (!result.isSuccess || result.data == null) {
        return [];
      }

      final records = (result.data!['records'] as List?) ?? const [];
      return records
          .map((e) => _normalizeWithdrawal(Map<String, dynamic>.from(e as Map)))
          .map(WithdrawModel.fromJson)
          .toList();
    } catch (e) {
      throw Exception(normalizeErrorMessage(e, fallback: '加载提现记录失败'));
    }
  }

  /// 申请提现
  Future<WithdrawResponse> requestWithdraw(WithdrawRequest request) async {
    try {
      final response = await _http.post(
        '/withdraw/apply',
        data: {
          'amount': request.amount,
          'bankName': '支付宝',
          'bankAccount': request.alipayAccount,
          'accountHolder': request.realName,
        },
      );

      final result = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );

      if (result.isSuccess) {
        final withdrawId = _toInt(result.data?['id']);
        return WithdrawResponse(
          success: true,
          message: '提现申请已提交',
          withdrawId: withdrawId,
        );
      } else {
        return WithdrawResponse(success: false, message: result.message);
      }
    } catch (e) {
      return WithdrawResponse(
        success: false,
        message: normalizeErrorMessage(e, fallback: '提现申请失败'),
      );
    }
  }
}

/// NurseRepository Provider
final nurseRepositoryProvider = Provider<NurseRepository>((ref) {
  return NurseRepository(HttpClient.instance);
});
