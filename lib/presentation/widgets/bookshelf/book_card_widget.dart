import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/presentation/widgets/bookshelf/book_cover_widget.dart';

class BookCardWidget extends ConsumerWidget {
  final Book book;
  final double? progress;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final ValueChanged<LongPressStartDetails>? onLongPressStart;
  final ValueChanged<TapDownDetails>? onSecondaryTapDown;

  const BookCardWidget({
    super.key,
    required this.book,
    this.progress,
    this.isSelected = false,
    this.selectionMode = false,
    this.onTap,
    this.onLongPressStart,
    this.onSecondaryTapDown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      onSecondaryTapDown: onSecondaryTapDown,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.76,
            child: Stack(
              children: [
                Positioned.fill(
                  child: BookCoverWidget(
                    book: book,
                    width: double.infinity,
                    height: double.infinity,
                    heroTag: 'book-cover-${book.id}',
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: _CoverProgressLine(progress: progress),
                ),
                if (selectionMode)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.primaryColor
                            : Colors.white.withValues(alpha: 0.82),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? theme.primaryColor
                              : theme.secondaryTextColor.withValues(
                                  alpha: 0.22,
                                ),
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 11,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book.title,
            style: TextStyle(
              fontSize: 12,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            book.author?.trim().isNotEmpty == true ? book.author! : '未知作者',
            style: TextStyle(
              fontSize: 10,
              height: 1,
              color: theme.secondaryTextColor.withValues(alpha: 0.78),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CoverProgressLine extends ConsumerWidget {
  final double? progress;

  const _CoverProgressLine({required this.progress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final value = (progress ?? 0).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 1.2,
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.12)),
            FractionallySizedBox(
              widthFactor: value,
              alignment: Alignment.centerLeft,
              child: Container(
                color: theme.primaryColor.withValues(
                  alpha: value > 0 ? 0.68 : 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
