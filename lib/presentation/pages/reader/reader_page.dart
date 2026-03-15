import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:charset_converter/charset_converter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/book_providers.dart';
import 'package:myreader/core/providers/tts_provider.dart';
import 'package:myreader/core/providers/usecase_providers.dart';
import 'package:myreader/data/services/txt_parser.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/entities/reading_progress.dart';
import 'package:myreader/presentation/pages/reader/audiobook_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final String bookId;
  final Book? initialBook;

  const ReaderPage({super.key, required this.bookId, this.initialBook});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _TxtPage {
  final String title;
  final int chapterIndex;
  final int startOffset;
  final int endOffset;

  const _TxtPage({
    required this.title,
    required this.chapterIndex,
    required this.startOffset,
    required this.endOffset,
  });
}

class _TocEntry {
  final String title;
  final int pageIndex;
  final int? chapterIndex;

  const _TocEntry({
    required this.title,
    required this.pageIndex,
    this.chapterIndex,
  });
}

class _TocSelection {
  final int pageIndex;
  final int? chapterIndex;

  const _TocSelection({required this.pageIndex, this.chapterIndex});
}

class _TxtChapter {
  final String title;
  final String content;
  final int index;

  const _TxtChapter({
    required this.title,
    required this.content,
    required this.index,
  });
}

class _AudiobookLaunchData {
  final String initialText;
  final String? chapterTitle;
  final String? chapterText;
  final int? chapterIndex;
  final int initialOffset;
  final int lookbackStartOffset;
  final String? nextChapterTitle;
  final String? nextChapterText;
  final int? nextChapterIndex;
  final List<AudiobookChapterPayload> chapterQueue;

  const _AudiobookLaunchData({
    required this.initialText,
    this.chapterTitle,
    this.chapterText,
    this.chapterIndex,
    this.initialOffset = 0,
    this.lookbackStartOffset = 0,
    this.nextChapterTitle,
    this.nextChapterText,
    this.nextChapterIndex,
    this.chapterQueue = const <AudiobookChapterPayload>[],
  });
}

class _ThemeOption {
  final int id;
  final Color color;
  final String name;
  final IconData icon;

  const _ThemeOption({
    required this.id,
    required this.color,
    required this.name,
    required this.icon,
  });
}

enum _ReaderPanel { none, toc, notes, progress, theme, typography }

Map<String, dynamic> _prepareTxtChapterData(String text) {
  final chapters = TxtParser().parse(text).chapters;
  final chapterData = <Map<String, dynamic>>[];

  if (chapters.isEmpty) {
    chapterData.add({'title': '正文', 'content': '该 TXT 文件为空。', 'index': 0});
  } else {
    for (final chapter in chapters) {
      final body = chapter.content.replaceAll('\r\n', '\n');
      if (body.isEmpty) {
        continue;
      }
      chapterData.add({
        'title': chapter.title,
        'content': _normalizeParagraphSpacing(body),
        'index': chapter.index,
      });
    }
    if (chapterData.isEmpty) {
      chapterData.add({'title': '正文', 'content': '该 TXT 文件为空。', 'index': 0});
    }
  }

  return {'chapters': chapterData};
}

String _normalizeParagraphSpacing(String text) {
  var processed = text.replaceAll(RegExp(r'\n{2,}'), '\n\n\n\n');

  // Remove leading empty lines
  processed = processed.replaceFirst(RegExp(r'^\n+'), '');

  // Remove trailing empty lines
  processed = processed.replaceFirst(RegExp(r'\n+$'), '');

  return processed;
}

class _TableOfContentsSheet extends StatefulWidget {
  final List<_TocEntry> entries;
  final double height;
  final Color textColor;
  final int currentPage;
  final int? currentChapterIndex;
  final int initialTocIndex;

  const _TableOfContentsSheet({
    required this.entries,
    required this.height,
    required this.textColor,
    required this.currentPage,
    required this.currentChapterIndex,
    required this.initialTocIndex,
  });

  @override
  State<_TableOfContentsSheet> createState() => _TableOfContentsSheetState();
}

class _TableOfContentsSheetState extends State<_TableOfContentsSheet> {
  static const double _tocItemExtent = 52;
  late final ScrollController _listController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initialOffset = widget.initialTocIndex < 0
        ? 0.0
        : max(0.0, widget.initialTocIndex * _tocItemExtent - 120.0);
    _listController = ScrollController(initialScrollOffset: initialOffset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_listController.hasClients || widget.initialTocIndex < 0) {
        return;
      }
      final target = max(0.0, widget.initialTocIndex * _tocItemExtent - 120.0);
      final maxOffset = _listController.position.maxScrollExtent;
      _listController.jumpTo(target.clamp(0.0, maxOffset));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapterNoByEntry = <_TocEntry, int>{
      for (var i = 0; i < widget.entries.length; i++) widget.entries[i]: i + 1,
    };
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.entries
        : widget.entries.where((e) {
            final chapterNo = chapterNoByEntry[e] ?? 0;
            return e.title.toLowerCase().contains(q) ||
                '$chapterNo'.contains(q) ||
                '${e.pageIndex + 1}'.contains(q);
          }).toList();

    return SafeArea(
      child: SizedBox(
        height: widget.height,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: widget.textColor.withOpacity(0.22),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: widget.textColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: '搜本书',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.search,
                        style: TextStyle(fontSize: 13, color: widget.textColor),
                        onChanged: (value) {
                          setState(() {
                            _query = value;
                          });
                          if (_listController.hasClients) {
                            _listController.jumpTo(0);
                          }
                        },
                        onSubmitted: (_) {
                          if (filtered.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('未找到匹配的章节'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          final first = filtered.first;
                          Navigator.pop(
                            context,
                            _TocSelection(
                              pageIndex: first.pageIndex,
                              chapterIndex: first.chapterIndex,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 34,
                    width: 76,
                    decoration: BoxDecoration(
                      color: widget.textColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '目录',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: widget.textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        '未找到匹配章节',
                        style: TextStyle(
                          color: widget.textColor.withOpacity(0.72),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _listController,
                      itemExtent: _tocItemExtent,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final selected = item.chapterIndex != null
                            ? item.chapterIndex == widget.currentChapterIndex
                            : (() {
                                final nextPageIndex =
                                    index < filtered.length - 1
                                    ? filtered[index + 1].pageIndex
                                    : 1 << 30;
                                return widget.currentPage >= item.pageIndex &&
                                    widget.currentPage < nextPageIndex;
                              })();
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 0,
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : widget.textColor,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          trailing: Text(
                            item.chapterIndex != null
                                ? '${chapterNoByEntry[item] ?? index + 1}'
                                : '${item.pageIndex + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.textColor.withOpacity(0.56),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(
                              context,
                              _TocSelection(
                                pageIndex: item.pageIndex,
                                chapterIndex: item.chapterIndex,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderPageState extends ConsumerState<ReaderPage>
    with SingleTickerProviderStateMixin {
  static const String _prefFontSizePreset = 'reader_font_size_preset_v1';
  static const String _prefPaddingPreset = 'reader_padding_preset_v1';
  static const String _prefLineHeightPreset = 'reader_line_height_preset_v1';
  static const String _prefTextAlignPreset = 'reader_text_align_preset_v1';
  static const String _prefParagraphIndent = 'reader_paragraph_indent_v1';
  static const String _prefFontStylePreset = 'reader_font_style_preset_v1';
  static const bool _enablePageCountMode = false;
  // 禁用 keepPage 以避免 page storage 延迟
  final PageController _pageController = PageController(keepPage: false);
  final int _fallbackPages = 100;
  late final AnimationController _floatingCoverController;

  bool _showControls = false;
  int _currentPage = 0;

  bool _isLoadingTxt = false;
  bool _txtLoadScheduled = false;
  String? _txtError;
  String? _loadedTxtPath;
  List<_TxtChapter> _txtChapters = const [];
  Map<int, _TxtChapter> _txtChapterByIndex = const {};
  Map<int, int> _txtChapterGlobalStart = const {};
  int _txtTotalLength = 0;
  List<_TxtPage> _txtPages = const [];
  List<_TocEntry> _txtToc = const [];
  int _paginationSignature = -1;
  bool _isRepaginating = false;
  bool _repaginateScheduled = false;
  int _paginationJobId = 0;
  final Map<String, List<_TxtPage>> _txtPageCache = {};
  bool _isUserPaging = false;
  Completer<void>? _pagingIdleCompleter;
  int? _lastPageTurnStart; // 用于追踪翻页延迟

  Timer? _progressSaveDebounce;
  Timer? _repaginateDebounce;
  Timer? _readerPrefsSaveDebounce;
  int _readingTimeSeconds = 0;
  _ReaderPanel _activePanel = _ReaderPanel.none;
  double _brightnessValue = 0.65;
  int _fontSizePreset = 20;
  int _themeIndex = 2;
  int _paddingPreset = 1;
  int _lineHeightPreset = 2;
  bool _autoPageEnabled = false;
  Timer? _autoPageTimer;
  bool _canStartTxtLoad = true;
  int _textAlignPreset = 0;
  bool _paragraphIndentEnabled = true;
  int _fontStylePreset = 0;
  bool _isFloatingCoverSpinning = false;
  Offset? _floatingPlaybackOffset;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _floatingCoverController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    _applySystemUiVisibility();
    _loadReaderPreferences();
  }

  @override
  void dispose() {
    _progressSaveDebounce?.cancel();
    _repaginateDebounce?.cancel();
    _readerPrefsSaveDebounce?.cancel();
    _autoPageTimer?.cancel();
    _floatingCoverController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(bookByIdProvider(widget.bookId));
    final currentBook = bookAsync.valueOrNull ?? widget.initialBook;

    return WillPopScope(
      onWillPop: () async {
        await _persistCurrentBookProgress(currentBook);
        return true;
      },
      child: Scaffold(
        backgroundColor: _readerBgColor,
        body: bookAsync.when(
          data: (book) => _buildReader(book ?? widget.initialBook),
          loading: () => widget.initialBook != null
              ? _buildReader(widget.initialBook)
              : const Center(child: CircularProgressIndicator()),
          error: (error, stack) => widget.initialBook != null
              ? _buildReader(widget.initialBook)
              : Center(child: Text('Error: $error')),
        ),
      ),
    );
  }

  void _applySystemUiVisibility() {
    if (_showControls) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _loadReaderPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final font = prefs.getInt(_prefFontSizePreset);
    final padding = prefs.getInt(_prefPaddingPreset);
    final lineHeight = prefs.getInt(_prefLineHeightPreset);
    final textAlignPreset = prefs.getInt(_prefTextAlignPreset);
    final paragraphIndent = prefs.getBool(_prefParagraphIndent);
    final fontStylePreset = prefs.getInt(_prefFontStylePreset);
    if (!mounted) {
      return;
    }
    setState(() {
      if (font != null) {
        _fontSizePreset = font.clamp(16, 40);
      }
      if (padding != null) {
        _paddingPreset = padding.clamp(0, 2);
      }
      if (lineHeight != null) {
        _lineHeightPreset = lineHeight.clamp(0, 3);
      }
      if (textAlignPreset != null) {
        _textAlignPreset = textAlignPreset.clamp(0, 3);
      }
      if (paragraphIndent != null) {
        _paragraphIndentEnabled = paragraphIndent;
      }
      if (fontStylePreset != null) {
        _fontStylePreset = fontStylePreset.clamp(0, 2);
      }
    });
    if (_txtChapters.isNotEmpty) {
      _scheduleRepaginate(immediate: true);
    }
  }

  void _scheduleSaveReaderPreferences() {
    _readerPrefsSaveDebounce?.cancel();
    _readerPrefsSaveDebounce = Timer(
      const Duration(milliseconds: 220),
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefFontSizePreset, _fontSizePreset);
        await prefs.setInt(_prefPaddingPreset, _paddingPreset);
        await prefs.setInt(_prefLineHeightPreset, _lineHeightPreset);
        await prefs.setInt(_prefTextAlignPreset, _textAlignPreset);
        await prefs.setBool(_prefParagraphIndent, _paragraphIndentEnabled);
        await prefs.setInt(_prefFontStylePreset, _fontStylePreset);
      },
    );
  }

  Widget _buildReader(Book? book) {
    if (book == null) {
      return const Center(child: Text('Book not found'));
    }

    if (_isTxtBook(book) &&
        _loadedTxtPath != book.epubPath &&
        !_isLoadingTxt &&
        !_txtLoadScheduled &&
        _canStartTxtLoad) {
      _txtLoadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadTxtBook(book);
        }
      });
    }

    if (_isTxtBook(book) && _txtError != null) {
      return Center(child: Text(_txtError!));
    }

    final isPreparingTxt =
        _isTxtBook(book) &&
        (_isLoadingTxt ||
            _loadedTxtPath != book.epubPath ||
            _txtChapters.isEmpty);

    if (isPreparingTxt) {
      return _buildOpeningView(book);
    }

    if (_isTxtBook(book) && _txtPages.isEmpty) {
      _ensureTxtPagination();
      return _buildOpeningView(book);
    }

    final ttsState = ref.watch(ttsProvider);
    final totalPages = _resolveTotalPages(book);
    if (_enablePageCountMode && _isTxtBook(book) && _txtChapters.isNotEmpty) {
      _ensureTxtPagination();
    }

    return Stack(
      children: [
        // 底层：全局单击检测（立即响应）
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            _handleTap(details, totalPages);
          },
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    _setUserPaging(true);
                  } else if (notification is ScrollEndNotification) {
                    _setUserPaging(false);
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: totalPages,
                  pageSnapping: true,
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                    if (_isTxtBook(book)) {
                      _scheduleSaveTxtProgress(book);
                    }
                    if (_lastPageTurnStart != null) {
                      _lastPageTurnStart = null;
                    }
                  },
                  itemBuilder: (context, index) =>
                      _buildPageContent(index, book, ttsState),
                ),
              ),
              _buildTopBar(book),
              _buildBottomToolbar(book, totalPages),
              if (!_showControls && _activePanel == _ReaderPanel.none)
                _buildBottomPageIndicator(totalPages),
              // 临时注释：黑色蒙层可能挡住视线
              // if (_brightnessValue < 0.5)
              //   IgnorePointer(
              //     child: Container(
              //       color: Colors.black.withOpacity(
              //         (0.5 - _brightnessValue) * 0.9,
              //       ),
              //     ),
              //   ),
              // 悬浮听书按钮(非播放时显示)
              _buildFloatingAudiobookButton(book, totalPages),
              // 悬浮播放控制按钮(播放时显示)
              _buildPlaybackControlButton(book, totalPages),
            ],
          ),
        ), // GestureDetector 闭合
      ], // 最外层 Stack children 闭合
    ); // 最外层 Stack 闭合
  }

  Widget _buildOpeningView(Book book) {
    return Container(
      color: _readerBgColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(height: 12),
            Text(
              '正在打开《${book.title}》',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _textColor.withOpacity(0.72),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(int index, Book book, TtsAppState ttsState) {
    if (_isTxtBook(book) && _txtPages.isNotEmpty) {
      final page = _txtPages[index];
      final chapter = _txtChapterByIndex[page.chapterIndex];
      final chapterText = chapter?.content ?? '';
      final safeStart = page.startOffset.clamp(0, chapterText.length);
      final safeEnd = page.endOffset.clamp(safeStart, chapterText.length);
      final showChapterHeader =
          page.startOffset == 0 ||
          (index > 0 && _txtPages[index - 1].chapterIndex != page.chapterIndex);
      final isLastPageOfChapter =
          safeEnd >= chapterText.length ||
          (index < _txtPages.length - 1 &&
              _txtPages[index + 1].chapterIndex != page.chapterIndex);
      final endsAtParagraphBoundary = _endsAtParagraphBoundary(
        chapterText: chapterText,
        endOffset: safeEnd,
      );
      final visibleText = _visiblePageBodyText(
        chapterText: chapterText,
        start: safeStart,
        end: safeEnd,
        showChapterHeader: showChapterHeader,
        chapterTitle: page.title,
        isLastPageOfChapter: isLastPageOfChapter,
      );
      final pageTextAlign = _resolveTextAlign(
        visibleText,
        endsAtParagraphBoundary: endsAtParagraphBoundary,
        isLastPageOfChapter: isLastPageOfChapter,
      );
      final bodyStyle = TextStyle(
        fontSize: _contentFontSize,
        height: _contentLineHeight,
        color: _textColor,
        fontFamily: _contentFontFamily,
      );
      final highlightRange = _resolveTtsHighlightRange(
        ttsState: ttsState,
        chapterText: chapterText,
        pageStart: safeStart,
        pageEnd: safeEnd,
        visibleText: visibleText,
      );

      // 只在正在播放且有高亮时，使用包含进度信息的 key 确保高亮更新
      // 否则使用简化的 key 避免频繁重建
      final useHighlightKey = ttsState.isSpeaking && highlightRange != null;
      final pageBuildStart = DateTime.now().microsecondsSinceEpoch;

      // 日志：记录页面重建原因
      if (useHighlightKey) {
        print('🎵 页面 $index 包含高亮 key（TTS 播放中）');
      } else if (ttsState.isSpeaking) {
        print('📄 页面 $index 使用简化 key（TTS 播放但无高亮）');
      } else {
        print('📄 页面 $index 使用简化 key（TTS 未播放）');
      }

      return SafeArea(
        key: ValueKey(
          'reader-page-$index-'
          'speaking-${ttsState.isSpeaking}-'
          'paused-${ttsState.isPaused}'
          '${useHighlightKey ? '-highlight-${(ttsState.playbackProgress * 1000).round()}' : ''}',
        ),
        child: Padding(
          padding: _contentPadding,
          child: Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final buildDuration =
                    (DateTime.now().microsecondsSinceEpoch - pageBuildStart) /
                    1000.0;
                if (buildDuration > 2.0) {
                  print('⚠️  页面 $index 构建耗时: ${buildDuration}ms');
                }
              });
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: RichText(
                        textScaler: TextScaler.noScaling,
                        textAlign: pageTextAlign,
                        textWidthBasis: TextWidthBasis.longestLine,
                        strutStyle: _contentStrutStyle,
                        text: TextSpan(
                          style: bodyStyle,
                          children: _buildPageTextSpans(
                            text: visibleText,
                            bodyStyle: bodyStyle,
                            chapterTitle: showChapterHeader ? page.title : null,
                            startsAtParagraphBoundary:
                                _startsAtParagraphBoundary(
                                  chapterText: chapterText,
                                  startOffset: safeStart,
                                ),
                            highlightStart: highlightRange?.start,
                            highlightEnd: highlightRange?.end,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 42),
        child: Text(
          'Book content for ${book.title}...\n\n'
          'This is a placeholder for EPUB rendering.',
          style: const TextStyle(fontSize: 17, height: 1.8),
        ),
      ),
    );
  }

  Widget _buildTopBar(Book book) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: _showControls ? Offset.zero : const Offset(0, -1.1),
        child: IgnorePointer(
          ignoring: !_showControls,
          child: Container(
            decoration: BoxDecoration(
              color: _controlSurfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border(
                bottom: BorderSide(
                  color: Colors.black.withOpacity(0.08),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        iconSize: 20,
                        icon: Icon(Icons.arrow_back, color: _textColor),
                        onPressed: () async {
                          await _persistCurrentBookProgress(book);
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: _textColor,
                            fontWeight: FontWeight.w500,
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

  Widget _buildBottomPageIndicator(int totalPages) {
    return Positioned(
      right: 20,
      bottom: 0,
      child: SafeArea(
        child: Text(
          '${(_currentProgressPercent * 100).clamp(0, 100).toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 13,
            color: _textColor.withOpacity(0.55),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(Book book, int totalPages) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: _showControls ? Offset.zero : const Offset(0, 1.1),
        child: IgnorePointer(
          ignoring: !_showControls,
          child: Container(
            decoration: BoxDecoration(
              color: _controlSurfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
              border: Border(
                top: BorderSide(
                  color: Colors.black.withOpacity(0.08),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _toolButton(
                    icon: CupertinoIcons.list_bullet,
                    active: _activePanel == _ReaderPanel.toc,
                    onTap: () => _openPanel(_ReaderPanel.toc, () async {
                      await _showTableOfContents(book);
                    }),
                  ),
                  _toolButton(
                    icon: CupertinoIcons.square_pencil,
                    active: _activePanel == _ReaderPanel.notes,
                    onTap: () => _openPanel(_ReaderPanel.notes, () async {
                      await _showReaderActionPanel(
                        title: '笔记',
                        child: const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('暂无笔记，长按正文即可添加。'),
                        ),
                      );
                    }),
                  ),
                  _toolButton(
                    icon: CupertinoIcons.circle,
                    active: _activePanel == _ReaderPanel.progress,
                    onTap: () => _openPanel(_ReaderPanel.progress, () async {
                      await _showProgressPanel(book, totalPages);
                    }),
                  ),
                  _toolButton(
                    icon: CupertinoIcons.sun_max,
                    active: _activePanel == _ReaderPanel.theme,
                    onTap: () => _openPanel(_ReaderPanel.theme, () async {
                      await _showThemePanel();
                    }),
                  ),
                  _toolButton(
                    icon: CupertinoIcons.textformat_size,
                    active: _activePanel == _ReaderPanel.typography,
                    onTap: () => _openPanel(_ReaderPanel.typography, () async {
                      await _showTypographyPanel();
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    // 黑色背景时用更亮的颜色，浅色背景时用深色
    final baseColor = _themeIndex == 4
        ? Colors.white70
        : const Color(0xFF1F2A1F);
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 24,
      splashRadius: 22,
      color: active ? baseColor : baseColor.withOpacity(0.82),
      onPressed: onTap,
      icon: Icon(icon, weight: 50, grade: -25, opticalSize: 22),
    );
  }

  Future<void> _showReaderActionPanel({
    required String title,
    required Widget child,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: _controlSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Wrap(
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _textColor.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _textColor,
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPanel(
    _ReaderPanel panel,
    Future<void> Function() action,
  ) async {
    setState(() {
      _activePanel = panel;
    });
    await action();
    if (mounted) {
      setState(() {
        _activePanel = _ReaderPanel.none;
      });
    }
  }

  Future<void> _showTableOfContents(Book book) async {
    final entries = _buildTocEntries(book);
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final safeAreaTop = mediaQuery.padding.top;
    final safeAreaBottom = mediaQuery.padding.bottom;

    // 目录弹窗尽量占满屏幕，优先展示更多目录项。
    final maxHeight = min(
      screenHeight * 0.95,
      screenHeight - safeAreaTop - safeAreaBottom,
    );
    final desiredHeight = maxHeight;
    final currentTxtChapter = _txtPages.isNotEmpty
        ? _txtPages[_currentPage.clamp(0, _txtPages.length - 1)].chapterIndex
        : null;
    final currentTocIndex = currentTxtChapter == null
        ? entries.lastIndexWhere((entry) => entry.pageIndex <= _currentPage)
        : entries.lastIndexWhere(
            (entry) => entry.chapterIndex == currentTxtChapter,
          );
    final selection = await showModalBottomSheet<_TocSelection>(
      context: context,
      backgroundColor: _controlSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (context) => _TableOfContentsSheet(
        entries: entries,
        height: desiredHeight,
        textColor: _textColor,
        currentPage: _currentPage,
        currentChapterIndex: currentTxtChapter,
        initialTocIndex: currentTocIndex,
      ),
    );
    if (!mounted || selection == null) {
      return;
    }
    // 选择章节后隐藏控制面板，回到正文页面
    setState(() {
      _showControls = false;
    });
    _applySystemUiVisibility();

    if (selection.chapterIndex != null) {
      _jumpToTxtChapter(selection.chapterIndex!);
    } else {
      _jumpToPage(selection.pageIndex);
    }
  }

  Future<void> _showProgressPanel(Book book, int totalPages) async {
    final isTxt = _isTxtBook(book);
    final progressValue = _currentProgressPercent.clamp(0.0, 1.0);
    await _showReaderActionPanel(
      title: '阅读进度',
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              _metricCell(
                '${(progressValue * 100).toStringAsFixed(1)}%',
                '约21小时后读完',
              ),
              _metricCell('18 分钟', '阅读时长'),
              _metricCell('0 条', '笔记'),
            ],
          ),
          const SizedBox(height: 12),
          isTxt
              ? _buildThemedSlider(
                  value: progressValue,
                  min: 0,
                  max: 1,
                  onChanged: (v) => _jumpToTxtProgress(v),
                )
              : _buildThemedSlider(
                  value: _currentPage.toDouble(),
                  min: 0,
                  max: (totalPages - 1).toDouble(),
                  onChanged: (v) => _jumpToPage(v.round()),
                ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _actionPill('阅读明细')),
              const SizedBox(width: 10),
              Expanded(child: _actionPill('开启自动翻页')),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _autoPageEnabled,
            onChanged: (value) {
              setState(() {
                _autoPageEnabled = value;
              });
              _updateAutoPageTimer(totalPages);
            },
            title: Text('自动翻页', style: TextStyle(color: _textColor)),
            dense: true,
          ),
        ],
      ),
    );
  }

  Future<void> _showThemePanel() async {
    final themeColors = [
      _ThemeOption(
        id: 0,
        color: const Color(0xFFF3F3F3),
        name: '浅色',
        icon: Icons.light_mode_rounded,
      ),
      _ThemeOption(
        id: 1,
        color: const Color(0xFFE8E2D6),
        name: '米色',
        icon: Icons.brightness_4_rounded,
      ),
      _ThemeOption(
        id: 2,
        color: const Color(0xFFF1F4EE),
        name: '薄荷绿',
        icon: Icons.emoji_nature_rounded,
      ),
      _ThemeOption(
        id: 3,
        color: const Color(0xFFA6C39D),
        name: '绿色',
        icon: Icons.nature_rounded,
      ),
      _ThemeOption(
        id: 4,
        color: const Color(0xFF111111),
        name: '深色',
        icon: Icons.dark_mode_rounded,
      ),
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: _controlSurfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Calculate background color based on current theme
          final backgroundColor = _controlSurfaceColor;
          final textColor = _textColor;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: backgroundColor,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Wrap(
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: textColor.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        '亮度与颜色',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        // Brightness card with modern slider
                        Container(
                          decoration: BoxDecoration(
                            color: _readerBgColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: _textColor.withOpacity(0.06),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.brightness_6_rounded,
                                            size: 18,
                                            color: _textColor.withOpacity(0.7),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '亮度',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: _textColor,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF3B82F6,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${(_brightnessValue * 100).round()}%',
                                        style: TextStyle(
                                          color: const Color(0xFF3B82F6),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Modern brightness slider with icons
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.brightness_2_rounded,
                                      size: 20,
                                      color: _textColor.withOpacity(0.4),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          sliderTheme: SliderThemeData(
                                            activeTrackColor: const Color(
                                              0xFF3B82F6,
                                            ),
                                            inactiveTrackColor: _textColor
                                                .withOpacity(0.15),
                                            thumbColor: const Color(0xFF3B82F6),
                                            overlayColor: const Color(
                                              0xFF3B82F6,
                                            ).withOpacity(0.1),
                                            trackHeight: 4,
                                            thumbShape:
                                                const RoundSliderThumbShape(
                                                  enabledThumbRadius: 10,
                                                ),
                                            overlayShape:
                                                const RoundSliderOverlayShape(
                                                  overlayRadius: 18,
                                                ),
                                            showValueIndicator:
                                                ShowValueIndicator
                                                    .onlyForDiscrete,
                                          ),
                                        ),
                                        child: Slider(
                                          value: _brightnessValue,
                                          min: 0,
                                          max: 1,
                                          divisions: 20,
                                          label:
                                              '${(_brightnessValue * 100).round()}%',
                                          onChanged: (v) {
                                            setState(
                                              () => _brightnessValue = v,
                                            );
                                            setModalState(
                                              () => _brightnessValue = v,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.brightness_7_rounded,
                                      size: 20,
                                      color: _textColor.withOpacity(0.4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Theme color selection - 3 columns top, 2 columns bottom
                        SizedBox(
                          height: 240,
                          child: Column(
                            children: [
                              // First row: 3 columns
                              Row(
                                children: [
                                  Expanded(
                                    child: _ColorOptionCard(
                                      theme: themeColors[0],
                                      isSelected: _themeIndex == 0,
                                      onTap: () {
                                        setState(() => _themeIndex = 0);
                                        setModalState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ColorOptionCard(
                                      theme: themeColors[1],
                                      isSelected: _themeIndex == 1,
                                      onTap: () {
                                        setState(() => _themeIndex = 1);
                                        setModalState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ColorOptionCard(
                                      theme: themeColors[2],
                                      isSelected: _themeIndex == 2,
                                      onTap: () {
                                        setState(() => _themeIndex = 2);
                                        setModalState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Second row: 2 columns, centered
                              Row(
                                children: [
                                  Expanded(
                                    child: _ColorOptionCard(
                                      theme: themeColors[3],
                                      isSelected: _themeIndex == 3,
                                      onTap: () {
                                        setState(() => _themeIndex = 3);
                                        setModalState(() {});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _ColorOptionCard(
                                      theme: themeColors[4],
                                      isSelected: _themeIndex == 4,
                                      onTap: () {
                                        setState(() => _themeIndex = 4);
                                        setModalState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _ColorOptionCard({
    required _ThemeOption theme,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: theme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
              width: isSelected ? 3 : 0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  theme.icon,
                  size: 28,
                  color: theme.id == 3
                      ? Colors.white.withOpacity(0.9)
                      : Colors.black87.withOpacity(0.7),
                ),
                const SizedBox(height: 8),
                Text(
                  theme.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: theme.id == 3
                        ? Colors.white.withOpacity(0.9)
                        : Colors.black87.withOpacity(0.7),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showTypographyPanel() async {
    const paddingLabels = ['小', '边距', '大'];
    const lineHeightLabels = ['紧', '行距', '松'];

    await _showReaderActionPanel(
      title: '字体设置',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final fontSize = _fontSizePreset.clamp(16, 40);
          final lineHeightDisplayIndex = _lineHeightPreset <= 1
              ? 0
              : _lineHeightPreset == 2
              ? 1
              : 2;

          void updateTypography({
            int? font,
            int? padding,
            int? lineHeight,
            bool repaginate = true,
          }) {
            setState(() {
              if (font != null) {
                _fontSizePreset = font.clamp(16, 40);
              }
              if (padding != null) {
                _paddingPreset = padding.clamp(0, 2);
              }
              if (lineHeight != null) {
                _lineHeightPreset = lineHeight.clamp(0, 3);
              }
            });
            setModalState(() {});
            _scheduleSaveReaderPreferences();
            if (repaginate) {
              _scheduleRepaginate();
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Font size card with modern Bento Grid style
              Container(
                decoration: BoxDecoration(
                  color: _readerBgColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Header label
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '字体大小',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _textColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$fontSize',
                              style: TextStyle(
                                color: const Color(0xFF3B82F6),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Slider with preview
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _textColor.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'A',
                              style: TextStyle(
                                fontSize: 14,
                                color: _textColor.withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                sliderTheme: SliderThemeData(
                                  activeTrackColor: const Color(0xFF3B82F6),
                                  inactiveTrackColor: _textColor.withOpacity(
                                    0.15,
                                  ),
                                  thumbColor: const Color(0xFF3B82F6),
                                  overlayColor: const Color(
                                    0xFF3B82F6,
                                  ).withOpacity(0.1),
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 10,
                                  ),
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 18,
                                  ),
                                  showValueIndicator:
                                      ShowValueIndicator.onlyForDiscrete,
                                ),
                              ),
                              child: Slider(
                                value: fontSize.toDouble(),
                                min: 16,
                                max: 40,
                                divisions: 12,
                                label: '$fontSize',
                                onChanged: (v) =>
                                    updateTypography(font: v.round()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _textColor.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'A',
                              style: TextStyle(
                                fontSize: 26,
                                color: _textColor.withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Quick settings cards in 2-column grid
              Row(
                children: [
                  Expanded(
                    child: _modernSegmentCard(
                      label: '边距',
                      labels: paddingLabels,
                      selectedIndex: _paddingPreset,
                      onSelect: (index) => updateTypography(padding: index),
                      icon: Icons.format_indent_increase_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _modernSegmentCard(
                      label: '行距',
                      labels: lineHeightLabels,
                      selectedIndex: lineHeightDisplayIndex,
                      onSelect: (index) {
                        final mapped = index == 0
                            ? 1
                            : index == 1
                            ? 2
                            : 3;
                        updateTypography(lineHeight: mapped);
                      },
                      icon: Icons.format_line_spacing_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Additional settings row
              Row(
                children: [
                  Expanded(
                    child: _modernSettingCard(
                      title: '字体样式',
                      subtitle: '默认', // TODO: Get current font style
                      icon: Icons.text_fields_rounded,
                      onTap: () async {
                        await _showFontStyleAndLayoutPanel();
                        if (mounted) {
                          setModalState(() {});
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _modernSettingCard(
                      title: '首行设置',
                      subtitle: _paragraphIndentEnabled ? '缩进' : '顶格',
                      icon: Icons.format_align_left_rounded,
                      onTap: () async {
                        await _showParagraphIndentPanel();
                        if (mounted) {
                          setModalState(() {});
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _modernActionButton(
                      label: '恢复默认',
                      isSecondary: false,
                      onTap: () {
                        setState(() {
                          _fontSizePreset = 20;
                          _paddingPreset = 1;
                          _lineHeightPreset = 2;
                          _textAlignPreset = 0;
                          _paragraphIndentEnabled = true;
                          _fontStylePreset = 0;
                        });
                        setModalState(() {});
                        _scheduleSaveReaderPreferences();
                        _scheduleRepaginate();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _modernActionButton(
                      label: '完成',
                      isSecondary: true,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _modernSegmentCard({
    required String label,
    required List<String> labels,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _readerBgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _textColor.withOpacity(0.6)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textColor.withOpacity(0.8),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(labels.length, (index) {
              final isSelected = index == selectedIndex;
              return GestureDetector(
                onTap: () => onSelect(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : _textColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : _textColor.withOpacity(0.7),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _modernSettingCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: _readerBgColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _textColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: _textColor.withOpacity(0.7)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: _textColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: _textColor.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modernActionButton({
    required String label,
    required bool isSecondary,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSecondary
                ? const Color(0xFF3B82F6)
                : _textColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSecondary
                ? [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSecondary ? Colors.white : _textColor,
                  letterSpacing: 0.3,
                ),
              ),
              if (!isSecondary) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: _textColor.withOpacity(0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFontStyleAndLayoutPanel() async {
    const styleOptions = ['默认', '衬线', '等宽'];
    const alignOptions = ['自动', '两端', '左对齐', '居中'];
    var draftStyle = _fontStylePreset;
    var draftAlign = _textAlignPreset;

    await _showReaderActionPanel(
      title: '字体样式',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _panelSubTitle('字体'),
              const SizedBox(height: 8),
              _segmentedChoices(
                labels: styleOptions,
                selectedIndex: draftStyle,
                onSelect: (index) {
                  draftStyle = index.clamp(0, 2);
                  setModalState(() {});
                },
              ),
              const SizedBox(height: 12),
              _panelSubTitle('布局方式'),
              const SizedBox(height: 8),
              _segmentedChoices(
                labels: alignOptions,
                selectedIndex: draftAlign,
                onSelect: (index) {
                  draftAlign = index.clamp(0, 3);
                  setModalState(() {});
                },
              ),
              const SizedBox(height: 12),
              _actionPill(
                '应用',
                textColor: _textColor,
                bgColor: _textColor.withOpacity(0.08),
                onTap: () {
                  setState(() {
                    _fontStylePreset = draftStyle;
                    _textAlignPreset = draftAlign;
                  });
                  _scheduleSaveReaderPreferences();
                  _scheduleRepaginate();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showParagraphIndentPanel() async {
    const options = ['首行缩进', '首行顶格'];
    var draft = _paragraphIndentEnabled ? 0 : 1;

    await _showReaderActionPanel(
      title: '首行顶格',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            children: [
              const SizedBox(height: 8),
              _segmentedChoices(
                labels: options,
                selectedIndex: draft,
                onSelect: (index) {
                  draft = index.clamp(0, 1);
                  setModalState(() {});
                },
              ),
              const SizedBox(height: 12),
              _actionPill(
                '应用',
                textColor: _textColor,
                bgColor: _textColor.withOpacity(0.08),
                onTap: () {
                  setState(() {
                    _paragraphIndentEnabled = draft == 0;
                  });
                  _scheduleSaveReaderPreferences();
                  _scheduleRepaginate();
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemedSlider({
    required double value,
    required double min,
    required double max,
    int? divisions,
    required ValueChanged<double> onChanged,
  }) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: _textColor.withOpacity(0.45),
        inactiveTrackColor: _textColor.withOpacity(0.2),
        thumbColor: _textColor,
        overlayColor: _textColor.withOpacity(0.12),
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }

  Widget _metricCell(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: _textColor.withOpacity(0.65)),
          ),
        ],
      ),
    );
  }

  Widget _actionPill(
    String text, {
    Color? textColor,
    Color? bgColor,
    VoidCallback? onTap,
  }) {
    if (_isIOS) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor ?? _textColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(21),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: textColor ?? _textColor,
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor ?? _textColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(21),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: textColor ?? _textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelSubTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: _textColor.withOpacity(0.85),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _segmentedChoices({
    required List<String> labels,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
  }) {
    if (_isIOS) {
      return CupertinoSlidingSegmentedControl<int>(
        groupValue: selectedIndex,
        thumbColor: _textColor.withOpacity(0.22),
        backgroundColor: _textColor.withOpacity(0.1),
        children: {
          for (var i = 0; i < labels.length; i++)
            i: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Text(
                labels[i],
                style: TextStyle(
                  color: _textColor.withOpacity(
                    selectedIndex == i ? 0.98 : 0.72,
                  ),
                  fontSize: 12,
                  fontWeight: selectedIndex == i
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
        },
        onValueChanged: (value) {
          if (value != null) {
            onSelect(value);
          }
        },
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _textColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? _textColor.withOpacity(0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  labels[index],
                  style: TextStyle(
                    color: _textColor.withOpacity(selected ? 0.95 : 0.68),
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _handleTap(TapUpDetails details, int totalPages) {
    final tapStart = DateTime.now().microsecondsSinceEpoch;
    final width = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;

    if (dx < width * 0.3) {
      if (_txtPages.isNotEmpty && _currentPage == 0) {
        _handleTxtEdgePaging(previous: true);
      }
      _turnPage(forward: false, totalPages: totalPages, tapStart: tapStart);
      _lastPageTurnStart = tapStart;
      return;
    }

    if (dx > width * 0.7) {
      if (_txtPages.isNotEmpty && _currentPage >= totalPages - 1) {
        _handleTxtEdgePaging(previous: false);
      }
      _turnPage(forward: true, totalPages: totalPages, tapStart: tapStart);
      _lastPageTurnStart = tapStart;
      return;
    }

    setState(() {
      _showControls = !_showControls;
    });
    _applySystemUiVisibility();
  }

  _AudiobookLaunchData? _buildAudiobookLaunchData(Book book) {
    if (_isTxtBook(book) && _txtPages.isNotEmpty) {
      final pageIndex = _currentPage.clamp(0, _txtPages.length - 1);
      final page = _txtPages[pageIndex];
      final chapter = _txtChapterByIndex[page.chapterIndex];
      final chapterText = chapter?.content ?? '';
      if (chapterText.trim().isEmpty) {
        return null;
      }

      final safeStart = page.startOffset.clamp(0, chapterText.length);
      final safeEnd = page.endOffset.clamp(safeStart, chapterText.length);
      final preview = safeEnd > safeStart
          ? chapterText.substring(safeStart, safeEnd)
          : chapterText.substring(safeStart);

      var lookbackStartOffset = safeStart;
      if (pageIndex > 0) {
        final previousPage = _txtPages[pageIndex - 1];
        if (previousPage.chapterIndex == page.chapterIndex) {
          lookbackStartOffset = previousPage.startOffset.clamp(0, safeStart);
        }
      }
      String? nextChapterTitle;
      String? nextChapterText;
      int? nextChapterIndex;
      final chapterQueue = _txtChapters
          .where((item) => item.content.trim().isNotEmpty)
          .map(
            (item) => AudiobookChapterPayload(
              title: item.title,
              text: item.content,
              index: item.index,
            ),
          )
          .toList(growable: false);
      final currentChapterPos = _txtChapters.indexWhere(
        (item) => item.index == page.chapterIndex,
      );
      if (currentChapterPos >= 0 &&
          currentChapterPos + 1 < _txtChapters.length) {
        final nextChapter = _txtChapters[currentChapterPos + 1];
        nextChapterTitle = nextChapter.title;
        nextChapterText = nextChapter.content;
        nextChapterIndex = nextChapter.index;
      }

      return _AudiobookLaunchData(
        initialText: preview.isEmpty ? chapterText : preview,
        chapterTitle: page.title,
        chapterText: chapterText,
        chapterIndex: page.chapterIndex,
        initialOffset: safeStart,
        lookbackStartOffset: lookbackStartOffset,
        nextChapterTitle: nextChapterTitle,
        nextChapterText: nextChapterText,
        nextChapterIndex: nextChapterIndex,
        chapterQueue: chapterQueue,
      );
    }

    final epubText = _getEpubPageText(book) ?? '';
    if (epubText.trim().isEmpty) {
      return null;
    }
    return _AudiobookLaunchData(initialText: epubText);
  }

  Future<void> _openAudiobookSheet(Book book, int totalPages) async {
    final launchData = _buildAudiobookLaunchData(book);
    if (!mounted || launchData == null) {
      return;
    }

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        return SizedBox(
          height: screenHeight,
          child: AudiobookPage(
            book: book,
            initialText: launchData.initialText,
            initialPage: _currentPage,
            totalPages: totalPages,
            chapterTitle: launchData.chapterTitle,
            chapterText: launchData.chapterText,
            chapterIndex: launchData.chapterIndex,
            initialOffset: launchData.initialOffset,
            lookbackStartOffset: launchData.lookbackStartOffset,
            nextChapterTitle: launchData.nextChapterTitle,
            nextChapterText: launchData.nextChapterText,
            nextChapterIndex: launchData.nextChapterIndex,
            chapterQueue: launchData.chapterQueue,
            bgColor: _readerBgColor,
          ),
        );
      },
    );

    ref.read(ttsProvider.notifier).setAudiobookUiVisible(false);
    _applySystemUiVisibility();

    if (result != null) {
      await _handleAudiobookResult(result, book, totalPages);
    }
  }

  Future<void> _handleAudiobookResult(
    Map<String, dynamic> result,
    Book book,
    int totalPages,
  ) async {
    final action = result['action'] as String?;
    final page = result['page'] as int?;

    if ((action == 'next_page' ||
            action == 'prev_page' ||
            action == 'goto_page') &&
        page != null) {
      _jumpToPage(page);
      return;
    }

    if (action == 'goto_txt_location') {
      final chapterIndex = result['chapterIndex'] as int?;
      final offset = result['offset'] as int?;
      if (chapterIndex != null && offset != null) {
        _jumpToTxtLocation(chapterIndex, offset);
      }
      return;
    }

    if (action == 'auto_next_txt_chapter') {
      final currentChapterIndex = result['chapterIndex'] as int?;
      final nextChapterIndex = _nextTxtChapterIndex(currentChapterIndex);
      if (nextChapterIndex == null) {
        return;
      }
      _jumpToTxtChapter(nextChapterIndex);
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) {
        return;
      }
      await _openAudiobookSheet(book, totalPages);
    }
  }

  Future<void> _toggleReaderPlayback({
    required Book book,
    required int totalPages,
    required TtsAppState ttsState,
    required bool canPlay,
  }) async {
    final isLoadingAudio =
        ttsState.isLoadingAudio && !ttsState.isSpeaking && !ttsState.isPaused;
    final canTapPlayback = canPlay && (!isLoadingAudio || ttsState.isPaused);
    if (!canTapPlayback) {
      return;
    }

    if (ttsState.isPaused) {
      await ref.read(ttsProvider.notifier).resume();
      return;
    }

    if (ttsState.isSpeaking) {
      await ref.read(ttsProvider.notifier).pause();
      return;
    }

    await _openAudiobookSheet(book, totalPages);
  }

  int? _nextTxtChapterIndex(int? currentChapterIndex) {
    if (currentChapterIndex == null || _txtChapters.isEmpty) {
      return null;
    }
    final currentPos = _txtChapters.indexWhere(
      (chapter) => chapter.index == currentChapterIndex,
    );
    if (currentPos < 0 || currentPos + 1 >= _txtChapters.length) {
      return null;
    }
    return _txtChapters[currentPos + 1].index;
  }

  void _jumpToTxtLocation(int chapterIndex, int offset) {
    if (_txtChapters.isEmpty || _txtChapterByIndex.isEmpty) {
      return;
    }
    final chapter = _txtChapterByIndex[chapterIndex];
    if (chapter == null) {
      return;
    }
    final safeOffset = offset.clamp(0, chapter.content.length);
    final location = 'txt:$chapterIndex:$safeOffset';
    final rebuilt = _buildQuickPagesFromLocation(
      chapters: _txtChapters,
      chapterByIndex: _txtChapterByIndex,
      location: location,
    );
    if (rebuilt.isEmpty) {
      return;
    }
    final targetPage = _resolvePageFromLocation(location, rebuilt);
    setState(() {
      _txtPages = rebuilt;
      _txtToc = _buildTocFromPages(rebuilt);
      _currentPage = targetPage;
    });
    _restorePageAfterBuild(targetPage);
  }

  void _handleTxtEdgePaging({required bool previous}) {
    if (_txtPages.isEmpty ||
        _txtChapters.isEmpty ||
        _txtChapterByIndex.isEmpty) {
      return;
    }
    final current = _txtPages[_currentPage.clamp(0, _txtPages.length - 1)];
    final location = 'txt:${current.chapterIndex}:${current.startOffset}';
    final rebuilt = _buildQuickPagesFromLocation(
      chapters: _txtChapters,
      chapterByIndex: _txtChapterByIndex,
      location: location,
    );
    if (rebuilt.isEmpty) {
      return;
    }
    final at = _resolvePageFromLocation(location, rebuilt);
    final target = previous ? max(0, at - 1) : min(rebuilt.length - 1, at + 1);
    setState(() {
      _txtPages = rebuilt;
      _txtToc = _buildTocFromPages(rebuilt);
      _currentPage = target;
    });
    _restorePageAfterBuild(target);
  }

  void _jumpToPage(int page, {int? tapStart, int? computeStart}) {
    final jumpStart = DateTime.now().microsecondsSinceEpoch;
    final currentPageBefore = _pageController.hasClients
        ? _pageController.page
        : null;

    if (!_pageController.hasClients) {
      print('❌ _jumpToPage: pageController has no clients');
      return;
    }

    // 检查 PageController 是否正在动画中或忙
    final position = _pageController.position;
    print(
      '🔍 PageController 状态: hasClients=true, page=$currentPageBefore, position=$position',
    );

    // 直接跳转以提供即时响应，快速点击时也能正常工作
    print('🔄 _jumpToPage: 从页面 ${currentPageBefore ?? "null"} 跳转到 $page');
    _pageController.jumpToPage(page);

    final jumpEnd = DateTime.now().microsecondsSinceEpoch;
    final currentPageAfter = _pageController.page;

    // 打印时间戳日志
    if (tapStart != null) {
      print('📊 翻页延迟分析:');
      print('  点击事件 → _handleTap: 0ms');
      print(
        '  _handleTap → _turnPage: ${(computeStart! - tapStart) / 1000}μs = ${(computeStart! - tapStart) / 1000.0}ms',
      );
      print(
        '  _turnPage → _jumpToPage: ${(jumpStart - computeStart!) / 1000}μs = ${(jumpStart - computeStart!) / 1000.0}ms',
      );
      print(
        '  _jumpToPage 完成: ${(jumpEnd - jumpStart) / 1000}μs = ${(jumpEnd - jumpStart) / 1000.0}ms',
      );
      print('  跳转前页面: $currentPageBefore, 跳转后页面: $currentPageAfter');
      print(
        '  总耗时: ${(jumpEnd - tapStart) / 1000}μs = ${(jumpEnd - tapStart) / 1000.0}ms',
      );
    }

    // 添加延时的帧检查
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final frameTime = DateTime.now().microsecondsSinceEpoch;
      final currentPageInFrame = _pageController.page;
      if (tapStart != null && _lastPageTurnStart == tapStart) {
        print(
          '🎯 下一帧检查: 帧延迟 = ${(frameTime - tapStart) / 1000.0}ms, 当前页 = $currentPageInFrame',
        );
      }
    });

    // 再添加一个更长时间的检查（500ms 后），确认页面是否真的更新了
    Future.delayed(const Duration(milliseconds: 500), () {
      final delayedPage = _pageController.page;
      if (tapStart != null && _lastPageTurnStart == null) {
        // 如果 500ms 后 _lastPageTurnStart 还是 null，说明 onPageChanged 已经触发
        print('⏰ 500ms 后检查: 页面已更新到 $delayedPage，onPageChanged 已触发');
      } else if (tapStart != null && _lastPageTurnStart != null) {
        // 如果 500ms 后 _lastPageTurnStart 还在，说明 onPageChanged 仍未触发
        print('⚠️  500ms 后检查: 页面当前为 $delayedPage，但 onPageChanged 尚未触发！');
      }
    });
  }

  void _turnPage({
    required bool forward,
    required int totalPages,
    int? tapStart,
  }) {
    final computeStart = DateTime.now().microsecondsSinceEpoch;
    final target = forward
        ? min(totalPages - 1, _currentPage + 1)
        : max(0, _currentPage - 1);

    print(
      '🎯 _turnPage: forward=$forward, _currentPage=$_currentPage, target=$target, totalPages=$totalPages',
    );

    if (target == _currentPage) {
      print('⛔ _turnPage: 目标页面 $target 等于当前页面 $_currentPage，不翻页');
      return;
    }

    print('✓ _turnPage: 准备跳转到页面 $target');
    _jumpToPage(target, tapStart: tapStart, computeStart: computeStart);
  }

  void _setUserPaging(bool paging) {
    if (_isUserPaging == paging) {
      print('⚠️  _setUserPaging: 状态已经是 $paging，跳过设置');
      return;
    }
    print('🔄 _setUserPaging: 从 $_isUserPaging 改变为 $paging');
    _isUserPaging = paging;
    if (!paging) {
      _pagingIdleCompleter?.complete();
      _pagingIdleCompleter = null;
    } else {
      _pagingIdleCompleter ??= Completer<void>();
    }
  }

  Future<void> _waitForPagingIdle() async {
    if (!_isUserPaging) {
      return;
    }
    _pagingIdleCompleter ??= Completer<void>();
    await _pagingIdleCompleter!.future;
  }

  void _restorePageAfterBuild(int page, {int retries = 8}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_pageController.hasClients) {
        _pageController.jumpToPage(page);
        return;
      }
      if (retries <= 0) {
        return;
      }
      Future<void>.delayed(const Duration(milliseconds: 16), () {
        _restorePageAfterBuild(page, retries: retries - 1);
      });
    });
  }

  void _updateAutoPageTimer(int totalPages) {
    _autoPageTimer?.cancel();
    if (!_autoPageEnabled) {
      return;
    }
    _autoPageTimer = Timer.periodic(const Duration(seconds: 9), (_) {
      if (!_pageController.hasClients) {
        return;
      }
      final next = _currentPage + 1;
      if (next >= totalPages) {
        setState(() {
          _autoPageEnabled = false;
        });
        _autoPageTimer?.cancel();
        return;
      }
      _jumpToPage(next);
    });
  }

  Future<void> _loadTxtBook(Book book) async {
    setState(() {
      _isLoadingTxt = true;
      _txtError = null;
    });

    try {
      final text = await _readTxtContent(book.epubPath);
      final prepared = await compute(_prepareTxtChapterData, text);
      final chapters = (prepared['chapters'] as List<dynamic>)
          .map(
            (e) => _TxtChapter(
              title: e['title'] as String,
              content: e['content'] as String,
              index: e['index'] as int,
            ),
          )
          .toList();

      final existingProgress = await ref
          .read(getReadingProgressUseCaseProvider)
          .call(book.id);
      _readingTimeSeconds = existingProgress?.readingTimeSeconds ?? 0;

      if (!mounted) {
        return;
      }

      final chapterByIndex = <int, _TxtChapter>{
        for (final chapter in chapters) chapter.index: chapter,
      };
      var totalLength = 0;
      final chapterGlobalStart = <int, int>{};
      for (final chapter in chapters) {
        chapterGlobalStart[chapter.index] = totalLength;
        totalLength += chapter.content.length;
      }

      if (_enablePageCountMode) {
        final signature = _buildPaginationSignature();
        final persistedPages = await _readPersistedPagination(
          bookId: book.id,
          signature: signature,
          chapterByIndex: chapterByIndex,
        );

        if (persistedPages != null && persistedPages.isNotEmpty) {
          final persistedToc = _buildTocFromPages(persistedPages);
          final persistedPage = _resolvePageFromLocation(
            existingProgress?.location,
            persistedPages,
          );
          setState(() {
            _txtChapters = chapters;
            _txtChapterByIndex = chapterByIndex;
            _txtChapterGlobalStart = chapterGlobalStart;
            _txtTotalLength = totalLength;
            _txtPages = persistedPages;
            _txtToc = persistedToc;
            _loadedTxtPath = book.epubPath;
            _currentPage = persistedPage;
            _paginationSignature = signature;
            _isLoadingTxt = false;
            _txtLoadScheduled = false;
          });
          _txtPageCache.clear();
          _txtPageCache[_buildPaginationCacheKey(signature)] =
              List<_TxtPage>.unmodifiable(persistedPages);
          _restorePageAfterBuild(persistedPage);
          return;
        }
      }

      final quickPages = _buildQuickPagesFromLocation(
        chapters: chapters,
        chapterByIndex: chapterByIndex,
        location: existingProgress?.location,
      );
      final quickToc = _buildTocFromPages(quickPages);
      final quickPage = _resolvePageFromLocation(
        existingProgress?.location,
        quickPages,
      );

      setState(() {
        _txtChapters = chapters;
        _txtChapterByIndex = chapterByIndex;
        _txtChapterGlobalStart = chapterGlobalStart;
        _txtTotalLength = totalLength;
        _txtPages = quickPages;
        _txtToc = quickToc;
        _loadedTxtPath = book.epubPath;
        _currentPage = quickPage;
        _paginationSignature = -1;
        _isLoadingTxt = false;
        _txtLoadScheduled = false;
      });

      _txtPageCache.clear();
      _restorePageAfterBuild(quickPage);
      if (_enablePageCountMode) {
        _scheduleRepaginate(anchorLocation: existingProgress?.location);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _txtError = 'Failed to load TXT: $e';
        _loadedTxtPath = book.epubPath;
        _isLoadingTxt = false;
        _txtLoadScheduled = false;
      });
    }
  }

  List<_TocEntry> _buildTocEntries(Book book) {
    if (_isTxtBook(book) && _txtChapters.isNotEmpty) {
      return _buildTocFromChapters();
    }

    if (_isTxtBook(book) && _txtToc.isNotEmpty) {
      return _txtToc;
    }

    final total = _resolveTotalPages(book);
    return List<_TocEntry>.generate(
      total,
      (index) => _TocEntry(title: '第${index + 1}页', pageIndex: index),
    );
  }

  int _resolveTotalPages(Book book) {
    if (_isTxtBook(book)) {
      return _txtPages.isEmpty ? 1 : _txtPages.length;
    }
    return book.totalPages ?? _fallbackPages;
  }

  bool _isTxtBook(Book book) => book.epubPath.toLowerCase().endsWith('.txt');

  List<_TocEntry> _buildTocFromChapters() {
    if (_txtChapters.isEmpty) {
      return const [];
    }
    final currentChapterIndex = _txtPages.isEmpty
        ? null
        : _txtPages[_currentPage.clamp(0, _txtPages.length - 1)].chapterIndex;
    final chapterPageMap = <int, int>{};
    for (var i = 0; i < _txtPages.length; i++) {
      final chapterIndex = _txtPages[i].chapterIndex;
      chapterPageMap.putIfAbsent(chapterIndex, () => i);
    }
    final toc = _txtChapters
        .map(
          (chapter) => _TocEntry(
            title: chapter.title,
            pageIndex: chapterPageMap[chapter.index] ?? _currentPage,
            chapterIndex: chapter.index,
          ),
        )
        .toList();
    if (currentChapterIndex != null &&
        !toc.any((entry) => entry.chapterIndex == currentChapterIndex)) {
      final currentPage =
          _txtPages[_currentPage.clamp(0, _txtPages.length - 1)];
      toc.insert(
        0,
        _TocEntry(
          title: currentPage.title,
          pageIndex: _currentPage,
          chapterIndex: currentChapterIndex,
        ),
      );
    }
    return toc;
  }

  void _ensureTxtPagination() {
    final signature = _buildPaginationSignature();
    if (signature == _paginationSignature ||
        _isRepaginating ||
        _repaginateScheduled) {
      return;
    }
    _scheduleRepaginate(immediate: true);
  }

  int _buildPaginationSignature() {
    final media = MediaQuery.of(context);
    return Object.hash(
      media.size.width.round(),
      media.size.height.round(),
      media.padding.top.round(),
      media.padding.bottom.round(),
      _fontSizePreset,
      _paddingPreset,
      _lineHeightPreset,
      _paragraphIndentEnabled,
      _fontStylePreset,
    );
  }

  void _scheduleRepaginate({String? anchorLocation, bool immediate = false}) {
    if (_txtChapters.isEmpty) {
      return;
    }
    _repaginateDebounce?.cancel();
    _repaginateScheduled = true;
    _repaginateDebounce = Timer(
      Duration(milliseconds: immediate ? 0 : 800),
      () {
        if (!mounted) {
          _repaginateScheduled = false;
          return;
        }
        _repaginateTxtPages(anchorLocation: anchorLocation);
      },
    );
  }

  Future<void> _repaginateTxtPages({String? anchorLocation}) async {
    if (_isRepaginating || _txtChapters.isEmpty) {
      _repaginateScheduled = false;
      return;
    }
    final signature = _buildPaginationSignature();
    final width = _contentMaxWidth;
    final height = _contentMaxHeight;
    if (width <= 1 || height <= 1) {
      _repaginateScheduled = false;
      return;
    }

    final location = anchorLocation ?? _locationForPage(_currentPage);
    final cacheKey = _buildPaginationCacheKey(signature);
    final cachedPages = _txtPageCache[cacheKey];
    if (cachedPages != null && cachedPages.isNotEmpty) {
      final restoredPage = _resolvePageFromLocation(location, cachedPages);
      if (!mounted) {
        _repaginateScheduled = false;
        return;
      }
      setState(() {
        _txtPages = cachedPages;
        _txtToc = _buildTocFromPages(cachedPages);
        _paginationSignature = signature;
        _currentPage = restoredPage;
      });
      _repaginateScheduled = false;
      _restorePageAfterBuild(restoredPage);
      return;
    }

    final jobId = ++_paginationJobId;
    _isRepaginating = true;
    final pages = await _paginateTxtPagesProgressive(
      width: width,
      height: height,
      jobId: jobId,
    );
    if (jobId != _paginationJobId) {
      _isRepaginating = false;
      _repaginateScheduled = false;
      return;
    }
    final toc = _buildTocFromPages(pages);
    final restoredPage = _resolvePageFromLocation(location, pages);
    _isRepaginating = false;
    _repaginateScheduled = false;
    _txtPageCache[cacheKey] = List<_TxtPage>.unmodifiable(pages);
    await _writePersistedPagination(
      bookId: widget.bookId,
      signature: signature,
      pages: pages,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _txtPages = pages;
      _txtToc = toc;
      _paginationSignature = signature;
      _currentPage = restoredPage;
    });
    _restorePageAfterBuild(restoredPage);
  }

  String _buildPaginationCacheKey(int signature) {
    final path = _loadedTxtPath ?? widget.bookId;
    return '$path::$signature';
  }

  Future<String> _paginationCachePath({
    required String bookId,
    required int signature,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/pagination_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return '${dir.path}/${bookId}_$signature.json';
  }

  Future<List<_TxtPage>?> _readPersistedPagination({
    required String bookId,
    required int signature,
    required Map<int, _TxtChapter> chapterByIndex,
  }) async {
    try {
      final path = await _paginationCachePath(
        bookId: bookId,
        signature: signature,
      );
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final pages = decoded['pages'];
      if (pages is! List) {
        return null;
      }
      final parsed = <_TxtPage>[];
      for (final entry in pages) {
        if (entry is! Map<String, dynamic>) {
          continue;
        }
        final chapterIndex = entry['chapterIndex'];
        final startOffset = entry['startOffset'];
        final endOffset = entry['endOffset'];
        final title = entry['title'];
        if (chapterIndex is! int ||
            startOffset is! int ||
            endOffset is! int ||
            title is! String) {
          continue;
        }
        final chapter = chapterByIndex[chapterIndex];
        if (chapter == null) {
          continue;
        }
        if (startOffset < 0 ||
            endOffset <= startOffset ||
            endOffset > chapter.content.length) {
          continue;
        }
        parsed.add(
          _TxtPage(
            title: title,
            chapterIndex: chapterIndex,
            startOffset: startOffset,
            endOffset: endOffset,
          ),
        );
      }
      if (parsed.isEmpty) {
        return null;
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePersistedPagination({
    required String bookId,
    required int signature,
    required List<_TxtPage> pages,
  }) async {
    try {
      final path = await _paginationCachePath(
        bookId: bookId,
        signature: signature,
      );
      final file = File(path);
      final payload = {
        'version': 1,
        'signature': signature,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        'pages': pages
            .map(
              (page) => {
                'title': page.title,
                'chapterIndex': page.chapterIndex,
                'startOffset': page.startOffset,
                'endOffset': page.endOffset,
              },
            )
            .toList(),
      };
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      // Ignore cache write failures, reading experience should continue normally.
    }
  }

  Future<List<_TxtPage>> _paginateTxtPagesProgressive({
    required double width,
    required double height,
    required int jobId,
  }) async {
    final chapters = List<_TxtChapter>.from(_txtChapters);
    final allPages = <_TxtPage>[];

    // Keep UI responsive: yield frequently and pause pagination while the user is paging.
    for (var i = 0; i < chapters.length; i++) {
      if (jobId != _paginationJobId) {
        return allPages;
      }
      await _waitForPagingIdle();

      final chapterPages = await _paginateSingleChapterAsync(
        chapter: chapters[i],
        width: width,
        height: height,
        jobId: jobId,
      );
      allPages.addAll(chapterPages);

      if (i % 1 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (allPages.isEmpty) {
      return const [
        _TxtPage(title: '正文', chapterIndex: 0, startOffset: 0, endOffset: 0),
      ];
    }
    if (kDebugMode) {
      _validatePageContinuity(allPages);
    }
    return allPages;
  }

  void _validatePageContinuity(List<_TxtPage> pages) {
    for (var i = 0; i < pages.length - 1; i++) {
      final current = pages[i];
      final next = pages[i + 1];
      if (current.chapterIndex != next.chapterIndex) {
        continue;
      }
      final currentEnd = current.endOffset;
      assert(
        currentEnd == next.startOffset,
        'TXT pagination gap/overlap at page $i',
      );
    }
  }

  TextStyle _paginationTextStyle() {
    return TextStyle(
      fontSize: _contentFontSize,
      height: _contentLineHeight,
      color: _textColor,
      fontFamily: _contentFontFamily,
    );
  }

  List<InlineSpan> _buildParagraphSpans(
    String text,
    TextStyle style, {
    required bool startsAtParagraphBoundary,
    bool useWidgetIndent = true,
    int? highlightStart,
    int? highlightEnd,
  }) {
    if (text.isEmpty) {
      return const [];
    }
    final lines = text.split('\n');
    final spans = <InlineSpan>[];
    var textOffset = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isBlank = line.trim().isEmpty;
      final lineStartsParagraph = i == 0 ? startsAtParagraphBoundary : true;
      if (!isBlank && _paragraphIndentEnabled && lineStartsParagraph) {
        if (useWidgetIndent) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: SizedBox(width: _paragraphIndentWidthForText(text)),
            ),
          );
        } else {
          spans.add(
            TextSpan(text: _paragraphIndentPrefixForText(text), style: style),
          );
        }
      }
      // 去掉段落开头的空格
      final lineText = lineStartsParagraph && !isBlank ? line.trimLeft() : line;
      final trimmedLeading = line.length - lineText.length;
      spans.addAll(
        _buildHighlightedLineSpans(
          lineText: lineText,
          style: style,
          lineStartOffset: textOffset + trimmedLeading,
          highlightStart: highlightStart,
          highlightEnd: highlightEnd,
        ),
      );
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
      textOffset += line.length + 1;
    }

    return spans;
  }

  List<InlineSpan> _buildPageTextSpans({
    required String text,
    required TextStyle bodyStyle,
    String? chapterTitle,
    required bool startsAtParagraphBoundary,
    bool useWidgetIndent = true,
    int? highlightStart,
    int? highlightEnd,
  }) {
    final spans = <InlineSpan>[];
    final title = chapterTitle?.trim() ?? '';
    if (title.isNotEmpty) {
      spans.add(
        TextSpan(
          text: title,
          style: bodyStyle.copyWith(
            fontSize: _contentFontSize * 1.2,
            fontWeight: FontWeight.w800,
            height: _contentLineHeight + 0.12,
          ),
        ),
      );
      // chapter title spacing before body
      spans.add(const TextSpan(text: '\n'));
    }
    spans.addAll(
      _buildParagraphSpans(
        text,
        bodyStyle,
        startsAtParagraphBoundary: startsAtParagraphBoundary,
        useWidgetIndent: useWidgetIndent,
        highlightStart: highlightStart,
        highlightEnd: highlightEnd,
      ),
    );
    return spans;
  }

  List<InlineSpan> _buildHighlightedLineSpans({
    required String lineText,
    required TextStyle style,
    required int lineStartOffset,
    int? highlightStart,
    int? highlightEnd,
  }) {
    if (lineText.isEmpty ||
        highlightStart == null ||
        highlightEnd == null ||
        highlightEnd <= lineStartOffset ||
        highlightStart >= lineStartOffset + lineText.length) {
      return [TextSpan(text: lineText, style: style)];
    }

    final localStart = max(0, highlightStart - lineStartOffset);
    final localEnd = min(lineText.length, highlightEnd - lineStartOffset);
    if (localStart >= localEnd) {
      return [TextSpan(text: lineText, style: style)];
    }

    final spans = <InlineSpan>[];
    if (localStart > 0) {
      spans.add(
        TextSpan(text: lineText.substring(0, localStart), style: style),
      );
    }
    spans.add(
      TextSpan(
        text: lineText.substring(localStart, localEnd),
        style: style.copyWith(
          backgroundColor: _ttsHighlightColor,
          color: _ttsHighlightTextColor,
        ),
      ),
    );
    if (localEnd < lineText.length) {
      spans.add(TextSpan(text: lineText.substring(localEnd), style: style));
    }
    return spans;
  }

  TextRange? _resolveTtsHighlightRange({
    required TtsAppState ttsState,
    required String chapterText,
    required int pageStart,
    required int pageEnd,
    required String visibleText,
  }) {
    if (!ttsState.isSpeaking && !ttsState.isPaused) {
      return null;
    }
    final segmentStart = ttsState.currentSegmentStartOffset;
    final segmentEnd = ttsState.currentSegmentEndOffset;
    if (chapterText.isEmpty ||
        segmentStart == null ||
        segmentEnd == null ||
        segmentStart < 0 ||
        segmentEnd <= segmentStart ||
        segmentEnd > chapterText.length) {
      return null;
    }
    if (segmentEnd <= pageStart || segmentStart >= pageEnd) {
      return null;
    }
    final highlightText = chapterText.substring(segmentStart, segmentEnd);
    final approximateStart = max(0, segmentStart - pageStart);
    final matchedIndex = visibleText.indexOf(highlightText, approximateStart);
    final localStart = matchedIndex >= 0 ? matchedIndex : approximateStart;
    final localEnd = min(visibleText.length, localStart + highlightText.length);
    if (localStart >= localEnd) {
      return null;
    }
    return TextRange(start: localStart, end: localEnd);
  }

  String _paragraphIndentPrefixForText(String text) {
    if (!_paragraphIndentEnabled) {
      return '';
    }
    return _isCjkDominant(text) ? '\u3000\u3000' : '\u00A0\u00A0';
  }

  String _visiblePageBodyText({
    required String chapterText,
    required int start,
    required int end,
    required bool showChapterHeader,
    required String chapterTitle,
    required bool isLastPageOfChapter,
  }) {
    final safeStart = start.clamp(0, chapterText.length);
    final safeEnd = end.clamp(safeStart, chapterText.length);
    final raw = safeEnd > safeStart
        ? chapterText.substring(safeStart, safeEnd)
        : '';

    if (!showChapterHeader) {
      return _trimEmptyLines(raw, removeTrailingLineBreak: isLastPageOfChapter);
    }

    var processed = _stripDuplicatedLeadingTitle(raw, chapterTitle);
    return _trimEmptyLines(
      processed,
      removeTrailingLineBreak: isLastPageOfChapter,
    );
  }

  String _trimEmptyLines(String text, {bool removeTrailingLineBreak = false}) {
    // Remove leading empty lines
    var result = text.replaceFirst(RegExp(r'^\n+'), '');

    // Remove trailing empty lines (keep at most 1 for paragraph spacing)
    if (result.endsWith('\n\n')) {
      result = result.substring(0, result.length - 1);
    }

    // If this is the last page of a chapter, remove the trailing line break
    // so the last line gets justified instead of being hard-aligned left
    if (removeTrailingLineBreak && result.endsWith('\n')) {
      result = result.substring(0, result.length - 1);
    }

    return result;
  }

  int _findLastNonEmptyLineEnd(String text, int start, int end) {
    var result = end;
    while (result > start) {
      final prevBreak = text.lastIndexOf('\n', result - 1);
      if (prevBreak < start) {
        break;
      }
      final lineEnd = result;
      final lineStart = prevBreak + 1;
      final line = text.substring(lineStart, lineEnd).trim();
      if (line.isNotEmpty) {
        break;
      }
      result = lineStart;
    }
    return result;
  }

  bool _startsAtParagraphBoundary({
    required String chapterText,
    required int startOffset,
  }) {
    if (startOffset <= 0) {
      return true;
    }
    if (startOffset > chapterText.length) {
      return false;
    }

    final prevLineBreak = chapterText.lastIndexOf('\n', startOffset - 1);
    final lineStart = prevLineBreak + 1;
    if (lineStart != startOffset) {
      return false;
    }

    if (prevLineBreak < 0) {
      return true;
    }
    final prevPrevBreak = chapterText.lastIndexOf('\n', prevLineBreak - 1);
    final prevLineStart = prevPrevBreak + 1;
    final prevLine = chapterText.substring(prevLineStart, prevLineBreak).trim();
    return prevLine.isEmpty;
  }

  bool _endsAtParagraphBoundary({
    required String chapterText,
    required int endOffset,
  }) {
    if (endOffset >= chapterText.length) {
      return true;
    }
    if (endOffset <= 0) {
      return false;
    }

    // Check if endOffset is at a line break (paragraph border)
    if (endOffset < chapterText.length && chapterText[endOffset] == '\n') {
      return true;
    }

    // Check if the previous character is a line break
    if (endOffset > 0 && chapterText[endOffset - 1] == '\n') {
      return true;
    }

    return false;
  }

  String _stripDuplicatedLeadingTitle(String text, String title) {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty || text.trim().isEmpty) {
      return text;
    }
    final lines = text.split('\n');
    if (lines.isEmpty) {
      return text;
    }
    final firstLine = lines.first.trim();
    if (firstLine != trimmedTitle) {
      return text;
    }
    var i = 1;
    while (i < lines.length && lines[i].trim().isEmpty) {
      i++;
    }
    if (i >= lines.length) {
      return '';
    }
    return lines.sublist(i).join('\n');
  }

  StrutStyle get _contentStrutStyle => StrutStyle(
    fontSize: _contentFontSize,
    height: _contentLineHeight,
    forceStrutHeight: false,
    leading: 0,
  );

  Future<List<_TxtPage>> _paginateSingleChapterAsync({
    required _TxtChapter chapter,
    required double width,
    required double height,
    required int jobId,
  }) async {
    final text = chapter.content;
    if (text.isEmpty) {
      return const [];
    }

    final style = _paginationTextStyle();
    final pages = <_TxtPage>[];
    var start = 0;
    while (start < text.length) {
      if (jobId != _paginationJobId) {
        return pages;
      }
      await _waitForPagingIdle();

      final end = _pageEndForText(
        text: text,
        start: start,
        width: width,
        height: height,
        style: style,
        chapterTitle: chapter.title,
      );
      pages.add(
        _TxtPage(
          title: chapter.title,
          chapterIndex: chapter.index,
          startOffset: start,
          endOffset: end,
        ),
      );
      start = end;

      if (pages.length % 2 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    return pages;
  }

  int _pageEndForText({
    required String text,
    required int start,
    required double width,
    required double height,
    required TextStyle style,
    required String chapterTitle,
  }) {
    final length = text.length;
    if (start >= length) {
      return length;
    }

    final estimate = _estimateCharsPerPage(width: width, height: height);
    var chunkSize = max(256, estimate * 3);
    if (start + chunkSize > length) {
      chunkSize = length - start;
    }
    var end = min(length, start + chunkSize);
    final safeHeight = max(48.0, height - _paginationSafetyInset);

    bool fits(int candidateEnd) {
      final showChapterHeader = start == 0;
      final isLastPageOfChapter = candidateEnd >= length;
      final endsAtParagraphBoundary = _endsAtParagraphBoundary(
        chapterText: text,
        endOffset: candidateEnd,
      );
      final visibleText = _visiblePageBodyText(
        chapterText: text,
        start: start,
        end: candidateEnd,
        showChapterHeader: showChapterHeader,
        chapterTitle: chapterTitle,
        isLastPageOfChapter: isLastPageOfChapter,
      );
      final pageTextAlign = _resolveTextAlign(
        visibleText,
        endsAtParagraphBoundary: endsAtParagraphBoundary,
        isLastPageOfChapter: isLastPageOfChapter,
      );
      final painter = TextPainter(
        text: TextSpan(
          style: style,
          children: _buildPageTextSpans(
            text: visibleText,
            bodyStyle: style,
            chapterTitle: showChapterHeader ? chapterTitle : null,
            startsAtParagraphBoundary: _startsAtParagraphBoundary(
              chapterText: text,
              startOffset: start,
            ),
            useWidgetIndent: false,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: pageTextAlign,
        textWidthBasis: TextWidthBasis.longestLine,
        maxLines: null,
        textScaler: TextScaler.noScaling,
        strutStyle: _contentStrutStyle,
      );
      painter.layout(maxWidth: width);
      return painter.height <= safeHeight;
    }

    if (!fits(start + 1)) {
      return (start + 1).clamp(start + 1, length).toInt();
    }

    var low = start + 1;
    if (fits(end)) {
      low = end;
      while (low < length) {
        final currentSize = low - start;
        final next = start + min(length - start, currentSize * 2).toInt();
        if (next <= low) {
          break;
        }
        if (!fits(next)) {
          end = next;
          break;
        }
        low = next;
      }
      if (low >= length) {
        return length;
      }
    }

    var high = end;
    while (low + 1 < high) {
      final mid = low + ((high - low) ~/ 2);
      if (fits(mid)) {
        low = mid;
      } else {
        high = mid;
      }
    }

    final trimmedEnd = _findLastNonEmptyLineEnd(text, start, low);
    return trimmedEnd.clamp(start + 1, length);
  }

  int _estimateCharsPerPage({required double width, required double height}) {
    final safeHeight = max(48.0, height - _paginationSafetyInset);
    final fontSize = _contentFontSize;
    final lineHeightPx = fontSize * _contentLineHeight * 1.10;
    final lineCount = max(8, (safeHeight / lineHeightPx).floor());

    // Keep it light-weight to avoid UI jank during background repagination.
    final charsPerLine = max(8, (width / (fontSize * 1.12)).floor());
    final estimate = lineCount * charsPerLine;
    return estimate.clamp(120, 2200);
  }

  List<_TxtPage> _buildQuickPagesFromLocation({
    required List<_TxtChapter> chapters,
    required Map<int, _TxtChapter> chapterByIndex,
    required String? location,
  }) {
    if (chapters.isEmpty || chapterByIndex.isEmpty) {
      return const [
        _TxtPage(title: '正文', chapterIndex: 0, startOffset: 0, endOffset: 0),
      ];
    }

    var chapterIndex = chapters.first.index;
    var startOffset = 0;
    if (location != null && location.startsWith('txt:')) {
      final parts = location.split(':');
      if (parts.length >= 3) {
        chapterIndex = int.tryParse(parts[1]) ?? chapterIndex;
        startOffset = int.tryParse(parts[2]) ?? 0;
      }
    }

    final width = _contentMaxWidth;
    final height = _contentMaxHeight;
    final style = _paginationTextStyle();
    final estimate = _estimateCharsPerPage(width: width, height: height);

    final pages = <_TxtPage>[];
    const maxQuickPages = 40;
    const maxBackPages = 8;
    final chapterPos = max(
      0,
      chapters.indexWhere((c) => c.index == chapterIndex),
    );

    if (chapterPos > 0) {
      final prev = chapters[chapterPos - 1];
      final prevText = prev.content;
      final prevStart = max(0, prevText.length - estimate * 14);
      final prevPages = <_TxtPage>[];
      var start = prevStart;
      while (start < prevText.length) {
        final end = _pageEndForText(
          text: prevText,
          start: start,
          width: width,
          height: height,
          style: style,
          chapterTitle: prev.title,
        );
        prevPages.add(
          _TxtPage(
            title: prev.title,
            chapterIndex: prev.index,
            startOffset: start,
            endOffset: end,
          ),
        );
        start = end;
      }
      if (prevPages.length > maxBackPages) {
        pages.addAll(prevPages.sublist(prevPages.length - maxBackPages));
      } else {
        pages.addAll(prevPages);
      }
    }

    for (
      var c = chapterPos;
      c < chapters.length && pages.length < maxQuickPages;
      c++
    ) {
      final chapter = chapters[c];
      final text = chapter.content;
      final isAnchor = c == chapterPos;
      var start = isAnchor
          ? max(0, startOffset - estimate * 12).clamp(0, text.length)
          : 0;

      while (start < text.length && pages.length < maxQuickPages) {
        final end = _pageEndForText(
          text: text,
          start: start,
          width: width,
          height: height,
          style: style,
          chapterTitle: chapter.title,
        );
        pages.add(
          _TxtPage(
            title: chapter.title,
            chapterIndex: chapter.index,
            startOffset: start,
            endOffset: end,
          ),
        );
        start = end;
      }
    }

    if (pages.isEmpty) {
      return const [
        _TxtPage(title: '正文', chapterIndex: 0, startOffset: 0, endOffset: 0),
      ];
    }
    return pages;
  }

  List<_TocEntry> _buildTocFromPages(List<_TxtPage> pages) {
    final seen = <int>{};
    final toc = <_TocEntry>[];
    for (var i = 0; i < pages.length; i++) {
      final chapterIndex = pages[i].chapterIndex;
      if (seen.add(chapterIndex)) {
        toc.add(_TocEntry(title: pages[i].title, pageIndex: i));
      }
    }
    return toc;
  }

  int _resolvePageFromLocation(String? location, List<_TxtPage> pages) {
    if (pages.isEmpty) {
      return 0;
    }
    if (location == null || location.isEmpty) {
      return 0;
    }

    if (location.startsWith('txtp:')) {
      final legacyPage = int.tryParse(location.substring(5));
      if (legacyPage != null) {
        return legacyPage.clamp(0, pages.length - 1);
      }
    }

    if (!location.startsWith('txt:')) {
      return 0;
    }
    final parts = location.split(':');
    if (parts.length < 3) {
      return 0;
    }
    final chapterIndex = int.tryParse(parts[1]);
    final offset = int.tryParse(parts[2]) ?? 0;
    if (chapterIndex == null) {
      return 0;
    }

    var bestMatch = -1;
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      if (page.chapterIndex != chapterIndex) {
        continue;
      }
      if (page.startOffset <= offset) {
        bestMatch = i;
      } else {
        break;
      }
    }
    if (bestMatch >= 0) {
      return bestMatch;
    }
    for (var i = 0; i < pages.length; i++) {
      if (pages[i].chapterIndex == chapterIndex) {
        return i;
      }
    }
    return 0;
  }

  String _locationForPage(int pageIndex) {
    if (_txtPages.isEmpty) {
      return 'txtp:0';
    }
    final safeIndex = pageIndex.clamp(0, _txtPages.length - 1);
    final page = _txtPages[safeIndex];
    return 'txt:${page.chapterIndex}:${page.startOffset}';
  }

  double get _currentProgressPercent {
    if (_txtPages.isNotEmpty && _txtTotalLength > 0) {
      return (_globalOffsetForPage(_currentPage) / _txtTotalLength).clamp(
        0.0,
        1.0,
      );
    }
    final total = max(1, _txtPages.isEmpty ? _fallbackPages : _txtPages.length);
    return (_currentPage / total).clamp(0.0, 1.0);
  }

  void _jumpToTxtProgress(double percent) {
    if (_txtChapters.isEmpty || _txtChapterByIndex.isEmpty) {
      return;
    }
    final safePercent = percent.clamp(0.0, 1.0);
    final targetGlobal = (_txtTotalLength * safePercent).round();
    int targetChapterIndex = _txtChapters.first.index;
    int targetOffsetInChapter = 0;

    for (final chapter in _txtChapters) {
      final chapterStart = _txtChapterGlobalStart[chapter.index] ?? 0;
      final chapterEnd = chapterStart + chapter.content.length;
      if (targetGlobal <= chapterEnd) {
        targetChapterIndex = chapter.index;
        targetOffsetInChapter = max(0, targetGlobal - chapterStart);
        break;
      }
    }

    final location = 'txt:$targetChapterIndex:$targetOffsetInChapter';
    final rebuilt = _buildQuickPagesFromLocation(
      chapters: _txtChapters,
      chapterByIndex: _txtChapterByIndex,
      location: location,
    );
    if (rebuilt.isEmpty) {
      return;
    }
    final targetPage = _resolvePageFromLocation(location, rebuilt);
    setState(() {
      _txtPages = rebuilt;
      _txtToc = _buildTocFromPages(rebuilt);
      _currentPage = targetPage;
    });
    _restorePageAfterBuild(targetPage);
  }

  void _jumpToTxtChapter(int chapterIndex) {
    if (_txtChapters.isEmpty || _txtChapterByIndex.isEmpty) {
      return;
    }
    for (var i = 0; i < _txtPages.length; i++) {
      if (_txtPages[i].chapterIndex == chapterIndex) {
        _jumpToPage(i);
        return;
      }
    }

    final location = 'txt:$chapterIndex:0';
    final rebuilt = _buildQuickPagesFromLocation(
      chapters: _txtChapters,
      chapterByIndex: _txtChapterByIndex,
      location: location,
    );
    if (rebuilt.isEmpty) {
      return;
    }
    final targetPage = _resolvePageFromLocation(location, rebuilt);
    setState(() {
      _txtPages = rebuilt;
      _txtToc = _buildTocFromPages(rebuilt);
      _currentPage = targetPage;
    });
    _restorePageAfterBuild(targetPage);
  }

  void _scheduleSaveTxtProgress(Book book) {
    _progressSaveDebounce?.cancel();
    _progressSaveDebounce = Timer(const Duration(milliseconds: 220), () {
      _persistTxtProgress(book);
    });
  }

  Future<void> _persistCurrentBookProgress(Book? book) async {
    if (book == null) {
      return;
    }
    if (_isTxtBook(book)) {
      await _persistTxtProgress(book);
      return;
    }
    final totalPages = max(1, _resolveTotalPages(book));
    final safePage = _currentPage.clamp(0, totalPages - 1);
    final progress = ReadingProgress(
      bookId: book.id,
      location: 'page:$safePage',
      percentage: (safePage + 1) / totalPages,
      lastReadAt: DateTime.now(),
      readingTimeSeconds: _readingTimeSeconds,
    );
    await ref.read(updateReadingProgressUseCaseProvider).call(progress);
  }

  Future<void> _persistTxtProgress(Book book) async {
    if (!_isTxtBook(book)) {
      return;
    }
    final hasPages = _txtPages.isNotEmpty;
    final safePage = hasPages ? _currentPage.clamp(0, _txtPages.length - 1) : 0;
    final location = hasPages ? _locationForPage(safePage) : 'txt:0:0';
    final globalOffset = hasPages ? _globalOffsetForPage(safePage) : 0;
    final percent = !hasPages
        ? 0.0
        : _txtTotalLength <= 0
        ? (safePage + 1) / _txtPages.length
        : (globalOffset / _txtTotalLength).clamp(0.0, 1.0);
    final progress = ReadingProgress(
      bookId: book.id,
      location: location,
      percentage: percent,
      lastReadAt: DateTime.now(),
      readingTimeSeconds: _readingTimeSeconds,
    );

    await ref.read(updateReadingProgressUseCaseProvider).call(progress);
  }

  int _globalOffsetForPage(int pageIndex) {
    if (_txtPages.isEmpty) {
      return 0;
    }
    final safeIndex = pageIndex.clamp(0, _txtPages.length - 1);
    final page = _txtPages[safeIndex];
    final chapterStart = _txtChapterGlobalStart[page.chapterIndex] ?? 0;
    return chapterStart + page.startOffset;
  }

  Future<String> _readTxtContent(String path) async {
    final resolvedPath = await _resolveTxtPath(path);
    if (resolvedPath == null) {
      throw Exception('TXT file not found. Please re-import this book.');
    }

    final bytes = await File(resolvedPath).readAsBytes();
    try {
      return utf8.decode(bytes);
    } catch (_) {
      final gb18030Text = await CharsetConverter.decode('gb18030', bytes);
      if (_containsReadableCjk(gb18030Text)) {
        return gb18030Text;
      }

      final gbkText = await CharsetConverter.decode('gbk', bytes);
      if (_containsReadableCjk(gbkText)) {
        return gbkText;
      }

      final utf8Text = utf8.decode(bytes, allowMalformed: true);
      if (utf8Text.trim().isNotEmpty) {
        return utf8Text;
      }

      final latinText = latin1.decode(bytes, allowInvalid: true);
      if (latinText.trim().isNotEmpty) {
        return latinText;
      }

      return gb18030Text.trim().isNotEmpty ? gb18030Text : gbkText;
    }
  }

  Future<String?> _resolveTxtPath(String rawPath) async {
    final candidates = <String>{rawPath, _safeDecode(rawPath)};

    final uri = Uri.tryParse(rawPath);
    if (uri != null && uri.scheme == 'file') {
      final filePath = uri.toFilePath();
      candidates.add(filePath);
      candidates.add(_safeDecode(filePath));
    }

    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        return candidate;
      }
    }

    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/books');
    if (!await booksDir.exists()) {
      return null;
    }

    final fileName = rawPath.split('/').last;
    final decodedFileName = _safeDecode(fileName);
    await for (final entity in booksDir.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final currentName = entity.path.split('/').last;
      if (currentName == fileName ||
          currentName == decodedFileName ||
          currentName.endsWith('_$decodedFileName')) {
        return entity.path;
      }
    }

    return null;
  }

  String _safeDecode(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (_) {
      return value;
    }
  }

  bool _containsReadableCjk(String text) {
    if (text.trim().isEmpty) {
      return false;
    }
    final cjkCount = RegExp(r'[\u4E00-\u9FFF]').allMatches(text).length;
    final replacementCount = RegExp('\uFFFD').allMatches(text).length;
    if (replacementCount > text.length * 0.02) {
      return false;
    }
    if (cjkCount >= 12) {
      return true;
    }
    return text.length < 80 && cjkCount >= 2;
  }

  TextAlign _resolveTextAlign(
    String text, {
    required bool endsAtParagraphBoundary,
    required bool isLastPageOfChapter,
  }) {
    switch (_textAlignPreset) {
      case 1:
        return TextAlign.justify;
      case 2:
        return TextAlign.start;
      case 3:
        return TextAlign.center;
      default:
        // Default: always use justify for aligned right edge
        return TextAlign.justify;
    }
  }

  bool _isCjkDominant(String text) {
    if (text.isEmpty) {
      return true;
    }
    final cjk = RegExp(r'[\u4E00-\u9FFF]').allMatches(text).length;
    if (cjk == 0) {
      return false;
    }
    return cjk / text.length >= 0.16;
  }

  double _paragraphIndentWidthForText(String text) {
    if (!_paragraphIndentEnabled) {
      return 0;
    }
    if (_isCjkDominant(text)) {
      return _contentFontSize * 2.0;
    }
    return _contentFontSize * 1.3;
  }

  EdgeInsets get _contentPadding {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 390;
    final horizontalBase = (width * 0.06).clamp(14.0, 30.0);
    final topBase = (width * 0.06).clamp(12.0, 24.0);
    final bottomBase = (width * 0.07).clamp(24.0, 40.0);

    if (_paddingPreset == 0) {
      return EdgeInsets.fromLTRB(
        horizontalBase - 6,
        topBase - 8,
        horizontalBase - 6,
        bottomBase - 6,
      );
    }
    if (_paddingPreset == 2) {
      return EdgeInsets.fromLTRB(
        horizontalBase + 10,
        topBase + 4,
        horizontalBase + 10,
        bottomBase + 2,
      );
    }
    return EdgeInsets.fromLTRB(
      horizontalBase + 2,
      topBase,
      horizontalBase + 2,
      bottomBase,
    );
  }

  double get _contentFontSize {
    return _fontSizePreset.clamp(16, 40).toDouble();
  }

  double get _contentLineHeight {
    const heights = [1.5, 1.66, 1.82, 2.0];
    return heights[_lineHeightPreset.clamp(0, heights.length - 1)];
  }

  String? get _contentFontFamily {
    switch (_fontStylePreset) {
      case 1:
        return 'serif';
      case 2:
        return 'monospace';
      default:
        return null;
    }
  }

  double get _contentMaxWidth {
    final media = MediaQuery.of(context);
    return max(120.0, media.size.width - _contentPadding.horizontal);
  }

  double get _contentMaxHeight {
    final media = MediaQuery.of(context);
    return max(
      120.0,
      media.size.height -
          media.padding.top -
          media.padding.bottom -
          _contentPadding.vertical,
    );
  }

  double get _paginationSafetyInset {
    // Keep only a small guard band now that pagination/rendering models are aligned.
    final byFont = _contentFontSize * 0.24;
    return byFont.clamp(3.0, 8.0);
  }

  Color get _readerBgColor {
    const palette = [
      Color(0xFFF3F3F3),
      Color(0xFFE8E2D6),
      Color(0xFFF1F4EE),
      Color(0xFFA6C39D),
      Color(0xFF111111),
    ];
    return palette[_themeIndex.clamp(0, palette.length - 1)];
  }

  Color get _controlSurfaceColor {
    final hsl = HSLColor.fromColor(_readerBgColor);
    // 黑色背景使用深灰色形成对比，浅色背景使用稍深的颜色
    if (hsl.lightness < 0.2) {
      return const Color(0xFF1A1A1A);
    }
    final darker = (hsl.lightness - 0.06).clamp(0.0, 1.0);
    return hsl.withLightness(darker).toColor();
  }

  Color get _textColor =>
      _themeIndex == 4 ? Colors.white70 : const Color(0xFF1F2A1F);

  Color get _ttsHighlightColor => _themeIndex == 4
      ? const Color(0xFF4C7D5B).withValues(alpha: 0.72)
      : const Color(0xFFBFE7A8).withValues(alpha: 0.9);

  Color get _ttsHighlightTextColor =>
      _themeIndex == 4 ? Colors.white : const Color(0xFF182118);

  Widget _buildFloatingAudiobookButton(Book book, int totalPages) {
    final ttsState = ref.watch(ttsProvider);
    const buttonSize = 54.0;
    final viewPadding = MediaQuery.of(context).viewPadding;

    final buttonBgColor = _controlSurfaceColor;

    // 图标颜色
    final iconColor = _textColor;

    // 非播放状态才显示听书按钮
    final isLoadingAudio =
        ttsState.isLoadingAudio && !ttsState.isSpeaking && !ttsState.isPaused;
    if (ttsState.isSpeaking ||
        ttsState.isPaused ||
        isLoadingAudio ||
        ttsState.isAudiobookUiVisible) {
      return const SizedBox.shrink();
    }
    final shouldShow = _showControls && !isLoadingAudio;

    return Positioned(
      right: 16,
      bottom: viewPadding.bottom + 78,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        opacity: shouldShow ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !shouldShow,
          child: GestureDetector(
            onTap: () async {
              await _openAudiobookSheet(book, totalPages);
            },
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: buttonBgColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.headphones_rounded,
                      size: 32,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackControlButton(Book book, int totalPages) {
    final ttsState = ref.watch(ttsProvider);
    const capsuleWidth = 164.0;
    const capsuleHeight = 59.0;
    const coverSize = 49.0;
    const ringSize = 55.0;
    const actionButtonSize = 34.0;
    final launchData = _buildAudiobookLaunchData(book);
    final isPlaying = ttsState.isSpeaking && !ttsState.isPaused;
    final isLoadingAudio =
        ttsState.isLoadingAudio && !ttsState.isSpeaking && !ttsState.isPaused;
    final canPlay =
        launchData != null ||
        ttsState.isSpeaking ||
        ttsState.isPaused ||
        isLoadingAudio;
    final canTapPlayback = canPlay && (!isLoadingAudio || ttsState.isPaused);
    final shouldShow =
        !ttsState.isAudiobookUiVisible &&
        (ttsState.isSpeaking || ttsState.isPaused || isLoadingAudio);
    final capsuleColor = _controlSurfaceColor;
    final primaryIconColor = _textColor;
    final secondaryIconColor = _textColor.withOpacity(0.78);
    final progressColor = _themeIndex == 4
        ? Colors.white.withOpacity(0.82)
        : const Color(0xFFF0F8F2);
    final trackColor = _themeIndex == 4
        ? Colors.white.withOpacity(0.14)
        : Colors.white.withOpacity(0.18);
    final coverPath = book.coverPath;
    final coverFile = coverPath != null && coverPath.isNotEmpty
        ? File(coverPath)
        : null;
    final hasCover = coverFile != null && coverFile.existsSync();
    final chapterProgress = _currentChapterReadingProgress(book, totalPages);
    final mediaSize = MediaQuery.of(context).size;
    final viewPadding = MediaQuery.of(context).viewPadding;
    final defaultOffset = Offset(
      16,
      mediaSize.height - viewPadding.bottom - 78 - capsuleHeight,
    );
    final resolvedOffset = _clampFloatingPlaybackOffset(
      _floatingPlaybackOffset ?? defaultOffset,
      screenSize: mediaSize,
      width: capsuleWidth,
      height: capsuleHeight,
    );
    _syncFloatingCoverSpin(isPlaying);

    return Positioned(
      left: resolvedOffset.dx,
      top: resolvedOffset.dy,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        opacity: shouldShow ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !shouldShow,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            offset: shouldShow ? Offset.zero : const Offset(-0.08, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              onPanUpdate: (details) {
                setState(() {
                  _floatingPlaybackOffset = _clampFloatingPlaybackOffset(
                    resolvedOffset + details.delta,
                    screenSize: mediaSize,
                    width: capsuleWidth,
                    height: capsuleHeight,
                  );
                });
              },
              child: Container(
                width: capsuleWidth,
                height: capsuleHeight,
                decoration: BoxDecoration(
                  color: capsuleColor,
                  borderRadius: BorderRadius.circular(capsuleHeight / 2),
                  border: Border.all(
                    color: Colors.white.withOpacity(
                      _themeIndex == 4 ? 0.16 : 0.24,
                    ),
                    width: 1,
                  ),
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
                      onTap: () async => _openAudiobookSheet(book, totalPages),
                      child: SizedBox(
                        width: ringSize,
                        height: ringSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: ringSize,
                              height: ringSize,
                              child: CircularProgressIndicator(
                                value: chapterProgress,
                                strokeWidth: 3,
                                color: progressColor,
                                backgroundColor: trackColor,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            RotationTransition(
                              turns: _floatingCoverController,
                              child: Container(
                                width: coverSize,
                                height: coverSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.26),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.44),
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(3),
                                  child: ClipOval(
                                    child: hasCover
                                        ? Image.file(
                                            coverFile,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _buildFloatingPlaybackCoverPlaceholder(
                                                  book,
                                                ),
                                          )
                                        : _buildFloatingPlaybackCoverPlaceholder(
                                            book,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        splashColor: Colors.white.withOpacity(0.14),
                        highlightColor: Colors.transparent,
                        onTap: canTapPlayback
                            ? () => unawaited(
                                _toggleReaderPlayback(
                                  book: book,
                                  totalPages: totalPages,
                                  ttsState: ttsState,
                                  canPlay: canPlay,
                                ),
                              )
                            : null,
                        child: SizedBox(
                          width: actionButtonSize,
                          height: actionButtonSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 22,
                                color: primaryIconColor,
                              ),
                              if (isLoadingAudio)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              primaryIconColor,
                                            ),
                                        backgroundColor: Colors.white
                                            .withOpacity(0.14),
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
                        splashColor: Colors.white.withOpacity(0.14),
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          await ref.read(ttsProvider.notifier).stop();
                        },
                        child: SizedBox(
                          width: actionButtonSize,
                          height: actionButtonSize,
                          child: Icon(
                            Icons.close_rounded,
                            size: 22,
                            color: secondaryIconColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _clampFloatingPlaybackOffset(
    Offset offset, {
    required Size screenSize,
    required double width,
    required double height,
  }) {
    final viewPadding = MediaQuery.of(context).viewPadding;
    final minLeft = 8.0;
    final maxLeft = screenSize.width - width - 8.0;
    final minTop = viewPadding.top + 8.0;
    final maxTop = screenSize.height - viewPadding.bottom - height - 8.0;
    return Offset(
      offset.dx.clamp(minLeft, maxLeft),
      offset.dy.clamp(minTop, maxTop),
    );
  }

  void _syncFloatingCoverSpin(bool shouldSpin) {
    if (shouldSpin == _isFloatingCoverSpinning) {
      return;
    }
    _isFloatingCoverSpinning = shouldSpin;
    if (shouldSpin) {
      _floatingCoverController.repeat();
    } else {
      _floatingCoverController.stop();
    }
  }

  double _currentChapterReadingProgress(Book book, int totalPages) {
    final ttsState = ref.read(ttsProvider);
    final chapterLength = ttsState.currentChapterLength;
    final chapterStartOffset = ttsState.currentStartOffset;
    final currentText = ttsState.currentText;
    if (chapterLength != null &&
        chapterLength > 0 &&
        chapterStartOffset != null &&
        currentText != null &&
        (ttsState.isSpeaking || ttsState.isPaused || ttsState.isLoadingAudio)) {
      final progressedChars = (currentText.length * ttsState.playbackProgress)
          .round();
      final chapterOffset = chapterStartOffset + progressedChars;
      return (chapterOffset / chapterLength).clamp(0.0, 1.0);
    }

    if (!_isTxtBook(book) || _txtPages.isEmpty) {
      return ((_currentPage + 1) / max(1, totalPages)).clamp(0.0, 1.0);
    }

    final safePage = _currentPage.clamp(0, _txtPages.length - 1);
    final currentChapterIndex = _txtPages[safePage].chapterIndex;
    var chapterStartPage = safePage;
    while (chapterStartPage > 0 &&
        _txtPages[chapterStartPage - 1].chapterIndex == currentChapterIndex) {
      chapterStartPage--;
    }

    var chapterEndPage = safePage;
    while (chapterEndPage < _txtPages.length - 1 &&
        _txtPages[chapterEndPage + 1].chapterIndex == currentChapterIndex) {
      chapterEndPage++;
    }

    final chapterPageCount = chapterEndPage - chapterStartPage + 1;
    final pageProgress = safePage - chapterStartPage + 1;
    return (pageProgress / max(1, chapterPageCount)).clamp(0.0, 1.0);
  }

  Widget _buildFloatingPlaybackCoverPlaceholder(Book book) {
    final title = book.title.trim();
    final initials = title.isEmpty ? '读' : title.substring(0, 1);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FBF7), Color(0xFFB9D4BD)],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: const Color(0xFF365446).withOpacity(0.88),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String? _getEpubPageText(Book book) {
    // TODO: 从EPUB中获取当前页面的文本
    // 这里暂时返回占位符文本
    return '这是EPUB书籍的第${_currentPage + 1}页内容。\n\n'
        '需要通过Flureadium集成来获取实际的EPUB文本内容。';
  }

  EdgeInsets get mediaQueryPadding => MediaQuery.of(context).padding;
}
