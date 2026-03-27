import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/profile_providers.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/utils/locale_text.dart';
import 'package:myreader/presentation/pages/profile/login_page.dart';
import 'package:myreader/presentation/pages/profile/reading_collection_page.dart';
import 'package:myreader/presentation/pages/profile/reading_rank_page.dart';
import 'package:myreader/presentation/pages/profile/system_settings_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final overview = ref.watch(profileOverviewProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(profileOverviewProvider.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _LoggedOutHero(
                onTap: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
                },
              ),
              const SizedBox(height: 10),
              overview.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _SectionCard(
                  child: Text(
                    LocaleText.of(
                      context,
                      zh: '个人页数据加载失败，请下拉重试',
                      en: 'Failed to load profile data. Pull to retry.',
                    ),
                  ),
                ),
                data: (data) => Column(
                  children: [
                    _ReadingOverviewCard(data: data),
                    const SizedBox(height: 10),
                    _SectionCard(
                      child: Column(
                        children: [
                          _SettingsRowTile(
                            title: LocaleText.of(
                              context,
                              zh: '读书排行',
                              en: 'Reading Rank',
                            ),
                            subtitle: LocaleText.of(
                              context,
                              zh: '按阅读时长排序',
                              en: 'Sorted by reading time',
                            ),
                            leadingText: LocaleText.of(
                              context,
                              zh: '${data.rankedBooks.where((item) => item.readingTimeSeconds > 0).length} 本',
                              en: '${data.rankedBooks.where((item) => item.readingTimeSeconds > 0).length}',
                            ),
                            icon: Icons.leaderboard_outlined,
                            iconColor: const Color(
                              0xFF4CAF50,
                            ), // Green for achievements
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ReadingRankPage(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          Divider(height: 1, color: theme.dividerColor),
                          const SizedBox(height: 4),
                          _SettingsRowTile(
                            title: LocaleText.of(
                              context,
                              zh: '阅读时长',
                              en: 'Reading Time',
                            ),
                            subtitle: _formatDuration(
                              context,
                              data.totalReadingTimeSeconds,
                            ),
                            icon: Icons.schedule_outlined,
                            iconColor: const Color(0xFF009688), // Teal for time
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ReadingCollectionPage(
                                  type: ReadingCollectionType.readingTime,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SectionCard(
                      child: Column(
                        children: [
                          _CompactMetricRow(
                            title: LocaleText.of(
                              context,
                              zh: '在读书籍',
                              en: 'Reading',
                            ),
                            value: LocaleText.of(
                              context,
                              zh: '${data.inProgressBooks.length} 本',
                              en: '${data.inProgressBooks.length}',
                            ),
                            icon: Icons.menu_book_outlined,
                            iconColor: const Color(
                              0xFF2196F3,
                            ), // Blue for reading
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ReadingCollectionPage(
                                  type: ReadingCollectionType.reading,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Divider(height: 1, color: theme.dividerColor),
                          const SizedBox(height: 4),
                          _CompactMetricRow(
                            title: LocaleText.of(
                              context,
                              zh: '读完书籍',
                              en: 'Finished',
                            ),
                            value: LocaleText.of(
                              context,
                              zh: '${data.finishedBooks.length} 本',
                              en: '${data.finishedBooks.length}',
                            ),
                            icon: Icons.task_alt_outlined,
                            iconColor: const Color(
                              0xFF4CAF50,
                            ), // Green for finished/achievement
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ReadingCollectionPage(
                                  type: ReadingCollectionType.finished,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Divider(height: 1, color: theme.dividerColor),
                          const SizedBox(height: 4),
                          _CompactMetricRow(
                            title: LocaleText.of(
                              context,
                              zh: '笔记',
                              en: 'Notes',
                            ),
                            value: LocaleText.of(
                              context,
                              zh: '${data.totalNoteCount} 条',
                              en: '${data.totalNoteCount}',
                            ),
                            icon: Icons.edit_note_outlined,
                            iconColor: const Color(
                              0xFF009688,
                            ), // Teal for notes
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ReadingCollectionPage(
                                  type: ReadingCollectionType.notes,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SectionCard(
                      child: _SettingsRowTile(
                        title: LocaleText.of(
                          context,
                          zh: '系统设置',
                          en: 'System Settings',
                        ),
                        subtitle: LocaleText.of(
                          context,
                          zh: '外观设置等系统级选项',
                          en: 'Appearance and other system options',
                        ),
                        icon: Icons.settings_outlined,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SystemSettingsPage(),
                            ),
                          );
                        },
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

  String _formatDuration(BuildContext context, int seconds) {
    final totalMinutes = seconds ~/ 60;
    if (totalMinutes < 60) {
      return LocaleText.of(
        context,
        zh: '$totalMinutes 分钟',
        en: '$totalMinutes min',
      );
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours < 24) {
      return LocaleText.of(
        context,
        zh: '$hours 小时 $minutes 分钟',
        en: '$hours h $minutes m',
      );
    }
    final days = hours ~/ 24;
    final remainHours = hours % 24;
    return LocaleText.of(
      context,
      zh: '$days 天 $remainHours 小时',
      en: '$days d $remainHours h',
    );
  }
}

class _LoggedOutHero extends ConsumerWidget {
  final VoidCallback onTap;

  const _LoggedOutHero({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.cardBackgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.cardBackgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleText.of(context, zh: '未登录', en: 'Not Signed In'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      LocaleText.of(
                        context,
                        zh: '点击进入登录页面，同步阅读进度与偏好设置',
                        en: 'Tap to go to sign-in and sync your reading data',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFF757575), // Gray for neutral actions
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingOverviewCard extends ConsumerWidget {
  final ProfileOverview data;

  const _ReadingOverviewCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    final topBook = data.rankedBooks.isEmpty ? null : data.rankedBooks.first;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniSummary(
                  title: LocaleText.of(context, zh: '书架', en: 'Library'),
                  value: '${data.rankedBooks.length}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniSummary(
                  title: LocaleText.of(context, zh: '阅读中', en: 'Active'),
                  value: '${data.inProgressBooks.length}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniSummary(
                  title: LocaleText.of(context, zh: '笔记', en: 'Notes'),
                  value: '${data.totalNoteCount}',
                ),
              ),
            ],
          ),
          if (topBook != null) ...[
            const SizedBox(height: 10),
            Text(
              LocaleText.of(
                context,
                zh: '最近最常读：《${topBook.book.title}》',
                en: 'Most active recently: ${topBook.book.title}',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.secondaryTextColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniSummary extends ConsumerWidget {
  final String title;
  final String value;

  const _MiniSummary({required this.title, required this.value});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
          ),
        ],
      ),
    );
  }
}

class _SettingsRowTile extends ConsumerWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? leadingText;
  final Color iconColor;

  const _SettingsRowTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.leadingText,
    this.iconColor = const Color(0xFFFF9800), // Default orange for settings
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.textColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (leadingText != null) ...[
                Text(
                  leadingText!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.secondaryTextColor,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: const Color(0xFF757575), // Gray for neutral actions
                ),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: theme.secondaryTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMetricRow extends ConsumerWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  const _CompactMetricRow({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
    this.iconColor = const Color(0xFF2196F3), // Default blue
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.textColor,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.secondaryTextColor,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFF757575), // Gray for neutral actions
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends ConsumerWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}
