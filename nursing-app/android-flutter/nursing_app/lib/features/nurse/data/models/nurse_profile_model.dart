import 'package:json_annotation/json_annotation.dart';

part 'nurse_profile_model.g.dart';

/// 护士审核状态枚举
enum AuditStatus {
  /// 待审核
  pending(0),

  /// 审核通过
  approved(1),

  /// 审核拒绝
  rejected(2);

  final int value;
  const AuditStatus(this.value);

  static AuditStatus fromValue(int value) {
    return AuditStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AuditStatus.pending,
    );
  }

  String get text {
    switch (this) {
      case AuditStatus.pending:
        return '待审核';
      case AuditStatus.approved:
        return '已通过';
      case AuditStatus.rejected:
        return '已拒绝';
    }
  }

  int get colorValue {
    switch (this) {
      case AuditStatus.pending:
        return 0xFFFF9800; // 橙色
      case AuditStatus.approved:
        return 0xFF4CAF50; // 绿色
      case AuditStatus.rejected:
        return 0xFFF44336; // 红色
    }
  }
}

/// 护士档案模型
///
/// 对应数据库 nurse_profile 表
@JsonSerializable()
class NurseProfileModel {
  /// 关联的用户ID
  @JsonKey(name: 'user_id')
  final int userId;

  /// 真实姓名
  @JsonKey(name: 'real_name')
  final String realName;

  /// 身份证号
  @JsonKey(name: 'id_card_no')
  final String? idCardNo;

  /// 身份证正面照片URL
  @JsonKey(name: 'id_card_photo_front')
  final String? idCardPhotoFront;

  /// 身份证背面照片URL
  @JsonKey(name: 'id_card_photo_back')
  final String? idCardPhotoBack;

  /// 护士执业证照片URL
  @JsonKey(name: 'certificate_photo')
  final String? certificatePhoto;

  /// 审核状态：0待审，1通过，2拒绝
  @JsonKey(name: 'audit_status')
  final int auditStatusValue;

  /// 审核拒绝原因
  @JsonKey(name: 'audit_reason')
  final String? auditReason;

  /// 工作模式：1开启接单，0休息中
  @JsonKey(name: 'work_mode')
  final int workModeValue;

  /// 账户余额(元)
  final double balance;

  /// 综合评分(1.0-5.0)
  final double rating;

  /// 服务区域
  @JsonKey(name: 'service_area')
  final String? serviceArea;

  /// 当前纬度
  @JsonKey(name: 'location_lat')
  final double? locationLat;

  /// 当前经度
  @JsonKey(name: 'location_lng')
  final double? locationLng;

  /// 头像URL
  final String? avatar;

  /// 手机号
  final String? phone;

  NurseProfileModel({
    required this.userId,
    required this.realName,
    this.idCardNo,
    this.idCardPhotoFront,
    this.idCardPhotoBack,
    this.certificatePhoto,
    this.auditStatusValue = 0,
    this.auditReason,
    this.workModeValue = 1,
    this.balance = 0.0,
    this.rating = 5.0,
    this.serviceArea,
    this.locationLat,
    this.locationLng,
    this.avatar,
    this.phone,
  });

  factory NurseProfileModel.fromJson(Map<String, dynamic> json) =>
      _$NurseProfileModelFromJson(json);

  Map<String, dynamic> toJson() => _$NurseProfileModelToJson(this);

  /// 获取审核状态枚举
  AuditStatus get auditStatus => AuditStatus.fromValue(auditStatusValue);

  /// 是否为工作模式
  bool get isWorkMode => workModeValue == 1;

  /// 是否已通过审核
  bool get isApproved => auditStatusValue == 1;

  /// 是否待审核
  bool get isPending => auditStatusValue == 0;

  /// 是否被拒绝
  bool get isRejected => auditStatusValue == 2;

  /// 复制并修改
  NurseProfileModel copyWith({
    int? userId,
    String? realName,
    String? idCardNo,
    String? idCardPhotoFront,
    String? idCardPhotoBack,
    String? certificatePhoto,
    int? auditStatusValue,
    String? auditReason,
    int? workModeValue,
    double? balance,
    double? rating,
    String? serviceArea,
    double? locationLat,
    double? locationLng,
    String? avatar,
    String? phone,
  }) {
    return NurseProfileModel(
      userId: userId ?? this.userId,
      realName: realName ?? this.realName,
      idCardNo: idCardNo ?? this.idCardNo,
      idCardPhotoFront: idCardPhotoFront ?? this.idCardPhotoFront,
      idCardPhotoBack: idCardPhotoBack ?? this.idCardPhotoBack,
      certificatePhoto: certificatePhoto ?? this.certificatePhoto,
      auditStatusValue: auditStatusValue ?? this.auditStatusValue,
      auditReason: auditReason ?? this.auditReason,
      workModeValue: workModeValue ?? this.workModeValue,
      balance: balance ?? this.balance,
      rating: rating ?? this.rating,
      serviceArea: serviceArea ?? this.serviceArea,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      avatar: avatar ?? this.avatar,
      phone: phone ?? this.phone,
    );
  }
}

/// 护士任务（订单）模型
///
/// 护士端查看的任务/订单
@JsonSerializable()
class NurseTaskModel {
  final int id;

  @JsonKey(name: 'order_no')
  final String orderNo;

  @JsonKey(name: 'user_id')
  final int userId;

  @JsonKey(name: 'nurse_id')
  final int? nurseId;

  @JsonKey(name: 'service_id')
  final int serviceId;

  @JsonKey(name: 'service_name')
  final String serviceName;

  @JsonKey(name: 'service_price')
  final double servicePrice;

  @JsonKey(name: 'total_amount')
  final double totalAmount;

  @JsonKey(name: 'platform_fee')
  final double platformFee;

  @JsonKey(name: 'nurse_income')
  final double nurseIncome;

  @JsonKey(name: 'contact_name')
  final String contactName;

  @JsonKey(name: 'contact_phone')
  final String contactPhone;

  final String address;

  @JsonKey(name: 'appointment_time')
  final String appointmentTime;

  final String? remark;

  final double? latitude;
  final double? longitude;

  /// 订单状态
  final int status;

  /// 支付状态
  @JsonKey(name: 'pay_status')
  final int payStatus;

  /// 到达时间
  @JsonKey(name: 'arrival_time')
  final String? arrivalTime;

  /// 到达打卡照
  @JsonKey(name: 'arrival_photo')
  final String? arrivalPhoto;

  /// 开始服务时间
  @JsonKey(name: 'start_time')
  final String? startTime;

  /// 服务前照片
  @JsonKey(name: 'start_photo')
  final String? startPhoto;

  /// 完成服务时间
  @JsonKey(name: 'finish_time')
  final String? finishTime;

  /// 服务后照片
  @JsonKey(name: 'finish_photo')
  final String? finishPhoto;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  NurseTaskModel({
    required this.id,
    required this.orderNo,
    required this.userId,
    this.nurseId,
    required this.serviceId,
    required this.serviceName,
    required this.servicePrice,
    required this.totalAmount,
    this.platformFee = 0,
    this.nurseIncome = 0,
    required this.contactName,
    required this.contactPhone,
    required this.address,
    required this.appointmentTime,
    this.remark,
    this.latitude,
    this.longitude,
    required this.status,
    this.payStatus = 0,
    this.arrivalTime,
    this.arrivalPhoto,
    this.startTime,
    this.startPhoto,
    this.finishTime,
    this.finishPhoto,
    this.createdAt,
  });

  factory NurseTaskModel.fromJson(Map<String, dynamic> json) =>
      _$NurseTaskModelFromJson(json);

  Map<String, dynamic> toJson() => _$NurseTaskModelToJson(this);

  /// 获取状态文本
  String get statusText {
    switch (status) {
      case 1:
        return '待接单';
      case 2:
        return '待服务';
      case 3:
        return '已到达';
      case 4:
        return '服务中';
      case 5:
        return '待评价';
      case 6:
        return '已完成';
      case 7:
        return '已取消';
      default:
        return '未知';
    }
  }

  /// 获取状态颜色值
  int get statusColorValue {
    switch (status) {
      case 1:
        return 0xFF2196F3; // 蓝色
      case 2:
        return 0xFFFF9800; // 橙色
      case 3:
        return 0xFF9C27B0; // 紫色
      case 4:
        return 0xFF00BCD4; // 青色
      case 5:
        return 0xFFE91E63; // 粉色
      case 6:
        return 0xFF4CAF50; // 绿色
      case 7:
        return 0xFF9E9E9E; // 灰色
      default:
        return 0xFF9E9E9E;
    }
  }

  /// 是否可以点击"到达现场"
  bool get canArrived => status == 2;

  /// 是否可以点击"接单"
  bool get canAccept => status == 1;

  /// 是否可以点击"拒单"
  /// 待接单阶段允许显示拒单入口，最终权限以后端校验为准
  bool get canReject => status == 1;

  /// 是否可以点击"开始服务"
  bool get canStart => status == 3;

  /// 是否可以点击"完成服务"
  bool get canFinish => status == 4;

  /// 复制
  NurseTaskModel copyWith({
    int? id,
    String? orderNo,
    int? userId,
    int? nurseId,
    int? serviceId,
    String? serviceName,
    double? servicePrice,
    double? totalAmount,
    double? platformFee,
    double? nurseIncome,
    String? contactName,
    String? contactPhone,
    String? address,
    String? appointmentTime,
    String? remark,
    double? latitude,
    double? longitude,
    int? status,
    int? payStatus,
    String? arrivalTime,
    String? arrivalPhoto,
    String? startTime,
    String? startPhoto,
    String? finishTime,
    String? finishPhoto,
    String? createdAt,
  }) {
    return NurseTaskModel(
      id: id ?? this.id,
      orderNo: orderNo ?? this.orderNo,
      userId: userId ?? this.userId,
      nurseId: nurseId ?? this.nurseId,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      servicePrice: servicePrice ?? this.servicePrice,
      totalAmount: totalAmount ?? this.totalAmount,
      platformFee: platformFee ?? this.platformFee,
      nurseIncome: nurseIncome ?? this.nurseIncome,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      address: address ?? this.address,
      appointmentTime: appointmentTime ?? this.appointmentTime,
      remark: remark ?? this.remark,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      payStatus: payStatus ?? this.payStatus,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      arrivalPhoto: arrivalPhoto ?? this.arrivalPhoto,
      startTime: startTime ?? this.startTime,
      startPhoto: startPhoto ?? this.startPhoto,
      finishTime: finishTime ?? this.finishTime,
      finishPhoto: finishPhoto ?? this.finishPhoto,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 护士注册请求
@JsonSerializable()
class NurseRegisterRequest {
  @JsonKey(name: 'real_name')
  final String realName;

  @JsonKey(name: 'id_card_no')
  final String idCardNo;

  @JsonKey(name: 'license_no')
  final String licenseNo;

  @JsonKey(name: 'hospital')
  final String hospital;

  @JsonKey(name: 'work_years')
  final int workYears;

  @JsonKey(name: 'skill_desc')
  final String skillDesc;

  @JsonKey(name: 'id_card_photo_front')
  final String idCardPhotoFront;

  @JsonKey(name: 'id_card_photo_back')
  final String idCardPhotoBack;

  @JsonKey(name: 'certificate_photo')
  final String certificatePhoto;

  @JsonKey(name: 'nurse_photo')
  final String nursePhoto;

  NurseRegisterRequest({
    required this.realName,
    required this.idCardNo,
    required this.licenseNo,
    required this.hospital,
    required this.workYears,
    required this.skillDesc,
    required this.idCardPhotoFront,
    required this.idCardPhotoBack,
    required this.certificatePhoto,
    required this.nursePhoto,
  });

  factory NurseRegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$NurseRegisterRequestFromJson(json);

  Map<String, dynamic> toJson() => _$NurseRegisterRequestToJson(this);
}

/// 位置上报请求
@JsonSerializable()
class LocationReportRequest {
  final double latitude;
  final double longitude;

  LocationReportRequest({required this.latitude, required this.longitude});

  factory LocationReportRequest.fromJson(Map<String, dynamic> json) =>
      _$LocationReportRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LocationReportRequestToJson(this);
}

/// 更新订单状态请求
@JsonSerializable()
class UpdateTaskStatusRequest {
  @JsonKey(name: 'order_id')
  final int orderId;

  /// 新状态：3到达，4开始服务，5完成服务
  final int status;

  /// 照片URL（可选）
  final String? photo;

  UpdateTaskStatusRequest({
    required this.orderId,
    required this.status,
    this.photo,
  });

  factory UpdateTaskStatusRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateTaskStatusRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateTaskStatusRequestToJson(this);
}

/// 钱包流水类型
enum WalletLogType {
  /// 订单收入
  orderIncome(1),

  /// 提现支出
  withdraw(2),

  /// 系统调整
  adjustment(3);

  final int value;
  const WalletLogType(this.value);

  static WalletLogType fromValue(int value) {
    return WalletLogType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => WalletLogType.orderIncome,
    );
  }

  String get text {
    switch (this) {
      case WalletLogType.orderIncome:
        return '订单收入';
      case WalletLogType.withdraw:
        return '提现';
      case WalletLogType.adjustment:
        return '系统调整';
    }
  }

  int get colorValue {
    switch (this) {
      case WalletLogType.orderIncome:
        return 0xFF4CAF50; // 绿色
      case WalletLogType.withdraw:
        return 0xFFF44336; // 红色
      case WalletLogType.adjustment:
        return 0xFF2196F3; // 蓝色
    }
  }
}

/// 钱包流水模型
///
/// 对应数据库 wallet_log 表
@JsonSerializable()
class WalletLogModel {
  final int id;

  @JsonKey(name: 'nurse_id')
  final int nurseId;

  /// 变动金额（+收入，-支出）
  final double amount;

  /// 类型：1订单收入，2提现支出，3系统调整
  final int type;

  /// 关联的订单号或提现单号
  @JsonKey(name: 'ref_id')
  final String? refId;

  /// 流水描述
  final String? description;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  WalletLogModel({
    required this.id,
    required this.nurseId,
    required this.amount,
    required this.type,
    this.refId,
    this.description,
    this.createdAt,
  });

  factory WalletLogModel.fromJson(Map<String, dynamic> json) =>
      _$WalletLogModelFromJson(json);

  Map<String, dynamic> toJson() => _$WalletLogModelToJson(this);

  /// 获取类型枚举
  WalletLogType get logType => WalletLogType.fromValue(type);

  /// 是否为收入
  bool get isIncome => amount > 0;
}

/// 提现状态
enum WithdrawStatus {
  /// 待审核
  pending(0),

  /// 审核通过（待打款）
  approved(1),

  /// 已打款
  completed(3),

  /// 已驳回
  rejected(2);

  final int value;
  const WithdrawStatus(this.value);

  static WithdrawStatus fromValue(int value) {
    return WithdrawStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => WithdrawStatus.pending,
    );
  }

  String get text {
    switch (this) {
      case WithdrawStatus.pending:
        return '审核中';
      case WithdrawStatus.approved:
        return '审核通过';
      case WithdrawStatus.completed:
        return '已打款';
      case WithdrawStatus.rejected:
        return '已驳回';
    }
  }

  int get colorValue {
    switch (this) {
      case WithdrawStatus.pending:
        return 0xFFFF9800; // 橙色
      case WithdrawStatus.approved:
        return 0xFF2196F3; // 蓝色
      case WithdrawStatus.completed:
        return 0xFF4CAF50; // 绿色
      case WithdrawStatus.rejected:
        return 0xFFF44336; // 红色
    }
  }
}

/// 提现记录模型
///
/// 对应数据库 withdrawals 表
@JsonSerializable()
class WithdrawModel {
  final int id;

  @JsonKey(name: 'nurse_id')
  final int nurseId;

  /// 提现金额
  final double amount;

  /// 支付宝账号
  @JsonKey(name: 'alipay_account')
  final String alipayAccount;

  /// 真实姓名
  @JsonKey(name: 'real_name')
  final String realName;

  /// 状态：0待审核，1已打款，2驳回
  final int status;

  /// 驳回原因
  @JsonKey(name: 'reject_reason')
  final String? rejectReason;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  @JsonKey(name: 'audit_time')
  final String? auditTime;

  WithdrawModel({
    required this.id,
    required this.nurseId,
    required this.amount,
    required this.alipayAccount,
    required this.realName,
    required this.status,
    this.rejectReason,
    this.createdAt,
    this.auditTime,
  });

  factory WithdrawModel.fromJson(Map<String, dynamic> json) =>
      _$WithdrawModelFromJson(json);

  Map<String, dynamic> toJson() => _$WithdrawModelToJson(this);

  /// 获取状态枚举
  WithdrawStatus get withdrawStatus => WithdrawStatus.fromValue(status);
}

/// 提现申请请求
@JsonSerializable()
class WithdrawRequest {
  final double amount;

  @JsonKey(name: 'alipay_account')
  final String alipayAccount;

  @JsonKey(name: 'real_name')
  final String realName;

  WithdrawRequest({
    required this.amount,
    required this.alipayAccount,
    required this.realName,
  });

  factory WithdrawRequest.fromJson(Map<String, dynamic> json) =>
      _$WithdrawRequestFromJson(json);

  Map<String, dynamic> toJson() => _$WithdrawRequestToJson(this);
}

/// 提现响应
@JsonSerializable()
class WithdrawResponse {
  final bool success;
  final String message;

  @JsonKey(name: 'withdraw_id')
  final int? withdrawId;

  WithdrawResponse({
    required this.success,
    required this.message,
    this.withdrawId,
  });

  factory WithdrawResponse.fromJson(Map<String, dynamic> json) =>
      _$WithdrawResponseFromJson(json);

  Map<String, dynamic> toJson() => _$WithdrawResponseToJson(this);
}

/// 平台配置模型
@JsonSerializable()
class PlatformConfigModel {
  /// 平台费率（如 0.20 表示 20%）
  @JsonKey(name: 'platform_fee_rate')
  final double platformFeeRate;

  /// 最低提现金额
  @JsonKey(name: 'min_withdraw_amount')
  final double minWithdrawAmount;

  PlatformConfigModel({
    this.platformFeeRate = 0.20,
    this.minWithdrawAmount = 10.0,
  });

  factory PlatformConfigModel.fromJson(Map<String, dynamic> json) =>
      _$PlatformConfigModelFromJson(json);

  Map<String, dynamic> toJson() => _$PlatformConfigModelToJson(this);

  /// 费率百分比文本
  String get feeRateText => '${(platformFeeRate * 100).toInt()}%';
}

/// 收入统计模型
@JsonSerializable()
class IncomeStatisticsModel {
  /// 今日收入
  @JsonKey(name: 'today_income')
  final double todayIncome;

  /// 本月收入
  @JsonKey(name: 'month_income')
  final double monthIncome;

  /// 总收入
  @JsonKey(name: 'total_income')
  final double totalIncome;

  /// 今日订单数
  @JsonKey(name: 'today_orders')
  final int todayOrders;

  /// 本月订单数
  @JsonKey(name: 'month_orders')
  final int monthOrders;

  IncomeStatisticsModel({
    this.todayIncome = 0.0,
    this.monthIncome = 0.0,
    this.totalIncome = 0.0,
    this.todayOrders = 0,
    this.monthOrders = 0,
  });

  factory IncomeStatisticsModel.fromJson(Map<String, dynamic> json) =>
      _$IncomeStatisticsModelFromJson(json);

  Map<String, dynamic> toJson() => _$IncomeStatisticsModelToJson(this);
}
