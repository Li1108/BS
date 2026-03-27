import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../network/http_client.dart';
import '../services/storage_service.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/data/repositories/auth_repository.dart';

// 导出账户禁用异常以便其他地方使用
export '../../features/auth/data/repositories/auth_repository.dart'
    show AccountDisabledException;

part 'auth_provider.freezed.dart';

/// 用户角色枚举
enum UserRole {
  /// 普通用户
  user('USER'),

  /// 护士
  nurse('NURSE'),

  /// 管理员
  admin('ADMIN');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.user,
    );
  }
}

/// 认证状态
@freezed
class AuthState with _$AuthState {
  const factory AuthState({
    /// 是否正在加载
    @Default(false) bool isLoading,

    /// 是否已认证
    @Default(false) bool isAuthenticated,

    /// 当前用户信息
    UserModel? user,

    /// 用户角色
    UserRole? role,

    /// 错误信息
    String? errorMessage,

    /// JWT Token
    String? token,
  }) = _AuthState;
}

/// 认证状态 Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  final AuthRepository _authRepository;
  final StorageService _storageService;

  AuthNotifier(this.ref)
    : _authRepository = AuthRepository(),
      _storageService = StorageService.instance,
      super(const AuthState()) {
    // 初始化时检查本地存储的认证状态
    _checkAuthStatus();
  }

  bool _isAccountDisabledError(Object error) {
    if (error is AccountDisabledException) {
      return true;
    }

    final message = error.toString().toLowerCase();
    return message.contains('禁用') || message.contains('封禁');
  }

  /// 检查认证状态
  Future<void> _checkAuthStatus() async {
    state = state.copyWith(isLoading: true);

    try {
      final token = await _storageService.getToken();
      final userJson = await _storageService.getUser();

      if (token != null && userJson != null) {
        try {
          final latestUser = await _authRepository.getCurrentUser();
          if (latestUser.status == 0) {
            await _storageService.clearAuth();
            state = state.copyWith(
              isLoading: false,
              isAuthenticated: false,
              errorMessage: '您的账户已被禁用，请联系客服处理',
            );
            return;
          }

          await _storageService.saveUser(latestUser.toJson());
          final role = UserRole.fromString(latestUser.role ?? 'USER');
          state = state.copyWith(
            isLoading: false,
            isAuthenticated: true,
            user: latestUser,
            role: role,
            token: token,
          );
        } catch (e) {
          await _storageService.clearAuth();
          state = state.copyWith(
            isLoading: false,
            isAuthenticated: false,
            errorMessage: _isAccountDisabledError(e) ? '账号已禁用' : null,
          );
        }
      } else {
        state = state.copyWith(isLoading: false, isAuthenticated: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: '检查认证状态失败: $e',
      );
    }
  }

  /// 发送短信验证码
  Future<bool> sendVerificationCode(String phone) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _authRepository.sendVerificationCode(phone);
      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      final baseMessage =
          '发送验证码失败: ${e.toString().replaceAll('Exception: ', '')}';
      final hint = ApiConfig.realDeviceBaseUrlHint;
      final errorMessage = hint == null ? baseMessage : '$baseMessage。$hint';
      state = state.copyWith(isLoading: false, errorMessage: errorMessage);
      return false;
    }
  }

  /// 手机号验证码登录
  Future<bool> loginWithPhone(
    String phone,
    String code, {
    String loginRole = 'USER',
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _authRepository.loginWithPhone(
        phone,
        code,
        role: loginRole,
      );
      final user = response.user;
      final token = response.token;

      // 检查账户状态（status=0表示禁用）
      if (user.status == 0) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: '您的账户已被禁用，请联系客服处理',
        );
        return false;
      }

      // 保存到本地存储（后续护士校验依赖 token）
      await _storageService.saveToken(token);
      await _storageService.saveUser(user.toJson());

      final userRole = UserRole.fromString(user.role ?? 'USER');

      if (loginRole == 'NURSE') {
        if (userRole != UserRole.nurse) {
          await _storageService.clearAuth();
          state = const AuthState(
            isLoading: false,
            isAuthenticated: false,
            errorMessage: '该账号不是护士身份，请先提交护士入驻申请并等待审核通过',
          );
          return false;
        }

        try {
          final nurseProfile = await _authRepository.getNurseProfile();
          if (!nurseProfile.isApproved) {
            await _storageService.clearAuth();
            final auditMessage = nurseProfile.auditStatus == 2
                ? '护士资质审核未通过，请按驳回原因修改后重新提交'
                : '护士资质待审核，审核通过后方可登录护士端';
            state = AuthState(
              isLoading: false,
              isAuthenticated: false,
              errorMessage: auditMessage,
            );
            return false;
          }
        } catch (_) {
          await _storageService.clearAuth();
          state = const AuthState(
            isLoading: false,
            isAuthenticated: false,
            errorMessage: '请先提交护士入驻申请并等待审核通过',
          );
          return false;
        }
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
        role: userRole,
        token: token,
      );

      return true;
    } on AccountDisabledException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      String errorMessage = '登录失败';
      if (e.toString().contains('验证码')) {
        errorMessage = '验证码错误或已过期，请重新获取';
      } else if (e.toString().contains('网络') ||
          e.toString().contains('connect')) {
        errorMessage = '网络连接失败，请检查网络设置';
      } else {
        errorMessage = '登录失败: ${e.toString().replaceAll('Exception: ', '')}';
      }
      final hint = ApiConfig.realDeviceBaseUrlHint;
      if (hint != null) {
        errorMessage = '$errorMessage。$hint';
      }
      state = state.copyWith(isLoading: false, errorMessage: errorMessage);
      return false;
    }
  }

  /// 注册用户
  Future<bool> register({
    required String phone,
    required String code,
    required String username,
    String role = 'USER',
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _authRepository.register(
        phone: phone,
        code: code,
        username: username,
        role: role,
      );

      final user = response.user;
      final token = response.token;

      // 保存到本地存储
      await _storageService.saveToken(token);
      await _storageService.saveUser(user.toJson());

      final userRole = UserRole.fromString(user.role ?? 'USER');

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
        role: userRole,
        token: token,
      );

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '注册失败: $e');
      return false;
    }
  }

  /// 查询当前用户是否已实名认证
  Future<bool> isCurrentUserRealNameVerified() async {
    if (!state.isAuthenticated) return false;
    try {
      return await _authRepository.getRealNameVerifiedStatus();
    } catch (_) {
      return false;
    }
  }

  /// 提交实名认证
  Future<bool> verifyRealName({
    required String realName,
    required String idCardNo,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final success = await _authRepository.verifyRealName(
        realName: realName,
        idCardNo: idCardNo,
      );
      state = state.copyWith(isLoading: false);
      return success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// 退出登录
  Future<void> logout() async {
    await _storageService.clearAuth();

    state = const AuthState(isLoading: false, isAuthenticated: false);
  }

  /// 退出其他设备（当前设备保持登录）
  Future<bool> logoutOtherDevices() async {
    if (!state.isAuthenticated) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final newToken = await _authRepository.logoutOtherDevices();
      await _storageService.saveToken(newToken);
      state = state.copyWith(isLoading: false, token: newToken);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// 更新用户信息
  void updateUser(UserModel user) {
    state = state.copyWith(user: user);
    _storageService.saveUser(user.toJson());
  }

  /// 检查是否为护士
  bool get isNurse => state.role == UserRole.nurse;

  /// 检查是否为普通用户
  bool get isUser => state.role == UserRole.user;

  /// 获取首页路由
  String getHomeRoute() {
    if (!state.isAuthenticated) {
      return '/login';
    }

    switch (state.role) {
      case UserRole.nurse:
        return '/nurse-home';
      case UserRole.user:
      default:
        return '/user-home';
    }
  }
}

/// 认证状态 Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// 当前用户 Provider
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});

/// 用户角色 Provider
final userRoleProvider = Provider<UserRole?>((ref) {
  return ref.watch(authProvider).role;
});

/// 是否已登录 Provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

/// 是否为护士 Provider
final isNurseProvider = Provider<bool>((ref) {
  return ref.watch(userRoleProvider) == UserRole.nurse;
});
