import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/book_providers.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/providers/tts_provider.dart';
import 'package:myreader/core/utils/locale_text.dart';
import 'package:myreader/presentation/pages/bookshelf/bookshelf_page.dart';
import 'package:myreader/presentation/pages/profile/profile_page.dart';
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
    final theme = ref.watch(currentThemeProvider);
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
    final capsuleColor =
        Color.lerp(theme.primaryColor, theme.cardBackgroundColor, 0.55) ??
        theme.cardBackgroundColor;
    final primaryIconColor = theme.textColor;
    final secondaryIconColor = theme.secondaryTextColor;
    final ringFill =
        Color.lerp(theme.primaryColor, Colors.white, 0.72) ??
        theme.primaryColor;
    final ringBorder =
        Color.lerp(theme.primaryColor, Colors.white, 0.5) ?? theme.primaryColor;
    // Colorful icon colors for overlay controls
    final blueAccent = const Color(0xFF2196F3);
    final redAccent = const Color(0xFFF44336);

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
            color: capsuleColor.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(29.5),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.44),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
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
                    color: ringFill.withValues(alpha: 0.24),
                    border: Border.all(
                      color: ringBorder.withValues(alpha: 0.5),
                    ),
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
                          color: blueAccent,
                        ),
                        if (isLoadingAudio)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    blueAccent,
                                  ),
                                  backgroundColor: blueAccent.withValues(
                                    alpha: 0.14,
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
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: redAccent,
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
              color: const Color(0xFF3F51B5), // Indigo for community
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
    return const ProfilePage();
  }
}
