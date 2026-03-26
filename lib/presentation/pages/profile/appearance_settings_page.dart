import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/constants/theme_constants.dart';
import 'package:myreader/core/models/app_theme_data.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/utils/locale_text.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final currentMode = ref.watch(appThemeModeProvider);
    final currentThemeId = ref.watch(currentThemeIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleText.of(context, zh: '外观设置', en: 'Appearance')),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AppearanceCard(
            theme: theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  theme: theme,
                  icon: Icons.dark_mode_outlined,
                  title: LocaleText.of(
                    context,
                    zh: '主题模式',
                    en: 'Appearance Mode',
                  ),
                  subtitle: LocaleText.of(
                    context,
                    zh: '跟随系统、浅色、深色三种模式',
                    en: 'Switch between system, light and dark',
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ThemeModeChip(
                      theme: theme,
                      label: LocaleText.of(context, zh: '跟随系统', en: 'System'),
                      selected: currentMode == AppThemeMode.system,
                      onTap: () => ref
                          .read(themeProvider.notifier)
                          .switchThemeMode(AppThemeMode.system),
                    ),
                    _ThemeModeChip(
                      theme: theme,
                      label: LocaleText.of(context, zh: '浅色', en: 'Light'),
                      selected: currentMode == AppThemeMode.light,
                      onTap: () => ref
                          .read(themeProvider.notifier)
                          .switchThemeMode(AppThemeMode.light),
                    ),
                    _ThemeModeChip(
                      theme: theme,
                      label: LocaleText.of(context, zh: '深色', en: 'Dark'),
                      selected: currentMode == AppThemeMode.dark,
                      onTap: () => ref
                          .read(themeProvider.notifier)
                          .switchThemeMode(AppThemeMode.dark),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AppearanceCard(
            theme: theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(
                  theme: theme,
                  icon: Icons.palette_outlined,
                  title: LocaleText.of(context, zh: '主题色', en: 'Theme Color'),
                  subtitle: LocaleText.of(
                    context,
                    zh: '只影响应用界面，不影响阅读正文背景',
                    en: 'Affects the app shell and profile pages',
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: ThemeConstants.allThemes
                      .map(
                        (item) => _ThemeColorChip(
                          appTheme: item,
                          selected: currentThemeId == item.id,
                          onTap: () => ref
                              .read(themeProvider.notifier)
                              .switchTheme(item.id),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  final AppThemeData theme;
  final Widget child;

  const _AppearanceCard({required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final AppThemeData theme;
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.primaryColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: theme.secondaryTextColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeModeChip extends StatelessWidget {
  final AppThemeData theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeChip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? theme.primaryColor.withValues(alpha: 0.14)
                : theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? theme.primaryColor : theme.dividerColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? theme.primaryColor : theme.textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeColorChip extends StatelessWidget {
  final AppThemeData appTheme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeColorChip({
    required this.appTheme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 72,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: appTheme.cardBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? appTheme.primaryDarkColor
                  : appTheme.dividerColor,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: appTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                appTheme.name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? appTheme.primaryDarkColor
                      : appTheme.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
