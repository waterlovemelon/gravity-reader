import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/theme_provider.dart';

class FloatingNavBar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final navBackground =
        Color.lerp(
          theme.cardBackgroundColor,
          theme.scaffoldBackgroundColor,
          isDark ? 0.08 : 0.14,
        ) ??
        theme.cardBackgroundColor;
    final selectedBackground = theme.primaryColor.withValues(alpha: 0.12);
    final selectedForeground = theme.primaryColor;
    final unselectedForeground = theme.secondaryTextColor;
    final navDecoration = BoxDecoration(
      color: isDark
          ? navBackground.withValues(alpha: 0.74)
          : navBackground.withValues(alpha: 0.78),
      gradient: isDark
          ? null
          : LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(navBackground, Colors.white, 0.18) ?? navBackground,
                navBackground,
              ],
            ),
      borderRadius: BorderRadius.circular(28),
      border: isDark
          ? Border.all(
              color: theme.dividerColor.withValues(alpha: 0.18),
              width: 0.8,
            )
          : Border.all(
              color:
                  Color.lerp(
                    theme.dividerColor,
                    Colors.white,
                    0.32,
                  )?.withValues(alpha: 0.42) ??
                  theme.dividerColor.withValues(alpha: 0.42),
              width: 0.9,
            ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, -1),
              ),
            ],
    );

    return Positioned(
      left: 20,
      right: 20,
      bottom: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isDark ? 12 : 16,
            sigmaY: isDark ? 12 : 16,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: navDecoration,
            child: Row(
              children: [
                _buildNavItem(
                  icon: Icons.auto_stories_outlined,
                  selectedIcon: Icons.auto_stories_rounded,
                  label: '阅读',
                  index: 0,
                  selectedBackground: selectedBackground,
                  selectedForeground: selectedForeground,
                  unselectedForeground: unselectedForeground,
                ),
                _buildNavItem(
                  icon: Icons.collections_bookmark_outlined,
                  selectedIcon: Icons.collections_bookmark_rounded,
                  label: '书架',
                  index: 1,
                  selectedBackground: selectedBackground,
                  selectedForeground: selectedForeground,
                  unselectedForeground: unselectedForeground,
                ),
                _buildNavItem(
                  icon: Icons.people_outline_rounded,
                  selectedIcon: Icons.people_rounded,
                  label: '书友',
                  index: 2,
                  selectedBackground: selectedBackground,
                  selectedForeground: selectedForeground,
                  unselectedForeground: unselectedForeground,
                ),
                _buildNavItem(
                  icon: Icons.sentiment_satisfied_alt_outlined,
                  selectedIcon: Icons.sentiment_satisfied_alt_rounded,
                  label: '我的',
                  index: 3,
                  selectedBackground: selectedBackground,
                  selectedForeground: selectedForeground,
                  unselectedForeground: unselectedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required Color selectedBackground,
    required Color selectedForeground,
    required Color unselectedForeground,
  }) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => onIndexChanged(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 18 : 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? selectedBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                size: 22,
                color: isSelected ? selectedForeground : unselectedForeground,
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                sizeCurve: Curves.easeOut,
                crossFadeState: isSelected
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selectedForeground,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
