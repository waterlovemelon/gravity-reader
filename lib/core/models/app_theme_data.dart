import 'package:flutter/material.dart';

/// App主题数据模型
/// 定义应用的所有颜色配置
class AppThemeData {
  /// 品牌主色
  final Color primaryColor;

  /// 深版本主色（用于按钮底衬等）
  final Color primaryDarkColor;

  /// 辅助背景（阅读页背景）
  final Color readingBackgroundColor;

  /// 听书页面背景渐变顶部色
  final Color audiobookBgTop;

  /// 页面底色（列表页底色、设置页背景）
  final Color scaffoldBackgroundColor;

  /// 正文文字（书籍正文、主要标题）
  final Color textColor;

  /// 辅助文字（作者名、日期、底部标签栏未选中态）
  final Color secondaryTextColor;

  /// 进度条背景轨道色
  final Color progressTrackColor;

  /// 点缀色（收藏星星、会员标识、折扣标签）
  final Color accentColor;

  /// 卡片背景色
  final Color cardBackgroundColor;

  /// 分割线颜色
  final Color dividerColor;

  /// 圆角半径（小清新风格推荐12px以上）
  final double borderRadius;

  /// 主题名称
  final String name;

  /// 主题ID（用于持久化和切换）
  final String id;

  const AppThemeData({
    required this.primaryColor,
    this.primaryDarkColor = const Color(0xFF7A9068),
    required this.readingBackgroundColor,
    this.audiobookBgTop = const Color(0xFFE8F0E9),
    required this.scaffoldBackgroundColor,
    required this.textColor,
    required this.secondaryTextColor,
    this.progressTrackColor = const Color(0xFFE8E8E8),
    required this.accentColor,
    required this.cardBackgroundColor,
    required this.dividerColor,
    this.borderRadius = 12.0,
    required this.name,
    required this.id,
  });

  /// 转换为Flutter ThemeData
  ThemeData toThemeData({Brightness brightness = Brightness.light}) {
    final resolvedTheme = resolveBrightness(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: resolvedTheme.primaryColor,
            brightness: brightness,
          ).copyWith(
            primary: resolvedTheme.primaryColor,
            secondary: resolvedTheme.accentColor,
            surface: resolvedTheme.cardBackgroundColor,
            onPrimary: Colors.white,
            onSecondary: resolvedTheme.textColor,
            onSurface: resolvedTheme.textColor,
          ),
      scaffoldBackgroundColor: resolvedTheme.scaffoldBackgroundColor,
      cardColor: resolvedTheme.cardBackgroundColor,
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          color: resolvedTheme.textColor,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: resolvedTheme.textColor,
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: resolvedTheme.secondaryTextColor,
          fontSize: 12,
          height: 1.5,
        ),
        titleLarge: TextStyle(
          color: resolvedTheme.textColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: resolvedTheme.textColor,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          color: resolvedTheme.secondaryTextColor,
          fontSize: 12,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: resolvedTheme.scaffoldBackgroundColor,
        foregroundColor: resolvedTheme.textColor,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: resolvedTheme.cardBackgroundColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(resolvedTheme.borderRadius),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: resolvedTheme.dividerColor,
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: resolvedTheme.primaryColor,
          foregroundColor: Colors.white, // 主色按钮搭配白色文字
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(resolvedTheme.borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: resolvedTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(resolvedTheme.borderRadius),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: resolvedTheme.cardBackgroundColor,
        selectedItemColor: resolvedTheme.primaryColor,
        unselectedItemColor: resolvedTheme.secondaryTextColor,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  AppThemeData resolveBrightness(Brightness brightness) {
    if (brightness == Brightness.light) {
      return this;
    }

    return copyWith(
      primaryColor: _shiftLightness(primaryColor, 0.64),
      primaryDarkColor: _shiftLightness(primaryDarkColor, 0.52),
      readingBackgroundColor: Color.lerp(
        readingBackgroundColor,
        Colors.black,
        0.86,
      )!,
      audiobookBgTop: Color.lerp(audiobookBgTop, Colors.black, 0.82)!,
      scaffoldBackgroundColor: Color.lerp(
        scaffoldBackgroundColor,
        Colors.black,
        0.84,
      )!,
      textColor: Color.lerp(Colors.white, textColor, 0.12)!,
      secondaryTextColor: Color.lerp(Colors.white, secondaryTextColor, 0.34)!,
      progressTrackColor: Color.lerp(progressTrackColor, Colors.black, 0.68)!,
      accentColor: _shiftLightness(accentColor, 0.72),
      cardBackgroundColor: Color.lerp(cardBackgroundColor, Colors.black, 0.78)!,
      dividerColor: Color.lerp(dividerColor, Colors.white, 0.14)!,
    );
  }

  /// 获取阅读器专用主题
  ThemeData getReadingTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: readingBackgroundColor,
        onPrimary: Colors.white,
        onSecondary: textColor,
        onSurface: textColor,
      ),
      scaffoldBackgroundColor: readingBackgroundColor,
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          color: textColor,
          fontSize: 18,
          height: 1.8, // 阅读行高
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          color: secondaryTextColor,
          fontSize: 14,
          height: 1.6,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: readingBackgroundColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
    );
  }

  /// 复制主题并修改部分颜色
  AppThemeData copyWith({
    Color? primaryColor,
    Color? primaryDarkColor,
    Color? readingBackgroundColor,
    Color? audiobookBgTop,
    Color? scaffoldBackgroundColor,
    Color? textColor,
    Color? secondaryTextColor,
    Color? progressTrackColor,
    Color? accentColor,
    Color? cardBackgroundColor,
    Color? dividerColor,
    double? borderRadius,
    String? name,
    String? id,
  }) {
    return AppThemeData(
      primaryColor: primaryColor ?? this.primaryColor,
      primaryDarkColor: primaryDarkColor ?? this.primaryDarkColor,
      readingBackgroundColor:
          readingBackgroundColor ?? this.readingBackgroundColor,
      audiobookBgTop: audiobookBgTop ?? this.audiobookBgTop,
      scaffoldBackgroundColor:
          scaffoldBackgroundColor ?? this.scaffoldBackgroundColor,
      textColor: textColor ?? this.textColor,
      secondaryTextColor: secondaryTextColor ?? this.secondaryTextColor,
      progressTrackColor: progressTrackColor ?? this.progressTrackColor,
      accentColor: accentColor ?? this.accentColor,
      cardBackgroundColor: cardBackgroundColor ?? this.cardBackgroundColor,
      dividerColor: dividerColor ?? this.dividerColor,
      borderRadius: borderRadius ?? this.borderRadius,
      name: name ?? this.name,
      id: id ?? this.id,
    );
  }

  static Color _shiftLightness(Color color, double targetLightness) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(targetLightness.clamp(0.0, 1.0)).toColor();
  }
}
