import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/flureadium_integration/epub_parser.dart';

class TableOfContentsWidget extends ConsumerWidget {
  final List<Chapter> chapters;
  final Function(Chapter)? onChapterTap;
  final int? currentChapterIndex;

  const TableOfContentsWidget({
    super.key,
    required this.chapters,
    this.onChapterTap,
    this.currentChapterIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    if (chapters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list, size: 48, color: theme.secondaryTextColor),
            const SizedBox(height: 16),
            Text(
              'No chapters available',
              style: TextStyle(color: theme.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: chapters.length,
      itemBuilder: (context, index) {
        final chapter = chapters[index];
        final isCurrentChapter = index == currentChapterIndex;

        return ListTile(
          leading: isCurrentChapter
              ? Icon(Icons.play_arrow, color: theme.primaryColor)
              : Text(
                  '${index + 1}',
                  style: TextStyle(color: theme.secondaryTextColor),
                ),
          title: Text(
            chapter.title,
            style: TextStyle(
              fontWeight: isCurrentChapter
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: isCurrentChapter ? theme.primaryColor : theme.textColor,
            ),
          ),
          trailing: isCurrentChapter
              ? Icon(Icons.bookmark, color: theme.primaryColor, size: 20)
              : null,
          onTap: () => onChapterTap?.call(chapter),
        );
      },
    );
  }
}
