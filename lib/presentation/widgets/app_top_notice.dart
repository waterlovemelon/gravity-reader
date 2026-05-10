import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:myreader/core/models/app_theme_data.dart';

enum AppTopNoticeKind { success, error, info }

class AppTopNotice extends StatelessWidget {
  static const Duration visibleDuration = Duration(milliseconds: 1600);

  final String message;
  final AppThemeData theme;
  final AppTopNoticeKind kind;
  final Animation<double> animation;
  final VoidCallback onDismiss;

  const AppTopNotice({
    super.key,
    required this.message,
    required this.theme,
    required this.kind,
    required this.animation,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForKind();

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final slideY = Tween<double>(begin: -12, end: 0).evaluate(animation);
        final scale = Tween<double>(begin: 0.98, end: 1).evaluate(animation);
        return Opacity(
          opacity: animation.value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, slideY),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onDismiss,
          borderRadius: BorderRadius.circular(15),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Ink(
                padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: palette.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 34),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(palette.icon, size: 17, color: palette.accent),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: palette.foreground,
                            height: 1.22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _AppTopNoticePalette _paletteForKind() {
    switch (kind) {
      case AppTopNoticeKind.success:
        return _AppTopNoticePalette(
          background: Color.alphaBlend(
            theme.primaryColor.withValues(alpha: 0.08),
            theme.cardBackgroundColor.withValues(alpha: 0.96),
          ),
          border: theme.primaryColor.withValues(alpha: 0.18),
          accent: theme.primaryColor,
          foreground: theme.textColor,
          icon: Icons.check_rounded,
        );
      case AppTopNoticeKind.error:
        return _AppTopNoticePalette(
          background: Color.alphaBlend(
            const Color(0xFFD85B5B).withValues(alpha: 0.08),
            theme.cardBackgroundColor.withValues(alpha: 0.96),
          ),
          border: const Color(0xFFD85B5B).withValues(alpha: 0.2),
          accent: const Color(0xFFD85B5B),
          foreground: theme.textColor,
          icon: Icons.close_rounded,
        );
      case AppTopNoticeKind.info:
        return _AppTopNoticePalette(
          background: Color.alphaBlend(
            theme.accentColor.withValues(alpha: 0.08),
            theme.cardBackgroundColor.withValues(alpha: 0.96),
          ),
          border: theme.accentColor.withValues(alpha: 0.2),
          accent: theme.accentColor,
          foreground: theme.textColor,
          icon: Icons.info_outline_rounded,
        );
    }
  }
}

class _AppTopNoticePalette {
  final Color background;
  final Color border;
  final Color accent;
  final Color foreground;
  final IconData icon;

  const _AppTopNoticePalette({
    required this.background,
    required this.border,
    required this.accent,
    required this.foreground,
    required this.icon,
  });
}
