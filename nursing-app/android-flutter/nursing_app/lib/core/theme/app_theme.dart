import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 应用主题配置
///
/// 定义亮色和暗色主题
class AppTheme {
  AppTheme._();

  // ==================== 颜色定义 ====================

  /// 主题色 - 护理蓝
  static const Color primaryColor = Color(0xFF2196F3);

  /// 次要色 - 温馨橙
  static const Color secondaryColor = Color(0xFFFF9800);

  /// 成功色
  static const Color successColor = Color(0xFF4CAF50);

  /// 警告色
  static const Color warningColor = Color(0xFFFFC107);

  /// 错误色
  static const Color errorColor = Color(0xFFF44336);

  /// 背景色
  static const Color backgroundColor = Color(0xFFF5F5F5);

  /// 卡片背景色
  static const Color cardColor = Colors.white;

  /// 文字颜色
  static const Color textPrimaryColor = Color(0xFF212121);
  static const Color textSecondaryColor = Color(0xFF757575);
  static const Color textHintColor = Color(0xFFBDBDBD);

  /// 分割线颜色
  static const Color dividerColor = Color(0xFFE0E0E0);

  // ==================== 亮色主题 ====================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,

      // 颜色方案
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: cardColor,
      ),

      // AppBar 主题
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: textPrimaryColor,
        titleTextStyle: TextStyle(
          color: textPrimaryColor,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: textPrimaryColor),
      ),

      // 卡片主题
      cardTheme: CardThemeData(
        elevation: 2,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),

      // 按钮主题
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          textStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
      ),

      // 输入框主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: errorColor),
        ),
        hintStyle: TextStyle(color: textHintColor, fontSize: 14.sp),
      ),

      // 底部导航栏主题
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondaryColor,
        selectedLabelStyle: TextStyle(fontSize: 12.sp),
        unselectedLabelStyle: TextStyle(fontSize: 12.sp),
        elevation: 8,
      ),

      // 分割线主题
      dividerTheme: const DividerThemeData(color: dividerColor, thickness: 0.5),

      // 文字主题
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28.sp,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 24.sp,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        headlineSmall: TextStyle(
          fontSize: 20.sp,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
        titleLarge: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
        titleMedium: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
        titleSmall: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
        bodyLarge: TextStyle(fontSize: 16.sp, color: textPrimaryColor),
        bodyMedium: TextStyle(fontSize: 14.sp, color: textPrimaryColor),
        bodySmall: TextStyle(fontSize: 12.sp, color: textSecondaryColor),
        labelLarge: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
      ),
    );
  }

  // ==================== 暗色主题 ====================

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFF121212),

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: secondaryColor,
        error: errorColor,
        surface: const Color(0xFF1E1E1E),
      ),

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: TextStyle(fontSize: 12.sp),
        unselectedLabelStyle: TextStyle(fontSize: 12.sp),
        elevation: 8,
      ),
    );
  }
}
