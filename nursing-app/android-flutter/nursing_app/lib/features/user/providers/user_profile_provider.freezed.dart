// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_profile_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$UserProfileState {
  UserProfileModel? get profile => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of UserProfileState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserProfileStateCopyWith<UserProfileState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserProfileStateCopyWith<$Res> {
  factory $UserProfileStateCopyWith(
    UserProfileState value,
    $Res Function(UserProfileState) then,
  ) = _$UserProfileStateCopyWithImpl<$Res, UserProfileState>;
  @useResult
  $Res call({UserProfileModel? profile, bool isLoading, String? error});

  $UserProfileModelCopyWith<$Res>? get profile;
}

/// @nodoc
class _$UserProfileStateCopyWithImpl<$Res, $Val extends UserProfileState>
    implements $UserProfileStateCopyWith<$Res> {
  _$UserProfileStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserProfileState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? profile = freezed,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            profile: freezed == profile
                ? _value.profile
                : profile // ignore: cast_nullable_to_non_nullable
                      as UserProfileModel?,
            isLoading: null == isLoading
                ? _value.isLoading
                : isLoading // ignore: cast_nullable_to_non_nullable
                      as bool,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }

  /// Create a copy of UserProfileState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $UserProfileModelCopyWith<$Res>? get profile {
    if (_value.profile == null) {
      return null;
    }

    return $UserProfileModelCopyWith<$Res>(_value.profile!, (value) {
      return _then(_value.copyWith(profile: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$UserProfileStateImplCopyWith<$Res>
    implements $UserProfileStateCopyWith<$Res> {
  factory _$$UserProfileStateImplCopyWith(
    _$UserProfileStateImpl value,
    $Res Function(_$UserProfileStateImpl) then,
  ) = __$$UserProfileStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({UserProfileModel? profile, bool isLoading, String? error});

  @override
  $UserProfileModelCopyWith<$Res>? get profile;
}

/// @nodoc
class __$$UserProfileStateImplCopyWithImpl<$Res>
    extends _$UserProfileStateCopyWithImpl<$Res, _$UserProfileStateImpl>
    implements _$$UserProfileStateImplCopyWith<$Res> {
  __$$UserProfileStateImplCopyWithImpl(
    _$UserProfileStateImpl _value,
    $Res Function(_$UserProfileStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserProfileState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? profile = freezed,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(
      _$UserProfileStateImpl(
        profile: freezed == profile
            ? _value.profile
            : profile // ignore: cast_nullable_to_non_nullable
                  as UserProfileModel?,
        isLoading: null == isLoading
            ? _value.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$UserProfileStateImpl implements _UserProfileState {
  const _$UserProfileStateImpl({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  @override
  final UserProfileModel? profile;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  @override
  String toString() {
    return 'UserProfileState(profile: $profile, isLoading: $isLoading, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserProfileStateImpl &&
            (identical(other.profile, profile) || other.profile == profile) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(runtimeType, profile, isLoading, error);

  /// Create a copy of UserProfileState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserProfileStateImplCopyWith<_$UserProfileStateImpl> get copyWith =>
      __$$UserProfileStateImplCopyWithImpl<_$UserProfileStateImpl>(
        this,
        _$identity,
      );
}

abstract class _UserProfileState implements UserProfileState {
  const factory _UserProfileState({
    final UserProfileModel? profile,
    final bool isLoading,
    final String? error,
  }) = _$UserProfileStateImpl;

  @override
  UserProfileModel? get profile;
  @override
  bool get isLoading;
  @override
  String? get error;

  /// Create a copy of UserProfileState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserProfileStateImplCopyWith<_$UserProfileStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
