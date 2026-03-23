import 'package:flutter/material.dart';
import 'package:myreader/core/models/app_theme_data.dart';

class ThemeConstants {
  // ========== 字体大小 ==========
  static const double fontSizeSmall = 12.0;
  static const double fontSizeNormal = 14.0;
  static const double fontSizeLarge = 16.0;

  // ========== 阅读主题类型（用于阅读器内部的主题切换） ==========
  static const int readingThemeLight = 1;
  static const int readingThemeDark = 2;
  static const int readingThemeSepia = 3;
  static const int readingThemeNight = 4;

  // ========== 主题主题ID定义 ==========
  static const String themeIdGreenFresh = 'green_fresh'; // 小清新绿色主题（默认）
  static const String themeIdBlueProfessional = 'blue_professional'; // 职感蓝色主题

  // ========== 小清新绿色主题配色 ==========
  /// 品牌主色 - 鼠尾草绿（优化后：降低饱和度，更清新）
  /// 用途：Logo、顶部导航栏、功能按钮、选中状态、进度条
  static const Color greenFreshPrimary = Color(0xFF9CAF88);

  /// 深版本主色 - 用于按钮底衬
  static const Color greenFreshPrimaryDark = Color(0xFF7A9068);

  /// 辅助背景 - 薄荷奶白（优化后：听书/阅读页专用背景，纸张质感）
  /// 用途：阅读页背景、听书页面背景（极度护眼）
  static const Color greenFreshReadingBg = Color(0xFFF1F4EE);

  /// 听书背景渐变顶部色 - 为听书页面添加微弱渐变
  static const Color greenFreshAudiobookBgTop = Color(0xFFE8F0E9);

  /// 页面底色 - 极简浅灰
  /// 用途：列表页底色、设置页背景
  static const Color greenFreshScaffoldBg = Color(0xFFF8FAF7);

  /// 正文文字 - 深森林灰
  /// 用途：书籍正文、主要标题（比纯黑更温和）
  static const Color greenFreshText = Color(0xFF2D352B);

  /// 辅助文字 - 灰绿调
  /// 用途：作者名、日期、底部标签栏未选中态
  static const Color greenFreshSecondaryText = Color(0xFF7A8A76);

  /// 进度条背景 - 极淡灰色
  /// 用途：进度条背景轨道
  static const Color greenFreshProgressTrack = Color(0xFFE8E8E8);

  /// 点缀色 - 暖杏黄
  /// 用途：收藏星星、会员标识、折扣标签
  static const Color greenFreshAccent = Color(0xFFE9D5A3);

  /// 卡片背景色 - 纯白
  static const Color greenFreshCardBg = Color(0xFFFFFFFF);

  /// 分割线颜色 - 淡灰绿
  static const Color greenFreshDivider = Color(0xFFE8F0EC);

  // ========== 职感蓝色主题配色 ==========
  /// 品牌主色 - 雾霾蓝
  /// 用途：Logo、按钮、底部Tab激活、分类标签
  static const Color blueProfessionalPrimary = Color(0xFF8BAABB);

  /// 阅读背景 - 纸感浅蓝
  /// 用途：阅读器背景（微蓝调，清冷且极度纯净）
  static const Color blueProfessionalReadingBg = Color(0xFFEDF2F4);

  /// 页面底色 - 极简冰灰
  /// 用途：发现页底色、列表分割背景
  static const Color blueProfessionalScaffoldBg = Color(0xFFF4F7F9);

  /// 正文文字 - 深海黛蓝
  /// 用途：替代纯黑，文字深邃且极具质感
  static const Color blueProfessionalText = Color(0xFF2A363D);

  /// 辅助文字 - 灰蓝调
  /// 用途：副标题、未选中图标、提示信息
  static const Color blueProfessionalSecondaryText = Color(0xFF748A96);

  /// 点缀色 - 夕阳橘
  /// 用途：徽章、价格、重要警示（蓝色的互补色）
  static const Color blueProfessionalAccent = Color(0xFFE9A88F);

  /// 卡片背景色 - 纯白
  static const Color blueProfessionalCardBg = Color(0xFFFFFFFF);

  /// 分割线颜色 - 淡冰蓝
  static const Color blueProfessionalDivider = Color(0xFFE1E8EC);

  // ========== 主题定义 ==========

  /// 小清新绿色主题
  static const AppThemeData greenFreshTheme = AppThemeData(
    primaryColor: greenFreshPrimary,
    primaryDarkColor: Color(0xFF8BA278),
    readingBackgroundColor: greenFreshReadingBg,
    audiobookBgTop: Color(0xFFE8F0E9),
    scaffoldBackgroundColor: greenFreshScaffoldBg,
    textColor: greenFreshText,
    secondaryTextColor: greenFreshSecondaryText,
    progressTrackColor: Color(0xFFE8E8E8),
    accentColor: greenFreshAccent,
    cardBackgroundColor: greenFreshCardBg,
    dividerColor: greenFreshDivider,
    borderRadius: 12.0, // 大圆角，显得更亲切
    name: '小清新绿',
    id: themeIdGreenFresh,
  );

  /// 职感蓝色主题
  /// 视觉感受：比绿色方案更具理性和现代感
  /// 适用场景：硬核知识、科技资讯或悬疑小说
  static const AppThemeData blueProfessionalTheme = AppThemeData(
    primaryColor: blueProfessionalPrimary,
    primaryDarkColor: Color(0xFF6F8795),
    readingBackgroundColor: blueProfessionalReadingBg,
    audiobookBgTop: Color(0xFFE5EDF1),
    scaffoldBackgroundColor: blueProfessionalScaffoldBg,
    textColor: blueProfessionalText,
    secondaryTextColor: blueProfessionalSecondaryText,
    progressTrackColor: Color(0xFFD9E2E7),
    accentColor: blueProfessionalAccent,
    cardBackgroundColor: blueProfessionalCardBg,
    dividerColor: blueProfessionalDivider,
    borderRadius: 12.0, // 保持统一的大圆角设计
    name: '职感蓝',
    id: themeIdBlueProfessional,
  );

  // ========== 默认主题 ==========
  static const AppThemeData defaultTheme = greenFreshTheme;

  // ========== 所有可用主题列表 ==========
  static const List<AppThemeData> allThemes = [
    greenFreshTheme,
    blueProfessionalTheme,
    // 后续可以在这里添加更多主题
  ];
}
