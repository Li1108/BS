import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../data/models/user_profile_model.dart';
import '../data/repositories/user_repository.dart';

part 'user_profile_provider.freezed.dart';

/// 用户资料状态
@freezed
class UserProfileState with _$UserProfileState {
  const factory UserProfileState({
    UserProfileModel? profile,
    @Default(false) bool isLoading,
    String? error,
  }) = _UserProfileState;
}

/// 用户资料提供者
class UserProfileNotifier extends StateNotifier<UserProfileState> {
  final UserRepository _repository;

  UserProfileNotifier(this._repository) : super(const UserProfileState());

  /// 加载用户资料
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _repository.getProfile();
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 更新用户资料
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final updatedProfile = await _repository.updateProfile(data);
      if (updatedProfile != null) {
        state = state.copyWith(
          profile: updatedProfile,
          isLoading: false,
          error: null,
        );
      } else {
        await loadProfile();
      }
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 上传头像并同步到个人资料
  Future<String?> uploadAvatar(File file) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final avatarUrl = await _repository.uploadAvatar(file);
      await _repository.updateProfile({'avatarUrl': avatarUrl});
      await loadProfile();
      return avatarUrl;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }
}

/// 用户资料提供者实例
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
      return UserProfileNotifier(UserRepository());
    });
