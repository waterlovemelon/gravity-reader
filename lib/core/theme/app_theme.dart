import 'package:flutter/material.dart';
import 'package:myreader/core/constants/theme_constants.dart';
import 'package:myreader/core/models/app_theme_data.dart';

/// App主题工具类
/// 提供主题相关的工具方法
class AppTheme {
  /// 获取主题数据（兼容旧代码）
  /// @deprecated 请使用 themeProvider.currentTheme 代替
  static ThemeData get lightTheme => ThemeConstants.defaultTheme.toThemeData();

  /// 获取深色主题数据
  /// 注意：当前主题系统主要支持浅色主题
  /// @deprecated 请使用 themeProvider 代替
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ThemeConstants.greenFreshPrimary,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  /// 根据主题ID获取主题数据
  static AppThemeData getThemeById(String themeId) {
    for (final theme in ThemeConstants.allThemes) {
      if (theme.id == themeId) {
        return theme;
      }
    }
    return ThemeConstants.defaultTheme;
  }

  /// 获取所有可用主题
  static List<AppThemeData> getAllThemes() {
    return ThemeConstants.allThemes;
  }

  /// 获取默认主题
  static AppThemeData getDefaultTheme() {
    return ThemeConstants.defaultTheme;
  }
}
