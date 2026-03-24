import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/shared_preferences_provider.dart';
import 'package:myreader/core/constants/theme_constants.dart';
import 'package:myreader/core/models/app_theme_data.dart';
import 'package:myreader/data/services/theme_preferences_service.dart';

enum AppThemeMode { system, light, dark }

extension AppThemeModeX on AppThemeMode {
  ThemeMode get themeMode {
    switch (this) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  String get storageValue {
    switch (this) {
      case AppThemeMode.system:
        return 'system';
      case AppThemeMode.light:
        return 'light';
      case AppThemeMode.dark:
        return 'dark';
    }
  }

  static AppThemeMode fromStorageValue(String? value) {
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
      default:
        return AppThemeMode.system;
    }
  }
}

/// 主题偏好服务Provider
final themePreferencesServiceProvider = Provider<ThemePreferencesService>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ThemePreferencesService(prefs);
});

/// 主题状态类
class ThemeState {
  final AppThemeData currentTheme;
  final String themeId;
  final AppThemeMode themeMode;

  const ThemeState({
    required this.currentTheme,
    required this.themeId,
    required this.themeMode,
  });

  ThemeState copyWith({
    AppThemeData? currentTheme,
    String? themeId,
    AppThemeMode? themeMode,
  }) {
    return ThemeState(
      currentTheme: currentTheme ?? this.currentTheme,
      themeId: themeId ?? this.themeId,
      themeMode: themeMode ?? this.themeMode,
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
          themeMode: AppThemeMode.system,
        ),
      ) {
    // 初始化时加载用户保存的主题
    _loadThemePreference();
  }

  /// 从持久化存储加载主题偏好
  Future<void> _loadThemePreference() async {
    try {
      final themeId = await _preferencesService.loadSelectedThemeId();
      final themeMode = AppThemeModeX.fromStorageValue(
        await _preferencesService.loadThemeMode(),
      );
      final theme = _getThemeById(themeId);
      state = ThemeState(
        currentTheme: theme,
        themeId: themeId,
        themeMode: themeMode,
      );
    } catch (e) {
      print('Error loading theme: $e');
      // 出错时使用默认主题
      state = const ThemeState(
        currentTheme: ThemeConstants.defaultTheme,
        themeId: ThemeConstants.themeIdGreenFresh,
        themeMode: AppThemeMode.system,
      );
    }
  }

  /// 切换主题
  Future<void> switchTheme(String themeId) async {
    try {
      // 获取主题数据
      final theme = _getThemeById(themeId);

      // 更新状态
      state = state.copyWith(currentTheme: theme, themeId: themeId);

      // 保存到持久化存储
      await _preferencesService.saveSelectedThemeId(themeId);
    } catch (e) {
      print('Error switching theme: $e');
      throw Exception('切换主题失败: $e');
    }
  }

  Future<void> switchThemeMode(AppThemeMode themeMode) async {
    try {
      state = state.copyWith(themeMode: themeMode);
      await _preferencesService.saveThemeMode(themeMode.storageValue);
    } catch (e) {
      print('Error switching theme mode: $e');
      throw Exception('切换主题模式失败: $e');
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

final systemBrightnessProvider = StateProvider<Brightness>((ref) {
  return WidgetsBinding.instance.platformDispatcher.platformBrightness;
});

final appThemeModeProvider = Provider<AppThemeMode>((ref) {
  return ref.watch(themeProvider).themeMode;
});

final effectiveBrightnessProvider = Provider<Brightness>((ref) {
  final themeMode = ref.watch(appThemeModeProvider);
  final systemBrightness = ref.watch(systemBrightnessProvider);

  switch (themeMode) {
    case AppThemeMode.light:
      return Brightness.light;
    case AppThemeMode.dark:
      return Brightness.dark;
    case AppThemeMode.system:
      return systemBrightness;
  }
});

/// 主题数据Provider
/// 直接提供当前主题数据
final currentThemeProvider = Provider<AppThemeData>((ref) {
  final themeState = ref.watch(themeProvider);
  final brightness = ref.watch(effectiveBrightnessProvider);
  return themeState.currentTheme.resolveBrightness(brightness);
});

/// 当前主题ID Provider
final currentThemeIdProvider = Provider<String>((ref) {
  return ref.watch(themeProvider).themeId;
});
