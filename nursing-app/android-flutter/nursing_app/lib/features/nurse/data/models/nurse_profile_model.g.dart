// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nurse_profile_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NurseProfileModel _$NurseProfileModelFromJson(Map<String, dynamic> json) =>
    NurseProfileModel(
      userId: (json['user_id'] as num).toInt(),
      realName: json['real_name'] as String,
      idCardNo: json['id_card_no'] as String?,
      idCardPhotoFront: json['id_card_photo_front'] as String?,
      idCardPhotoBack: json['id_card_photo_back'] as String?,
      certificatePhoto: json['certificate_photo'] as String?,
      auditStatusValue: (json['audit_status'] as num?)?.toInt() ?? 0,
      auditReason: json['audit_reason'] as String?,
      workModeValue: (json['work_mode'] as num?)?.toInt() ?? 1,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      serviceArea: json['service_area'] as String?,
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      avatar: json['avatar'] as String?,
      phone: json['phone'] as String?,
    );

Map<String, dynamic> _$NurseProfileModelToJson(NurseProfileModel instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'real_name': instance.realName,
      'id_card_no': instance.idCardNo,
      'id_card_photo_front': instance.idCardPhotoFront,
      'id_card_photo_back': instance.idCardPhotoBack,
      'certificate_photo': instance.certificatePhoto,
      'audit_status': instance.auditStatusValue,
      'audit_reason': instance.auditReason,
      'work_mode': instance.workModeValue,
      'balance': instance.balance,
      'rating': instance.rating,
      'service_area': instance.serviceArea,
      'location_lat': instance.locationLat,
      'location_lng': instance.locationLng,
      'avatar': instance.avatar,
      'phone': instance.phone,
    };

NurseTaskModel _$NurseTaskModelFromJson(Map<String, dynamic> json) =>
    NurseTaskModel(
      id: (json['id'] as num).toInt(),
      orderNo: json['order_no'] as String,
      userId: (json['user_id'] as num).toInt(),
      nurseId: (json['nurse_id'] as num?)?.toInt(),
      serviceId: (json['service_id'] as num).toInt(),
      serviceName: json['service_name'] as String,
      servicePrice: (json['service_price'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      platformFee: (json['platform_fee'] as num?)?.toDouble() ?? 0,
      nurseIncome: (json['nurse_income'] as num?)?.toDouble() ?? 0,
      contactName: json['contact_name'] as String,
      contactPhone: json['contact_phone'] as String,
      address: json['address'] as String,
      appointmentTime: json['appointment_time'] as String,
      remark: json['remark'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: (json['status'] as num).toInt(),
      payStatus: (json['pay_status'] as num?)?.toInt() ?? 0,
      arrivalTime: json['arrival_time'] as String?,
      arrivalPhoto: json['arrival_photo'] as String?,
      startTime: json['start_time'] as String?,
      startPhoto: json['start_photo'] as String?,
      finishTime: json['finish_time'] as String?,
      finishPhoto: json['finish_photo'] as String?,
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$NurseTaskModelToJson(NurseTaskModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_no': instance.orderNo,
      'user_id': instance.userId,
      'nurse_id': instance.nurseId,
      'service_id': instance.serviceId,
      'service_name': instance.serviceName,
      'service_price': instance.servicePrice,
      'total_amount': instance.totalAmount,
      'platform_fee': instance.platformFee,
      'nurse_income': instance.nurseIncome,
      'contact_name': instance.contactName,
      'contact_phone': instance.contactPhone,
      'address': instance.address,
      'appointment_time': instance.appointmentTime,
      'remark': instance.remark,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'status': instance.status,
      'pay_status': instance.payStatus,
      'arrival_time': instance.arrivalTime,
      'arrival_photo': instance.arrivalPhoto,
      'start_time': instance.startTime,
      'start_photo': instance.startPhoto,
      'finish_time': instance.finishTime,
      'finish_photo': instance.finishPhoto,
      'created_at': instance.createdAt,
    };

NurseRegisterRequest _$NurseRegisterRequestFromJson(
  Map<String, dynamic> json,
) => NurseRegisterRequest(
  realName: json['real_name'] as String,
  idCardNo: json['id_card_no'] as String,
  licenseNo: json['license_no'] as String,
  hospital: json['hospital'] as String,
  workYears: (json['work_years'] as num).toInt(),
  skillDesc: json['skill_desc'] as String,
  idCardPhotoFront: json['id_card_photo_front'] as String,
  idCardPhotoBack: json['id_card_photo_back'] as String,
  certificatePhoto: json['certificate_photo'] as String,
  nursePhoto: json['nurse_photo'] as String,
);

Map<String, dynamic> _$NurseRegisterRequestToJson(
  NurseRegisterRequest instance,
) => <String, dynamic>{
  'real_name': instance.realName,
  'id_card_no': instance.idCardNo,
  'license_no': instance.licenseNo,
  'hospital': instance.hospital,
  'work_years': instance.workYears,
  'skill_desc': instance.skillDesc,
  'id_card_photo_front': instance.idCardPhotoFront,
  'id_card_photo_back': instance.idCardPhotoBack,
  'certificate_photo': instance.certificatePhoto,
  'nurse_photo': instance.nursePhoto,
};

LocationReportRequest _$LocationReportRequestFromJson(
  Map<String, dynamic> json,
) => LocationReportRequest(
  latitude: (json['latitude'] as num).toDouble(),
  longitude: (json['longitude'] as num).toDouble(),
);

Map<String, dynamic> _$LocationReportRequestToJson(
  LocationReportRequest instance,
) => <String, dynamic>{
  'latitude': instance.latitude,
  'longitude': instance.longitude,
};

UpdateTaskStatusRequest _$UpdateTaskStatusRequestFromJson(
  Map<String, dynamic> json,
) => UpdateTaskStatusRequest(
  orderId: (json['order_id'] as num).toInt(),
  status: (json['status'] as num).toInt(),
  photo: json['photo'] as String?,
);

Map<String, dynamic> _$UpdateTaskStatusRequestToJson(
  UpdateTaskStatusRequest instance,
) => <String, dynamic>{
  'order_id': instance.orderId,
  'status': instance.status,
  'photo': instance.photo,
};

WalletLogModel _$WalletLogModelFromJson(Map<String, dynamic> json) =>
    WalletLogModel(
      id: (json['id'] as num).toInt(),
      nurseId: (json['nurse_id'] as num).toInt(),
      amount: (json['amount'] as num).toDouble(),
      type: (json['type'] as num).toInt(),
      refId: json['ref_id'] as String?,
      description: json['description'] as String?,
      createdAt: json['created_at'] as String?,
    );

Map<String, dynamic> _$WalletLogModelToJson(WalletLogModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nurse_id': instance.nurseId,
      'amount': instance.amount,
      'type': instance.type,
      'ref_id': instance.refId,
      'description': instance.description,
      'created_at': instance.createdAt,
    };

WithdrawModel _$WithdrawModelFromJson(Map<String, dynamic> json) =>
    WithdrawModel(
      id: (json['id'] as num).toInt(),
      nurseId: (json['nurse_id'] as num).toInt(),
      amount: (json['amount'] as num).toDouble(),
      alipayAccount: json['alipay_account'] as String,
      realName: json['real_name'] as String,
      status: (json['status'] as num).toInt(),
      rejectReason: json['reject_reason'] as String?,
      createdAt: json['created_at'] as String?,
      auditTime: json['audit_time'] as String?,
    );

Map<String, dynamic> _$WithdrawModelToJson(WithdrawModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nurse_id': instance.nurseId,
      'amount': instance.amount,
      'alipay_account': instance.alipayAccount,
      'real_name': instance.realName,
      'status': instance.status,
      'reject_reason': instance.rejectReason,
      'created_at': instance.createdAt,
      'audit_time': instance.auditTime,
    };

WithdrawRequest _$WithdrawRequestFromJson(Map<String, dynamic> json) =>
    WithdrawRequest(
      amount: (json['amount'] as num).toDouble(),
      alipayAccount: json['alipay_account'] as String,
      realName: json['real_name'] as String,
    );

Map<String, dynamic> _$WithdrawRequestToJson(WithdrawRequest instance) =>
    <String, dynamic>{
      'amount': instance.amount,
      'alipay_account': instance.alipayAccount,
      'real_name': instance.realName,
    };

WithdrawResponse _$WithdrawResponseFromJson(Map<String, dynamic> json) =>
    WithdrawResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      withdrawId: (json['withdraw_id'] as num?)?.toInt(),
    );

Map<String, dynamic> _$WithdrawResponseToJson(WithdrawResponse instance) =>
    <String, dynamic>{
      'success': instance.success,
      'message': instance.message,
      'withdraw_id': instance.withdrawId,
    };

PlatformConfigModel _$PlatformConfigModelFromJson(Map<String, dynamic> json) =>
    PlatformConfigModel(
      platformFeeRate: (json['platform_fee_rate'] as num?)?.toDouble() ?? 0.20,
      minWithdrawAmount:
          (json['min_withdraw_amount'] as num?)?.toDouble() ?? 10.0,
    );

Map<String, dynamic> _$PlatformConfigModelToJson(
  PlatformConfigModel instance,
) => <String, dynamic>{
  'platform_fee_rate': instance.platformFeeRate,
  'min_withdraw_amount': instance.minWithdrawAmount,
};

IncomeStatisticsModel _$IncomeStatisticsModelFromJson(
  Map<String, dynamic> json,
) => IncomeStatisticsModel(
  todayIncome: (json['today_income'] as num?)?.toDouble() ?? 0.0,
  monthIncome: (json['month_income'] as num?)?.toDouble() ?? 0.0,
  totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0.0,
  todayOrders: (json['today_orders'] as num?)?.toInt() ?? 0,
  monthOrders: (json['month_orders'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$IncomeStatisticsModelToJson(
  IncomeStatisticsModel instance,
) => <String, dynamic>{
  'today_income': instance.todayIncome,
  'month_income': instance.monthIncome,
  'total_income': instance.totalIncome,
  'today_orders': instance.todayOrders,
  'month_orders': instance.monthOrders,
};
