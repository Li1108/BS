import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

/// 权限管理服务
///
/// 使用 permission_handler 统一管理应用权限
/// 支持位置、通知、相机、相册等权限
class PermissionService {
  PermissionService._internal();

  static final PermissionService instance = PermissionService._internal();

  final Logger _logger = Logger();

  // ==================== 位置权限 ====================

  /// 检查位置权限
  Future<bool> hasLocationPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// 请求位置权限
  Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();

    if (status.isGranted) {
      _logger.i('位置权限已授予');
      return true;
    } else if (status.isPermanentlyDenied) {
      _logger.w('位置权限被永久拒绝');
      return false;
    } else {
      _logger.w('位置权限被拒绝');
      return false;
    }
  }

  /// 请求始终使用位置权限（后台定位）
  Future<bool> requestAlwaysLocationPermission() async {
    // 先请求基本位置权限
    final basicStatus = await Permission.location.request();
    if (!basicStatus.isGranted) return false;

    // 再请求后台位置权限
    final alwaysStatus = await Permission.locationAlways.request();
    return alwaysStatus.isGranted;
  }

  // ==================== 通知权限 ====================

  /// 检查通知权限
  Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// 请求通知权限
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();

    if (status.isGranted) {
      _logger.i('通知权限已授予');
      return true;
    } else {
      _logger.w('通知权限被拒绝');
      return false;
    }
  }

  // ==================== 相机权限 ====================

  /// 检查相机权限
  Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// 请求相机权限
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      _logger.i('相机权限已授予');
      return true;
    } else {
      _logger.w('相机权限被拒绝');
      return false;
    }
  }

  // ==================== 相册权限 ====================

  /// 检查相册权限
  Future<bool> hasPhotosPermission() async {
    final status = await Permission.photos.status;
    return status.isGranted;
  }

  /// 请求相册权限
  Future<bool> requestPhotosPermission() async {
    final status = await Permission.photos.request();

    if (status.isGranted) {
      _logger.i('相册权限已授予');
      return true;
    } else {
      _logger.w('相册权限被拒绝');
      return false;
    }
  }

  // ==================== 存储权限 ====================

  /// 检查存储权限（Android）
  Future<bool> hasStoragePermission() async {
    final status = await Permission.storage.status;
    return status.isGranted;
  }

  /// 请求存储权限
  Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  // ==================== 批量权限 ====================

  /// 请求应用所需的基础权限
  Future<Map<Permission, bool>> requestBasicPermissions() async {
    final permissions = [Permission.location, Permission.notification];

    final statuses = await permissions.request();

    final results = <Permission, bool>{};
    statuses.forEach((permission, status) {
      results[permission] = status.isGranted;
      _logger.i(
        '${permission.toString()}: ${status.isGranted ? "已授予" : "被拒绝"}',
      );
    });

    return results;
  }

  /// 请求拍照上传相关权限
  Future<bool> requestPhotoUploadPermissions() async {
    final statuses = await [Permission.camera, Permission.photos].request();

    return statuses.values.every((status) => status.isGranted);
  }

  // ==================== 权限状态检查 ====================

  /// 检查权限是否被永久拒绝
  Future<bool> isPermanentlyDenied(Permission permission) async {
    final status = await permission.status;
    return status.isPermanentlyDenied;
  }

  /// 打开应用设置页面
  Future<bool> openSettings() async {
    return await openAppSettings();
  }

  // ==================== 权限请求对话框 ====================

  /// 显示权限请求对话框
  Future<bool> showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required Permission permission,
    bool openSettingsOnDeny = true,
  }) async {
    // 先检查权限状态
    final status = await permission.status;
    if (status.isGranted) return true;

    // 如果被永久拒绝，引导用户到设置页面
    if (status.isPermanentlyDenied && openSettingsOnDeny) {
      if (!context.mounted) return false;
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text('$message\n\n请在系统设置中开启权限。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('去设置'),
            ),
          ],
        ),
      );

      if (goToSettings == true) {
        await openAppSettings();
      }
      return false;
    }

    // 显示权限说明对话框
    if (!context.mounted) return false;
    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('暂不开启'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('立即开启'),
          ),
        ],
      ),
    );

    if (shouldRequest == true) {
      final result = await permission.request();
      return result.isGranted;
    }

    return false;
  }

  /// 显示位置权限请求对话框
  Future<bool> showLocationPermissionDialog(BuildContext context) async {
    return await showPermissionDialog(
      context,
      title: '需要位置权限',
      message: '为了提供精准的上门服务，我们需要获取您的位置信息来匹配附近的护士。',
      permission: Permission.location,
    );
  }

  /// 显示通知权限请求对话框
  Future<bool> showNotificationPermissionDialog(BuildContext context) async {
    return await showPermissionDialog(
      context,
      title: '开启通知',
      message: '开启通知权限后，您可以及时收到订单状态更新、护士到达提醒等重要消息。',
      permission: Permission.notification,
    );
  }

  /// 显示相机权限请求对话框
  Future<bool> showCameraPermissionDialog(BuildContext context) async {
    return await showPermissionDialog(
      context,
      title: '需要相机权限',
      message: '拍摄护理现场照片需要使用相机功能。',
      permission: Permission.camera,
    );
  }
}
