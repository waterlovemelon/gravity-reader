import 'package:shared_preferences/shared_preferences.dart';
import 'package:myreader/core/constants/theme_constants.dart';

/// 主题偏好服务
/// 负责保存和加载用户选择的主题偏好
class ThemePreferencesService {
  static const String _keySelectedThemeId = 'selected_theme_id';

  /// 保存用户选择的主题ID
  Future<bool> saveSelectedThemeId(String themeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_keySelectedThemeId, themeId);
    } catch (e) {
      print('Error saving theme preference: $e');
      return false;
    }
  }

  /// 加载用户选择的主题ID
  /// 如果没有保存过，返回默认主题ID
  Future<String> loadSelectedThemeId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeId = prefs.getString(_keySelectedThemeId);

      // 如果没有保存过，返回默认主题ID
      return themeId ?? ThemeConstants.themeIdGreenFresh;
    } catch (e) {
      print('Error loading theme preference: $e');
      // 出错时返回默认主题ID
      return ThemeConstants.themeIdGreenFresh;
    }
  }

  /// 清除主题偏好
  Future<bool> clearThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_keySelectedThemeId);
    } catch (e) {
      print('Error clearing theme preference: $e');
      return false;
    }
  }
}
