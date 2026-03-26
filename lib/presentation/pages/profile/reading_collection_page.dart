import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/profile_providers.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/utils/locale_text.dart';
import 'package:myreader/presentation/pages/reader/reader_page.dart';
import 'package:myreader/presentation/widgets/bookshelf/book_cover_widget.dart';

enum ReadingCollectionType { readingTime, reading, finished, notes }

class ReadingCollectionPage extends ConsumerWidget {
  final ReadingCollectionType type;

  const ReadingCollectionPage({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final overview = ref.watch(profileOverviewProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(_title(context))),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ProfileErrorState(
          message: LocaleText.of(
            context,
            zh: '加载失败，请稍后重试',
            en: 'Failed to load. Please try again.',
          ),
        ),
        data: (data) {
          final items = _itemsFor(data);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryBanner(
                title: _title(context),
                value: _summaryValue(context, data),
                description: _summaryDescription(context, items.length),
              ),
              const SizedBox(height: 14),
              if (items.isEmpty)
                _ProfileEmptyState(
                  message: LocaleText.of(
                    context,
                    zh: '这里还没有内容',
                    en: 'Nothing here yet',
                  ),
                )
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BookInsightTile(item: item),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _title(BuildContext context) {
    switch (type) {
      case ReadingCollectionType.readingTime:
        return LocaleText.of(context, zh: '阅读时长', en: 'Reading Time');
      case ReadingCollectionType.reading:
        return LocaleText.of(context, zh: '在读', en: 'Reading');
      case ReadingCollectionType.finished:
        return LocaleText.of(context, zh: '读完', en: 'Finished');
      case ReadingCollectionType.notes:
        return LocaleText.of(context, zh: '笔记', en: 'Notes');
    }
  }

  List<ProfileBookInsight> _itemsFor(ProfileOverview overview) {
    switch (type) {
      case ReadingCollectionType.readingTime:
        return overview.rankedBooks
            .where((item) => item.readingTimeSeconds > 0)
            .toList(growable: false);
      case ReadingCollectionType.reading:
        return overview.inProgressBooks;
      case ReadingCollectionType.finished:
        return overview.finishedBooks;
      case ReadingCollectionType.notes:
        return overview.notedBooks;
    }
  }

  String _summaryValue(BuildContext context, ProfileOverview overview) {
    switch (type) {
      case ReadingCollectionType.readingTime:
        final totalMinutes = overview.totalReadingTimeSeconds ~/ 60;
        if (totalMinutes < 60) {
          return LocaleText.of(
            context,
            zh: '$totalMinutes 分钟',
            en: '$totalMinutes min',
          );
        }
        final hours = totalMinutes ~/ 60;
        final minutes = totalMinutes % 60;
        return LocaleText.of(
          context,
          zh: '$hours 小时 $minutes 分钟',
          en: '$hours h $minutes m',
        );
      case ReadingCollectionType.reading:
        return LocaleText.of(
          context,
          zh: '${overview.inProgressBooks.length} 本',
          en: '${overview.inProgressBooks.length}',
        );
      case ReadingCollectionType.finished:
        return LocaleText.of(
          context,
          zh: '${overview.finishedBooks.length} 本',
          en: '${overview.finishedBooks.length}',
        );
      case ReadingCollectionType.notes:
        return LocaleText.of(
          context,
          zh: '${overview.totalNoteCount} 条',
          en: '${overview.totalNoteCount}',
        );
    }
  }

  String _summaryDescription(BuildContext context, int itemCount) {
    switch (type) {
      case ReadingCollectionType.readingTime:
        return LocaleText.of(
          context,
          zh: '按单本书阅读时长排序',
          en: 'Sorted by reading time per book',
        );
      case ReadingCollectionType.reading:
        return LocaleText.of(
          context,
          zh: '当前仍在推进的书籍，共 $itemCount 本',
          en: '$itemCount books currently in progress',
        );
      case ReadingCollectionType.finished:
        return LocaleText.of(
          context,
          zh: '阅读进度达到 99% 及以上的书籍',
          en: 'Books with progress at or above 99%',
        );
      case ReadingCollectionType.notes:
        return LocaleText.of(
          context,
          zh: '按笔记数量展示有摘录的书',
          en: 'Books that already contain notes',
        );
    }
  }
}

class _SummaryBanner extends ConsumerWidget {
  final String title;
  final String value;
  final String description;

  const _SummaryBanner({
    required this.title,
    required this.value,
    required this.description,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withValues(alpha: 0.18),
            theme.cardBackgroundColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 14, color: theme.secondaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: theme.secondaryTextColor),
          ),
        ],
      ),
    );
  }
}

class _BookInsightTile extends ConsumerWidget {
  final ProfileBookInsight item;

  const _BookInsightTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final readingMinutes = item.readingTimeSeconds ~/ 60;
    final progressPercent = (item.progressValue * 100).round();

    return Material(
      color: theme.cardBackgroundColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  ReaderPage(bookId: item.book.id, initialBook: item.book),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 72,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BookCoverImage(book: item.book),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.book.author ??
                          LocaleText.of(
                            context,
                            zh: '未知作者',
                            en: 'Unknown Author',
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(
                          label: LocaleText.of(
                            context,
                            zh: '$readingMinutes 分钟',
                            en: '$readingMinutes min',
                          ),
                        ),
                        _MetaChip(
                          label: LocaleText.of(
                            context,
                            zh: '进度 $progressPercent%',
                            en: '$progressPercent%',
                          ),
                        ),
                        if (item.noteCount > 0)
                          _MetaChip(
                            label: LocaleText.of(
                              context,
                              zh: '${item.noteCount} 条笔记',
                              en: '${item.noteCount} notes',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends ConsumerWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.primaryColor,
        ),
      ),
    );
  }
}

class _ProfileEmptyState extends ConsumerWidget {
  final String message;

  const _ProfileEmptyState({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontSize: 14, color: theme.secondaryTextColor),
        ),
      ),
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  final String message;

  const _ProfileErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(message));
  }
}
