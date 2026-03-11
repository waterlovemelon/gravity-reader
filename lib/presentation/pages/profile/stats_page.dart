import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/entities/reading_progress.dart';
import 'package:myreader/core/providers/book_providers.dart';
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
      final allProgress = await _ref
          .read(updateReadingProgressUseCaseProvider)
          .call(
            ReadingProgress(
              bookId: '',
              location: '',
              percentage: 0,
              lastReadAt: DateTime.now(),
              readingTimeSeconds: 0,
            ),
          );

      int totalMinutes = 0;
      int totalPages = 0;

      for (final book in books) {
        if (book.lastReadAt != null) {
          totalPages += book.totalPages ?? 0;
        }
      }

      state = ReadingStatsState(
        totalBooksRead: books.length,
        totalReadingTimeSeconds: totalMinutes * 60,
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
      final category = book.categoryId ?? 'Uncategorized';
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
    final stats = ref.watch(readingStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reading Statistics')),
      body: stats.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryCards(stats),
                  const SizedBox(height: 24),
                  _buildWeeklyChart(stats),
                  const SizedBox(height: 24),
                  _buildCategoryBreakdown(stats),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards(ReadingStatsState stats) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.book,
            value: '${stats.totalBooksRead}',
            label: 'Books',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.timer,
            value: _formatDuration(stats.totalReadingTimeSeconds),
            label: 'Time',
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.auto_stories,
            value: '${stats.totalPagesRead}',
            label: 'Pages',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart(ReadingStatsState stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This Week',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: stats.dailyStats.map((day) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${day.minutesRead}m',
                        style: const TextStyle(fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 30,
                        height: day.minutesRead.toDouble(),
                        color: Colors.blue,
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

  Widget _buildCategoryBreakdown(ReadingStatsState stats) {
    if (stats.categoryBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Categories',
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
                      children: [Text(entry.key), Text('$percentage%')],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey[200],
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

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).toInt()}m';
    return '${(seconds / 3600).toInt()}h';
  }
}

class _StatCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
