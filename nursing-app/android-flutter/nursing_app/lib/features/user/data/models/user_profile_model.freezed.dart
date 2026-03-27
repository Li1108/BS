// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_profile_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

UserProfileModel _$UserProfileModelFromJson(Map<String, dynamic> json) {
  return _UserProfileModel.fromJson(json);
}

/// @nodoc
mixin _$UserProfileModel {
  int get id => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  String? get nickname => throw _privateConstructorUsedError;
  String? get avatarUrl => throw _privateConstructorUsedError;
  int? get gender => throw _privateConstructorUsedError; // 0: 未设置, 1: 男, 2: 女
  String? get realName => throw _privateConstructorUsedError;
  String? get idCardNo => throw _privateConstructorUsedError;
  String? get birthday => throw _privateConstructorUsedError;
  String? get emergencyContact => throw _privateConstructorUsedError;
  String? get emergencyPhone => throw _privateConstructorUsedError;
  int? get status => throw _privateConstructorUsedError;
  String? get createTime => throw _privateConstructorUsedError;
  int? get realNameVerified =>
      throw _privateConstructorUsedError; // 0-未认证，1-已认证
  String? get realNameVerifyTime => throw _privateConstructorUsedError;

  /// Serializes this UserProfileModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserProfileModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserProfileModelCopyWith<UserProfileModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserProfileModelCopyWith<$Res> {
  factory $UserProfileModelCopyWith(
    UserProfileModel value,
    $Res Function(UserProfileModel) then,
  ) = _$UserProfileModelCopyWithImpl<$Res, UserProfileModel>;
  @useResult
  $Res call({
    int id,
    String phone,
    String? nickname,
    String? avatarUrl,
    int? gender,
    String? realName,
    String? idCardNo,
    String? birthday,
    String? emergencyContact,
    String? emergencyPhone,
    int? status,
    String? createTime,
    int? realNameVerified,
    String? realNameVerifyTime,
  });
}

/// @nodoc
class _$UserProfileModelCopyWithImpl<$Res, $Val extends UserProfileModel>
    implements $UserProfileModelCopyWith<$Res> {
  _$UserProfileModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserProfileModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? phone = null,
    Object? nickname = freezed,
    Object? avatarUrl = freezed,
    Object? gender = freezed,
    Object? realName = freezed,
    Object? idCardNo = freezed,
    Object? birthday = freezed,
    Object? emergencyContact = freezed,
    Object? emergencyPhone = freezed,
    Object? status = freezed,
    Object? createTime = freezed,
    Object? realNameVerified = freezed,
    Object? realNameVerifyTime = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            phone: null == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                      as String,
            nickname: freezed == nickname
                ? _value.nickname
                : nickname // ignore: cast_nullable_to_non_nullable
                      as String?,
            avatarUrl: freezed == avatarUrl
                ? _value.avatarUrl
                : avatarUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            gender: freezed == gender
                ? _value.gender
                : gender // ignore: cast_nullable_to_non_nullable
                      as int?,
            realName: freezed == realName
                ? _value.realName
                : realName // ignore: cast_nullable_to_non_nullable
                      as String?,
            idCardNo: freezed == idCardNo
                ? _value.idCardNo
                : idCardNo // ignore: cast_nullable_to_non_nullable
                      as String?,
            birthday: freezed == birthday
                ? _value.birthday
                : birthday // ignore: cast_nullable_to_non_nullable
                      as String?,
            emergencyContact: freezed == emergencyContact
                ? _value.emergencyContact
                : emergencyContact // ignore: cast_nullable_to_non_nullable
                      as String?,
            emergencyPhone: freezed == emergencyPhone
                ? _value.emergencyPhone
                : emergencyPhone // ignore: cast_nullable_to_non_nullable
                      as String?,
            status: freezed == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as int?,
            createTime: freezed == createTime
                ? _value.createTime
                : createTime // ignore: cast_nullable_to_non_nullable
                      as String?,
            realNameVerified: freezed == realNameVerified
                ? _value.realNameVerified
                : realNameVerified // ignore: cast_nullable_to_non_nullable
                      as int?,
            realNameVerifyTime: freezed == realNameVerifyTime
                ? _value.realNameVerifyTime
                : realNameVerifyTime // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$UserProfileModelImplCopyWith<$Res>
    implements $UserProfileModelCopyWith<$Res> {
  factory _$$UserProfileModelImplCopyWith(
    _$UserProfileModelImpl value,
    $Res Function(_$UserProfileModelImpl) then,
  ) = __$$UserProfileModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String phone,
    String? nickname,
    String? avatarUrl,
    int? gender,
    String? realName,
    String? idCardNo,
    String? birthday,
    String? emergencyContact,
    String? emergencyPhone,
    int? status,
    String? createTime,
    int? realNameVerified,
    String? realNameVerifyTime,
  });
}

/// @nodoc
class __$$UserProfileModelImplCopyWithImpl<$Res>
    extends _$UserProfileModelCopyWithImpl<$Res, _$UserProfileModelImpl>
    implements _$$UserProfileModelImplCopyWith<$Res> {
  __$$UserProfileModelImplCopyWithImpl(
    _$UserProfileModelImpl _value,
    $Res Function(_$UserProfileModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserProfileModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? phone = null,
    Object? nickname = freezed,
    Object? avatarUrl = freezed,
    Object? gender = freezed,
    Object? realName = freezed,
    Object? idCardNo = freezed,
    Object? birthday = freezed,
    Object? emergencyContact = freezed,
    Object? emergencyPhone = freezed,
    Object? status = freezed,
    Object? createTime = freezed,
    Object? realNameVerified = freezed,
    Object? realNameVerifyTime = freezed,
  }) {
    return _then(
      _$UserProfileModelImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        phone: null == phone
            ? _value.phone
            : phone // ignore: cast_nullable_to_non_nullable
                  as String,
        nickname: freezed == nickname
            ? _value.nickname
            : nickname // ignore: cast_nullable_to_non_nullable
                  as String?,
        avatarUrl: freezed == avatarUrl
            ? _value.avatarUrl
            : avatarUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        gender: freezed == gender
            ? _value.gender
            : gender // ignore: cast_nullable_to_non_nullable
                  as int?,
        realName: freezed == realName
            ? _value.realName
            : realName // ignore: cast_nullable_to_non_nullable
                  as String?,
        idCardNo: freezed == idCardNo
            ? _value.idCardNo
            : idCardNo // ignore: cast_nullable_to_non_nullable
                  as String?,
        birthday: freezed == birthday
            ? _value.birthday
            : birthday // ignore: cast_nullable_to_non_nullable
                  as String?,
        emergencyContact: freezed == emergencyContact
            ? _value.emergencyContact
            : emergencyContact // ignore: cast_nullable_to_non_nullable
                  as String?,
        emergencyPhone: freezed == emergencyPhone
            ? _value.emergencyPhone
            : emergencyPhone // ignore: cast_nullable_to_non_nullable
                  as String?,
        status: freezed == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as int?,
        createTime: freezed == createTime
            ? _value.createTime
            : createTime // ignore: cast_nullable_to_non_nullable
                  as String?,
        realNameVerified: freezed == realNameVerified
            ? _value.realNameVerified
            : realNameVerified // ignore: cast_nullable_to_non_nullable
                  as int?,
        realNameVerifyTime: freezed == realNameVerifyTime
            ? _value.realNameVerifyTime
            : realNameVerifyTime // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$UserProfileModelImpl extends _UserProfileModel {
  const _$UserProfileModelImpl({
    required this.id,
    required this.phone,
    this.nickname,
    this.avatarUrl,
    this.gender,
    this.realName,
    this.idCardNo,
    this.birthday,
    this.emergencyContact,
    this.emergencyPhone,
    this.status,
    this.createTime,
    this.realNameVerified,
    this.realNameVerifyTime,
  }) : super._();

  factory _$UserProfileModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserProfileModelImplFromJson(json);

  @override
  final int id;
  @override
  final String phone;
  @override
  final String? nickname;
  @override
  final String? avatarUrl;
  @override
  final int? gender;
  // 0: 未设置, 1: 男, 2: 女
  @override
  final String? realName;
  @override
  final String? idCardNo;
  @override
  final String? birthday;
  @override
  final String? emergencyContact;
  @override
  final String? emergencyPhone;
  @override
  final int? status;
  @override
  final String? createTime;
  @override
  final int? realNameVerified;
  // 0-未认证，1-已认证
  @override
  final String? realNameVerifyTime;

  @override
  String toString() {
    return 'UserProfileModel(id: $id, phone: $phone, nickname: $nickname, avatarUrl: $avatarUrl, gender: $gender, realName: $realName, idCardNo: $idCardNo, birthday: $birthday, emergencyContact: $emergencyContact, emergencyPhone: $emergencyPhone, status: $status, createTime: $createTime, realNameVerified: $realNameVerified, realNameVerifyTime: $realNameVerifyTime)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserProfileModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.nickname, nickname) ||
                other.nickname == nickname) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.gender, gender) || other.gender == gender) &&
            (identical(other.realName, realName) ||
                other.realName == realName) &&
            (identical(other.idCardNo, idCardNo) ||
                other.idCardNo == idCardNo) &&
            (identical(other.birthday, birthday) ||
                other.birthday == birthday) &&
            (identical(other.emergencyContact, emergencyContact) ||
                other.emergencyContact == emergencyContact) &&
            (identical(other.emergencyPhone, emergencyPhone) ||
                other.emergencyPhone == emergencyPhone) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createTime, createTime) ||
                other.createTime == createTime) &&
            (identical(other.realNameVerified, realNameVerified) ||
                other.realNameVerified == realNameVerified) &&
            (identical(other.realNameVerifyTime, realNameVerifyTime) ||
                other.realNameVerifyTime == realNameVerifyTime));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    phone,
    nickname,
    avatarUrl,
    gender,
    realName,
    idCardNo,
    birthday,
    emergencyContact,
    emergencyPhone,
    status,
    createTime,
    realNameVerified,
    realNameVerifyTime,
  );

  /// Create a copy of UserProfileModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserProfileModelImplCopyWith<_$UserProfileModelImpl> get copyWith =>
      __$$UserProfileModelImplCopyWithImpl<_$UserProfileModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$UserProfileModelImplToJson(this);
  }
}

abstract class _UserProfileModel extends UserProfileModel {
  const factory _UserProfileModel({
    required final int id,
    required final String phone,
    final String? nickname,
    final String? avatarUrl,
    final int? gender,
    final String? realName,
    final String? idCardNo,
    final String? birthday,
    final String? emergencyContact,
    final String? emergencyPhone,
    final int? status,
    final String? createTime,
    final int? realNameVerified,
    final String? realNameVerifyTime,
  }) = _$UserProfileModelImpl;
  const _UserProfileModel._() : super._();

  factory _UserProfileModel.fromJson(Map<String, dynamic> json) =
      _$UserProfileModelImpl.fromJson;

  @override
  int get id;
  @override
  String get phone;
  @override
  String? get nickname;
  @override
  String? get avatarUrl;
  @override
  int? get gender; // 0: 未设置, 1: 男, 2: 女
  @override
  String? get realName;
  @override
  String? get idCardNo;
  @override
  String? get birthday;
  @override
  String? get emergencyContact;
  @override
  String? get emergencyPhone;
  @override
  int? get status;
  @override
  String? get createTime;
  @override
  int? get realNameVerified; // 0-未认证，1-已认证
  @override
  String? get realNameVerifyTime;

  /// Create a copy of UserProfileModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserProfileModelImplCopyWith<_$UserProfileModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
