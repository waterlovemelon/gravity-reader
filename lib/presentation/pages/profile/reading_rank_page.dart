import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/profile_providers.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/utils/locale_text.dart';
import 'package:myreader/presentation/pages/reader/reader_page.dart';
import 'package:myreader/presentation/widgets/bookshelf/book_cover_widget.dart';

class ReadingRankPage extends ConsumerWidget {
  const ReadingRankPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final overview = ref.watch(profileOverviewProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(LocaleText.of(context, zh: '读书排行', en: 'Reading Rank')),
      ),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            LocaleText.of(context, zh: '读书排行加载失败', en: 'Failed to load rank'),
          ),
        ),
        data: (data) {
          final rankedBooks = data.rankedBooks
              .where((item) => item.readingTimeSeconds > 0)
              .toList(growable: false);
          if (rankedBooks.isEmpty) {
            return Center(
              child: Text(
                LocaleText.of(
                  context,
                  zh: '开始阅读后，这里会显示你的阅读排行',
                  en: 'Your ranking will appear after you start reading',
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _RankHero(topBook: rankedBooks.first),
              const SizedBox(height: 14),
              ...rankedBooks.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RankTile(rank: entry.key + 1, item: entry.value),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RankHero extends ConsumerWidget {
  final ProfileBookInsight topBook;

  const _RankHero({required this.topBook});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final minutes = topBook.readingTimeSeconds ~/ 60;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withValues(alpha: 0.22),
            theme.cardBackgroundColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.emoji_events_outlined, color: theme.primaryColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleText.of(context, zh: '当前阅读榜首', en: 'Top Book'),
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  topBook.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  LocaleText.of(
                    context,
                    zh: '累计阅读 $minutes 分钟',
                    en: '$minutes minutes read',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankTile extends ConsumerWidget {
  final int rank;
  final ProfileBookInsight item;

  const _RankTile({required this.rank, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final progressPercent = (item.progressValue * 100).round();
    final minutes = item.readingTimeSeconds ~/ 60;

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
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                height: 68,
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
                    const SizedBox(height: 8),
                    Text(
                      LocaleText.of(
                        context,
                        zh: '阅读 $minutes 分钟 · 进度 $progressPercent%',
                        en: '$minutes min read · $progressPercent%',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.secondaryTextColor,
                      ),
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
