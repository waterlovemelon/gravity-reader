import 'package:flutter/material.dart';
import 'package:myreader/core/models/app_theme_data.dart';

class ThemeConstants {
  static const double fontSizeSmall = 12.0;
  static const double fontSizeNormal = 14.0;
  static const double fontSizeLarge = 16.0;

  static const int readingThemeLight = 1;
  static const int readingThemeDark = 2;
  static const int readingThemeSepia = 3;
  static const int readingThemeNight = 4;

  static const String themeIdRose = 'rose';
  static const String themeIdOrange = 'orange';
  static const String themeIdYellow = 'yellow';
  static const String themeIdGreen = 'green';
  static const String themeIdTeal = 'teal';
  static const String themeIdBlue = 'blue';
  static const String themeIdIndigo = 'indigo';
  static const String themeIdPurple = 'purple';
  static const String themeIdGray = 'gray';

  static const Color _fixedReadingBg = Color(0xFFEDF2F4);
  static const Color _fixedAudiobookBgTop = Color(0xFFE5EDF1);
  static const Color _fixedText = Color(0xFF2A363D);
  static const Color _fixedSecondaryText = Color(0xFF748A96);
  static const Color _fixedProgressTrack = Color(0xFFD9E2E7);

  static AppThemeData _buildTheme({
    required String id,
    required String name,
    required Color primary,
    required Color primaryDark,
    required Color accent,
    required Color scaffoldBackground,
    required Color cardBackground,
    required Color divider,
  }) {
    return AppThemeData(
      primaryColor: primary,
      primaryDarkColor: primaryDark,
      readingBackgroundColor: _fixedReadingBg,
      audiobookBgTop: _fixedAudiobookBgTop,
      scaffoldBackgroundColor: scaffoldBackground,
      textColor: _fixedText,
      secondaryTextColor: _fixedSecondaryText,
      progressTrackColor: _fixedProgressTrack,
      accentColor: accent,
      cardBackgroundColor: cardBackground,
      dividerColor: divider,
      borderRadius: 12.0,
      name: name,
      id: id,
    );
  }

  static final AppThemeData roseTheme = _buildTheme(
    id: themeIdRose,
    name: '玫红',
    primary: const Color(0xFFD8316C),
    primaryDark: const Color(0xFFAA2754),
    accent: const Color(0xFFF6B4CA),
    scaffoldBackground: const Color(0xFFFFF5F8),
    cardBackground: const Color(0xFFFFFFFF),
    divider: const Color(0xFFF3D4DF),
  );

  static final AppThemeData orangeTheme = _buildTheme(
    id: themeIdOrange,
    name: '橙红',
    primary: const Color(0xFFFF5D00),
    primaryDark: const Color(0xFFCC4A00),
    accent: const Color(0xFFFFC29A),
    scaffoldBackground: const Color(0xFFFFF7F2),
    cardBackground: const Color(0xFFFFFFFF),
    divider: const Color(0xFFF6D9C7),
  );

  static final AppThemeData yellowTheme = _buildTheme(
    id: themeIdYellow,
    name: '明黄',
    primary: const Color(0xFFF8CB00),
    primaryDark: const Color(0xFFC9A300),
    accent: const Color(0xFFFFE999),
    scaffoldBackground: const Color(0xFFFFFBEE),
    cardBackground: const Color(0xFFFFFFFF),
    divider: const Color(0xFFF4E9BD),
  );

  static final AppThemeData greenTheme = _buildTheme(
    id: themeIdGreen,
    name: '翠绿',
    primary: const Color(0xFF23C400),
    primaryDark: const Color(0xFF1B9700),
    accent: const Color(0xFFA9E79B),
    scaffoldBackground: const Color(0xFFF4FCF1),
    cardBackground: const Color(0xFFFFFFFF),
    divider: const Color(0xFFD8EDD0),
  );

  static final AppThemeData tealTheme = _buildTheme(
    id: themeIdTeal,
    name: '青绿',
    primary: const Color(0xFF00A48A),
    primaryDark: const Color(0xFF007F6B),
    accent: const Color(0xFF9FE7DA),
    scaffoldBackground: const Color(0xFFF1FBF8),
    cardBackground: const Color(0xFFFFFFFF),
    divider: const Color(0xFFD1ECE6),
  );

  static final AppThemeData blueTheme = _buildTheme(
    id: themeIdBlue,
    name: '蓝色',
    primary: const Color(0xFF0081FF),
    primaryDark: const Color(0xFF0066CC),
    accent: const Color(0xFFA9D0FF),
    scaffoldBackground: const Color(0xFFF3F8FF),
    cardBackground: const Color(0xFFFFFFFF),
    divider: const Color(0xFFD8E6F7),
  );

  static final AppThemeData indigoTheme = _buildTheme(
    id: themeIdIndigo,
    name: '紫蓝',
    primary: const Color(0xFF7565C3),
    primaryDark: const Color(0xFF5D4FA0),
    accent: const Color(0xFFC8C0F2),
    scaffoldBackground: const Color(0xFFF6F4FF),
    cardBackground: const Color(0xFFFFFFFF),
    divider: const Color(0xFFE1DBF3),
  );

  static final AppThemeData purpleTheme = _buildTheme(
    id: themeIdPurple,
    name: '紫色',
    primary: const Color(0xFF8C00D4),
    primaryDark: const Color(0xFF6D00A5),
    accent: const Color(0xFFD8A8F5),
    scaffoldBackground: const Color(0xFFFBF4FF),
    cardBackground: const Color(0xFFFFFFFF),
    divider: const Color(0xFFEBD8F5),
  );

  static final AppThemeData grayTheme = _buildTheme(
    id: themeIdGray,
    name: '灰色',
    primary: const Color(0xFFA6A6A6),
    primaryDark: const Color(0xFF7D7D7D),
    accent: const Color(0xFFDADADA),
    scaffoldBackground: const Color(0xFFF7F7F7),
    cardBackground: const Color(0xFFFFFFFF),
    divider: const Color(0xFFE5E5E5),
  );

  static final AppThemeData defaultTheme = blueTheme;

  static final List<AppThemeData> allThemes = <AppThemeData>[
    roseTheme,
    orangeTheme,
    yellowTheme,
    greenTheme,
    tealTheme,
    blueTheme,
    indigoTheme,
    purpleTheme,
    grayTheme,
  ];
}
