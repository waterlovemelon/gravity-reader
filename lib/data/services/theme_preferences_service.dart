import 'package:shared_preferences/shared_preferences.dart';
import 'package:myreader/core/constants/theme_constants.dart';

/// 主题偏好服务
/// 负责保存和加载用户选择的主题偏好
class ThemePreferencesService {
  static const String _keySelectedThemeId = 'selected_theme_id';
  static const String _keyAppThemeMode = 'app_theme_mode';
  final SharedPreferences _prefs;

  ThemePreferencesService(this._prefs);

  /// 保存用户选择的主题ID
  Future<bool> saveSelectedThemeId(String themeId) async {
    try {
      return await _prefs.setString(_keySelectedThemeId, themeId);
    } catch (e) {
      print('Error saving theme preference: $e');
      return false;
    }
  }

  /// 加载用户选择的主题ID
  /// 如果没有保存过，返回默认主题ID
  Future<String> loadSelectedThemeId() async {
    try {
      final themeId = _prefs.getString(_keySelectedThemeId);

      // 如果没有保存过，返回默认主题ID
      return themeId ?? ThemeConstants.themeIdBlue;
    } catch (e) {
      print('Error loading theme preference: $e');
      // 出错时返回默认主题ID
      return ThemeConstants.themeIdBlue;
    }
  }

  Future<bool> saveThemeMode(String themeMode) async {
    try {
      return await _prefs.setString(_keyAppThemeMode, themeMode);
    } catch (e) {
      print('Error saving theme mode: $e');
      return false;
    }
  }

  Future<String?> loadThemeMode() async {
    try {
      return _prefs.getString(_keyAppThemeMode);
    } catch (e) {
      print('Error loading theme mode: $e');
      return null;
    }
  }

  /// 清除主题偏好
  Future<bool> clearThemePreference() async {
    try {
      final selectedThemeRemoved = await _prefs.remove(_keySelectedThemeId);
      final themeModeRemoved = await _prefs.remove(_keyAppThemeMode);
      return selectedThemeRemoved && themeModeRemoved;
    } catch (e) {
      print('Error clearing theme preference: $e');
      return false;
    }
  }
}
