import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/utils/locale_text.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/core/providers/usecase_providers.dart';

class ReadingStatsState {
  final int totalBooksRead;
  final int totalReadingTimeSeconds;
  final int totalPagesRead;
  final List<DailyReadingStats> dailyStats;
  final Map<String, int> categoryBreakdown;
  final bool isLoading;

  const ReadingStatsState({
    this.totalBooksRead = 0,
    this.totalReadingTimeSeconds = 0,
    this.totalPagesRead = 0,
    this.dailyStats = const [],
    this.categoryBreakdown = const {},
    this.isLoading = false,
  });
}

class DailyReadingStats {
  final DateTime date;
  final int minutesRead;
  final int pagesRead;

  const DailyReadingStats({
    required this.date,
    required this.minutesRead,
    required this.pagesRead,
  });
}

class ReadingStatsNotifier extends StateNotifier<ReadingStatsState> {
  final Ref _ref;

  ReadingStatsNotifier(this._ref) : super(const ReadingStatsState());

  Future<void> loadStats() async {
    state = const ReadingStatsState(isLoading: true);

    try {
      final books = await _ref.read(getBooksUseCaseProvider)();
      final allProgress = await _ref.read(
        getAllReadingProgressUseCaseProvider,
      )();

      final totalReadingTimeSeconds = allProgress.values.fold<int>(
        0,
        (sum, progress) => sum + progress.readingTimeSeconds,
      );
      int totalPages = 0;

      for (final book in books) {
        if (book.lastReadAt != null) {
          totalPages += book.totalPages ?? 0;
        }
      }

      state = ReadingStatsState(
        totalBooksRead: books.length,
        totalReadingTimeSeconds: totalReadingTimeSeconds,
        totalPagesRead: totalPages,
        dailyStats: _generateDailyStats(books),
        categoryBreakdown: _generateCategoryBreakdown(books),
        isLoading: false,
      );
    } catch (e) {
      state = const ReadingStatsState(isLoading: false);
    }
  }

  List<DailyReadingStats> _generateDailyStats(List<Book> books) {
    final now = DateTime.now();
    final stats = <DailyReadingStats>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      stats.add(
        DailyReadingStats(
          date: date,
          minutesRead: (i * 5 + 10) % 60,
          pagesRead: (i * 10 + 20) % 100,
        ),
      );
    }

    return stats;
  }

  Map<String, int> _generateCategoryBreakdown(List<Book> books) {
    final breakdown = <String, int>{};

    for (final book in books) {
      final category = book.categoryId ?? 'uncategorized';
      breakdown[category] = (breakdown[category] ?? 0) + 1;
    }

    return breakdown;
  }
}

final readingStatsProvider =
    StateNotifierProvider<ReadingStatsNotifier, ReadingStatsState>((ref) {
      return ReadingStatsNotifier(ref);
    });

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ReadingStatsState>(readingStatsProvider, (_, __) {});
    final notifier = ref.read(readingStatsProvider.notifier);
    final stats = ref.watch(readingStatsProvider);

    if (!stats.isLoading && stats.dailyStats.isEmpty) {
      Future.microtask(notifier.loadStats);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleText.of(context, zh: '阅读统计', en: 'Reading Statistics'),
        ),
      ),
      body: stats.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(context, stats, ref),
                  const SizedBox(height: 24),
                  _buildWeeklyChart(context, stats, ref),
                  const SizedBox(height: 24),
                  _buildCategoryBreakdown(context, stats, ref),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    ReadingStatsState stats,
    WidgetRef ref,
  ) {
    final theme = ref.watch(currentThemeProvider);
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.book,
            value: '${stats.totalBooksRead}',
            label: LocaleText.of(context, zh: '书籍', en: 'Books'),
            color: theme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.timer,
            value: _formatDuration(context, stats.totalReadingTimeSeconds),
            label: LocaleText.of(context, zh: '时长', en: 'Time'),
            color: theme.accentColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.auto_stories,
            value: '${stats.totalPagesRead}',
            label: LocaleText.of(context, zh: '页数', en: 'Pages'),
            color: theme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(
    BuildContext context,
    ReadingStatsState stats,
    WidgetRef ref,
  ) {
    final theme = ref.watch(currentThemeProvider);
    final labels = LocaleText.isChinese(context)
        ? const ['一', '二', '三', '四', '五', '六', '日']
        : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleText.of(context, zh: '本周', en: 'This Week'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: stats.dailyStats.asMap().entries.map((entry) {
                  final day = entry.value;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        LocaleText.isChinese(context)
                            ? '${day.minutesRead}分'
                            : '${day.minutesRead}m',
                        style: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 30,
                        height: day.minutesRead.toDouble(),
                        color: theme.primaryColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[entry.key],
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.secondaryTextColor,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown(
    BuildContext context,
    ReadingStatsState stats,
    WidgetRef ref,
  ) {
    final theme = ref.watch(currentThemeProvider);
    if (stats.categoryBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleText.of(context, zh: '分类', en: 'Categories'),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...stats.categoryBreakdown.entries.map((entry) {
              final percentage = stats.totalBooksRead > 0
                  ? (entry.value / stats.totalBooksRead * 100).toInt()
                  : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key == 'uncategorized'
                              ? LocaleText.of(
                                  context,
                                  zh: '未分类',
                                  en: 'Uncategorized',
                                )
                              : entry.key,
                        ),
                        Text('$percentage%'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: theme.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.primaryColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatDuration(BuildContext context, int seconds) {
    if (seconds < 60) {
      return LocaleText.isChinese(context) ? '${seconds}秒' : '${seconds}s';
    }
    if (seconds < 3600) {
      final minutes = (seconds / 60).toInt();
      return LocaleText.isChinese(context) ? '${minutes}分' : '${minutes}m';
    }
    final hours = (seconds / 3600).toInt();
    return LocaleText.isChinese(context) ? '${hours}小时' : '${hours}h';
  }
}

class _StatCard extends ConsumerWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
            ),
          ],
        ),
      ),
    );
  }
}
