import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_theme.dart';

class AppSkeletonLine extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const AppSkeletonLine({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height.h,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(radius.r),
      ),
    );
  }
}

class AppListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  const AppListSkeleton({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 116,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        return Container(
          height: itemHeight.h,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54.w,
                height: 54.w,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: const [
                    AppSkeletonLine(width: 150, height: 13),
                    AppSkeletonLine(width: 210, height: 11),
                    AppSkeletonLine(width: 120, height: 11),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              const AppSkeletonLine(width: 48, height: 16),
            ],
          ),
        );
      },
    );
  }
}

class AppRetryGuide extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryText;
  final IconData icon;

  const AppRetryGuide({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryText = '重试',
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 24.w),
        padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 18.h),
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
            Icon(icon, size: 44.sp, color: AppTheme.textHintColor),
            SizedBox(height: 12.h),
            Text(
              title,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: AppTheme.textSecondaryColor),
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retryText),
            ),
          ],
        ),
      ),
    );
  }
}

class AppConfirmSheet {
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = '确认',
    String cancelText = '取消',
    IconData icon = Icons.help_outline_rounded,
    Color iconBgColor = const Color(0x332196F3),
    Color iconColor = AppTheme.primaryColor,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 10.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor),
                ),
                SizedBox(height: 10.h),
                Text(
                  title,
                  style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppTheme.textSecondaryColor,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(cancelText),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(confirmText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }
}
