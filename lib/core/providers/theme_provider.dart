import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/constants/theme_constants.dart';
import 'package:myreader/core/models/app_theme_data.dart';
import 'package:myreader/data/services/theme_preferences_service.dart';

/// 主题偏好服务Provider
final themePreferencesServiceProvider = Provider<ThemePreferencesService>((
  ref,
) {
  return ThemePreferencesService();
});

/// 主题状态类
class ThemeState {
  final AppThemeData currentTheme;
  final String themeId;

  const ThemeState({required this.currentTheme, required this.themeId});

  ThemeState copyWith({AppThemeData? currentTheme, String? themeId}) {
    return ThemeState(
      currentTheme: currentTheme ?? this.currentTheme,
      themeId: themeId ?? this.themeId,
    );
  }
}

/// 主题StateNotifier
/// 负责管理主题状态和切换逻辑
class ThemeNotifier extends StateNotifier<ThemeState> {
  final ThemePreferencesService _preferencesService;

  ThemeNotifier(this._preferencesService)
    : super(
        const ThemeState(
          currentTheme: ThemeConstants.defaultTheme,
          themeId: ThemeConstants.themeIdGreenFresh,
        ),
      ) {
    // 初始化时加载用户保存的主题
    _loadThemePreference();
  }

  /// 从持久化存储加载主题偏好
  Future<void> _loadThemePreference() async {
    try {
      final themeId = await _preferencesService.loadSelectedThemeId();
      final theme = _getThemeById(themeId);
      state = ThemeState(currentTheme: theme, themeId: themeId);
    } catch (e) {
      print('Error loading theme: $e');
      // 出错时使用默认主题
      state = ThemeState(
        currentTheme: ThemeConstants.defaultTheme,
        themeId: ThemeConstants.themeIdGreenFresh,
      );
    }
  }

  /// 切换主题
  Future<void> switchTheme(String themeId) async {
    try {
      // 获取主题数据
      final theme = _getThemeById(themeId);

      // 更新状态
      state = ThemeState(currentTheme: theme, themeId: themeId);

      // 保存到持久化存储
      await _preferencesService.saveSelectedThemeId(themeId);
    } catch (e) {
      print('Error switching theme: $e');
      throw Exception('切换主题失败: $e');
    }
  }

  /// 根据ID获取主题
  AppThemeData _getThemeById(String themeId) {
    for (final theme in ThemeConstants.allThemes) {
      if (theme.id == themeId) {
        return theme;
      }
    }

    // 如果找不到，返回默认主题
    return ThemeConstants.defaultTheme;
  }

  /// 获取所有可用主题
  List<AppThemeData> getAvailableThemes() {
    return ThemeConstants.allThemes;
  }
}

/// 主题Provider
/// 提供主题状态和切换方法
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  final preferencesService = ref.watch(themePreferencesServiceProvider);
  return ThemeNotifier(preferencesService);
});

/// 主题数据Provider
/// 直接提供当前主题数据
final currentThemeProvider = Provider<AppThemeData>((ref) {
  return ref.watch(themeProvider).currentTheme;
});

/// 当前主题ID Provider
final currentThemeIdProvider = Provider<String>((ref) {
  return ref.watch(themeProvider).themeId;
});
