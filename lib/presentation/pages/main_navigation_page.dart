import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/models/app_theme_data.dart';
import 'package:myreader/core/providers/book_providers.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/providers/tts_provider.dart';
import 'package:myreader/core/utils/locale_text.dart';
import 'package:myreader/presentation/pages/bookshelf/bookshelf_page.dart';
import 'package:myreader/presentation/pages/reader/reader_page.dart';
import 'package:myreader/presentation/widgets/bookshelf/book_cover_widget.dart';
import 'package:myreader/presentation/widgets/floating_nav_bar.dart';

class MainNavigationPage extends ConsumerStatefulWidget {
  const MainNavigationPage({super.key});

  @override
  ConsumerState<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends ConsumerState<MainNavigationPage> {
  int _currentIndex = 1;

  final List<Widget> _pages = const [
    ReadingTab(),
    BookshelfTab(),
    BookFriendsTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final ttsState = ref.watch(ttsProvider);

    return Stack(
      children: [
        Scaffold(
          extendBody: true,
          body: IndexedStack(index: _currentIndex, children: _pages),
        ),
        FloatingNavBar(
          currentIndex: _currentIndex,
          onIndexChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
        ),
        _GlobalPlaybackOverlay(ttsState: ttsState),
      ],
    );
  }
}

class _GlobalPlaybackOverlay extends ConsumerWidget {
  final TtsAppState ttsState;

  const _GlobalPlaybackOverlay({required this.ttsState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoadingAudio =
        ttsState.isLoadingAudio && !ttsState.isSpeaking && !ttsState.isPaused;
    final shouldShow =
        !ttsState.isAudiobookUiVisible &&
        (ttsState.isSpeaking || ttsState.isPaused || isLoadingAudio);
    final book = ttsState.currentBook;
    if (!shouldShow || book == null) {
      return const SizedBox.shrink();
    }

    final latestBook = ref.watch(bookByIdProvider(book.id)).valueOrNull;
    final displayBook = latestBook ?? book;
    final isPlaying = ttsState.isSpeaking && !ttsState.isPaused;
    final canTapPlayback = !isLoadingAudio || ttsState.isPaused;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 96,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Container(
          width: 164,
          height: 59,
          decoration: BoxDecoration(
            color: const Color(0xFFA8C1AC).withOpacity(0.96),
            borderRadius: BorderRadius.circular(29.5),
            border: Border.all(color: Colors.white.withOpacity(0.24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReaderPage(
                        bookId: displayBook.id,
                        initialBook: displayBook,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 49,
                  height: 49,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.26),
                    border: Border.all(color: Colors.white.withOpacity(0.44)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: ClipOval(child: BookCoverImage(book: displayBook)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: canTapPlayback
                      ? () {
                          if (ttsState.isPaused) {
                            ref.read(ttsProvider.notifier).resume();
                            return;
                          }
                          if (ttsState.isSpeaking) {
                            ref.read(ttsProvider.notifier).pause();
                            return;
                          }
                        }
                      : null,
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 22,
                          color: const Color(0xFFF6FBF7),
                        ),
                        if (isLoadingAudio)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFFF6FBF7),
                                      ),
                                  backgroundColor: Colors.white.withOpacity(
                                    0.14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () async {
                    await ref.read(ttsProvider.notifier).stop();
                  },
                  child: const SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 5),
            ],
          ),
        ),
      ),
    );
  }
}

class ReadingTab extends ConsumerWidget {
  const ReadingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleText.of(context, zh: '阅读', en: 'Read')),
      ),
      body: Center(
        child: Text(
          LocaleText.of(
            context,
            zh: '从书架中选择一本书开始阅读',
            en: 'Pick a book from your library to start reading',
          ),
          style: TextStyle(color: theme.secondaryTextColor),
        ),
      ),
    );
  }
}

class BookshelfTab extends ConsumerWidget {
  const BookshelfTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const BookshelfPage();
  }
}

class BookFriendsTab extends ConsumerWidget {
  const BookFriendsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleText.of(context, zh: '书友', en: 'Community')),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 64,
              color: theme.secondaryTextColor,
            ),
            const SizedBox(height: 16),
            Text(
              LocaleText.of(
                context,
                zh: '书友动态即将上线',
                en: 'Community feed is coming soon',
              ),
              style: TextStyle(fontSize: 18, color: theme.secondaryTextColor),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Icon(
                  Icons.mail_outline,
                  color: theme.textColor.withOpacity(0.7),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.dividerColor,
                  child: Text(
                    'Q',
                    style: TextStyle(fontSize: 22, color: theme.textColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    LocaleText.of(context, zh: '我也系打工仔', en: 'Office Worker'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: theme.textColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '+14',
                    style: TextStyle(color: theme.primaryColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _ProfileCard(
              theme: theme,
              child: Row(
                children: [
                  Icon(Icons.workspace_premium, color: theme.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      LocaleText.of(
                        context,
                        zh: '成为付费会员',
                        en: 'Become a premium member',
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                  Text(
                    LocaleText.of(
                      context,
                      zh: '立即开通 19 元/月',
                      en: 'Upgrade now for CNY 19/month',
                    ),
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _ThemeModeSection(theme: theme),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SimpleStatCard(
                    title: LocaleText.of(context, zh: '充值币', en: 'Coins'),
                    value: LocaleText.of(
                      context,
                      zh: '余额 0.00',
                      en: 'Balance 0.00',
                    ),
                    icon: Icons.monetization_on_outlined,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _SimpleStatCard(
                    title: LocaleText.of(context, zh: '福利', en: 'Benefits'),
                    value: LocaleText.of(
                      context,
                      zh: '0天 | 赠币0.00',
                      en: '0 days | bonus 0.00',
                    ),
                    icon: Icons.card_giftcard,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ProfileCard(
              theme: theme,
              child: Column(
                children: [
                  _RowMetric(
                    theme: theme,
                    title: LocaleText.of(
                      context,
                      zh: '读书排行榜',
                      en: 'Reading Rank',
                    ),
                    value: LocaleText.of(context, zh: '第 2 名', en: '#2'),
                    sub: LocaleText.of(
                      context,
                      zh: '6 分钟中',
                      en: 'within 6 minutes',
                    ),
                  ),
                  const Divider(height: 18),
                  _RowMetric(
                    theme: theme,
                    title: LocaleText.of(
                      context,
                      zh: '阅读时长',
                      en: 'Reading Time',
                    ),
                    value: LocaleText.of(
                      context,
                      zh: '1935 小时 38 分钟',
                      en: '1935 h 38 m',
                    ),
                    sub: LocaleText.of(
                      context,
                      zh: '本月 6 分钟',
                      en: '6 min this month',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.7,
              children: [
                _SimpleStatCard(
                  title: LocaleText.of(context, zh: '在读', en: 'Reading'),
                  value: LocaleText.of(context, zh: '累计 60 本', en: '60 total'),
                  icon: Icons.east,
                ),
                _SimpleStatCard(
                  title: LocaleText.of(context, zh: '读完', en: 'Finished'),
                  value: LocaleText.of(context, zh: '累计 16 本', en: '16 total'),
                  icon: Icons.check_circle,
                ),
                _SimpleStatCard(
                  title: LocaleText.of(context, zh: '笔记', en: 'Notes'),
                  value: LocaleText.of(context, zh: '累计 86 个', en: '86 total'),
                  icon: Icons.edit_note,
                ),
                _SimpleStatCard(
                  title: LocaleText.of(context, zh: '订阅', en: 'Subscriptions'),
                  value: LocaleText.of(
                    context,
                    zh: '已上架 1 本',
                    en: '1 published',
                  ),
                  icon: Icons.notifications,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ProfileCard(
              theme: theme,
              child: _RowMetric(
                theme: theme,
                title: LocaleText.of(context, zh: '书单', en: 'Booklists'),
                value: LocaleText.of(context, zh: '1 个', en: '1'),
                sub: '',
              ),
            ),
            const SizedBox(height: 10),
            _ProfileCard(
              theme: theme,
              child: _RowMetric(
                theme: theme,
                title: LocaleText.of(context, zh: '关注', en: 'Followers'),
                value: LocaleText.of(
                  context,
                  zh: '12 人关注我',
                  en: '12 follow me',
                ),
                sub: LocaleText.of(
                  context,
                  zh: '我关注了 13 人',
                  en: 'Following 13',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AppThemeData theme;
  final Widget child;

  const _ProfileCard({required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _ThemeModeSection extends ConsumerWidget {
  final AppThemeData theme;

  const _ThemeModeSection({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(appThemeModeProvider);

    return _ProfileCard(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: theme.primaryColor),
              const SizedBox(width: 8),
              Text(
                LocaleText.of(context, zh: '主题设置', en: 'Theme'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            LocaleText.of(
              context,
              zh: '选择应用外观模式',
              en: 'Choose the app appearance mode',
            ),
            style: TextStyle(fontSize: 13, color: theme.secondaryTextColor),
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
                onTap: () {
                  ref
                      .read(themeProvider.notifier)
                      .switchThemeMode(AppThemeMode.system);
                },
              ),
              _ThemeModeChip(
                theme: theme,
                label: LocaleText.of(context, zh: '浅色', en: 'Light'),
                selected: currentMode == AppThemeMode.light,
                onTap: () {
                  ref
                      .read(themeProvider.notifier)
                      .switchThemeMode(AppThemeMode.light);
                },
              ),
              _ThemeModeChip(
                theme: theme,
                label: LocaleText.of(context, zh: '深色', en: 'Dark'),
                selected: currentMode == AppThemeMode.dark,
                onTap: () {
                  ref
                      .read(themeProvider.notifier)
                      .switchThemeMode(AppThemeMode.dark);
                },
              ),
            ],
          ),
        ],
      ),
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
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? theme.primaryColor : theme.textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _RowMetric extends StatelessWidget {
  final AppThemeData theme;
  final String title;
  final String value;
  final String sub;

  const _RowMetric({
    required this.theme,
    required this.title,
    required this.value,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 16, color: theme.textColor),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: theme.textColor,
              ),
            ),
            if (sub.isNotEmpty)
              Text(
                sub,
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
              ),
          ],
        ),
      ],
    );
  }
}

class _SimpleStatCard extends ConsumerWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SimpleStatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(currentThemeProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.secondaryTextColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.textColor,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: theme.secondaryTextColor,
                    fontSize: 12,
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
