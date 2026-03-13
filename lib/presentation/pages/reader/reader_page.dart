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

  const _AudiobookLaunchData({
    required this.initialText,
    this.chapterTitle,
    this.chapterText,
    this.chapterIndex,
    this.initialOffset = 0,
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
  return text.replaceAll(RegExp(r'\n{2,}'), '\n\n\n');
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

class _ReaderPageState extends ConsumerState<ReaderPage> {
  static const String _prefFontSizePreset = 'reader_font_size_preset_v1';
  static const String _prefPaddingPreset = 'reader_padding_preset_v1';
  static const String _prefLineHeightPreset = 'reader_line_height_preset_v1';
  static const bool _enablePageCountMode = false;
  static const Set<String> _breakChars = {
    '\n',
    ' ',
    '。',
    '！',
    '？',
    '；',
    '，',
    '、',
    '.',
    '!',
    '?',
    ';',
    ',',
    ':',
    '：',
    '）',
    ')',
  };

  final PageController _pageController = PageController();
  final int _fallbackPages = 100;

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
  bool _usingQuickPages = false;
  bool _didUserTurnPageSinceOpen = false;
  bool _isUserPaging = false;
  Completer<void>? _pagingIdleCompleter;

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
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _applySystemUiVisibility();
    _loadReaderPreferences();
  }

  @override
  void dispose() {
    _progressSaveDebounce?.cancel();
    _repaginateDebounce?.cancel();
    _readerPrefsSaveDebounce?.cancel();
    _autoPageTimer?.cancel();
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

    final totalPages = _resolveTotalPages(book);
    if (_enablePageCountMode && _isTxtBook(book) && _txtChapters.isNotEmpty) {
      _ensureTxtPagination();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _handleTap(details, totalPages),
      onDoubleTapDown: (details) {
        if (_isInAudiobookTriggerZone(details.localPosition)) {
          _handleDoubleTap(book, totalPages);
        }
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
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
                _didUserTurnPageSinceOpen = true;
                if (_isTxtBook(book)) {
                  _scheduleSaveTxtProgress(book);
                }
              },
              itemBuilder: (context, index) => _buildPageContent(index, book),
            ),
          ),
          _buildTopBar(book),
          _buildBottomToolbar(book, totalPages),
          if (!_showControls && _activePanel == _ReaderPanel.none)
            _buildBottomPageIndicator(totalPages),
          if (_brightnessValue < 0.5)
            IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity((0.5 - _brightnessValue) * 0.9),
              ),
            ),
          // 悬浮听书按钮
          _buildFloatingAudiobookButton(book, totalPages),
        ],
      ),
    );
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

  Widget _buildPageContent(int index, Book book) {
    if (_isTxtBook(book) && _txtPages.isNotEmpty) {
      final page = _txtPages[index];
      final chapter = _txtChapterByIndex[page.chapterIndex];
      final chapterText = chapter?.content ?? '';
      final safeStart = page.startOffset.clamp(0, chapterText.length);
      final safeEnd = page.endOffset.clamp(safeStart, chapterText.length);
      final visibleText = safeEnd > safeStart
          ? chapterText.substring(safeStart, safeEnd)
          : '';
      return SafeArea(
        child: Padding(
          padding: _contentPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    visibleText,
                    textScaler: TextScaler.noScaling,
                    strutStyle: _contentStrutStyle,
                    textAlign: TextAlign.justify,
                    textWidthBasis: TextWidthBasis.parent,
                    style: TextStyle(
                      fontSize: _contentFontSize,
                      height: _contentLineHeight,
                      color: _textColor,
                    ),
                  ),
                ),
              ),
            ],
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
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.black87,
                        ),
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
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
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
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 24,
      splashRadius: 22,
      color: active ? Colors.black : Colors.black87,
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
            title: const Text('自动翻页'),
            dense: true,
          ),
        ],
      ),
    );
  }

  Future<void> _showThemePanel() async {
    final colors = [
      const Color(0xFFF3F3F3),
      const Color(0xFFE8E2D6),
      const Color(0xFFA6C39D),
      const Color(0xFF111111),
    ];
    await _showReaderActionPanel(
      title: '亮度与颜色',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildThemedSlider(
                value: _brightnessValue,
                min: 0,
                max: 1,
                onChanged: (v) {
                  setState(() => _brightnessValue = v);
                  setModalState(() => _brightnessValue = v);
                },
              ),
              const SizedBox(height: 2),
              Text('颜色', style: TextStyle(color: _textColor.withOpacity(0.8))),
              const SizedBox(height: 8),
              Row(
                children: List.generate(colors.length, (i) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _themeIndex = i);
                        setModalState(() {});
                      },
                      child: Container(
                        height: 40,
                        margin: EdgeInsets.only(
                          right: i == colors.length - 1 ? 0 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors[i],
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: i == _themeIndex
                                ? const Color(0xFF3A8B2A)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showTypographyPanel() async {
    const paddingLabels = ['紧凑', '标准', '宽松'];
    const lineHeightLabels = ['紧凑', '舒适', '宽阔', '沉浸'];

    await _showReaderActionPanel(
      title: '字体设置',
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final fontSize = _fontSizePreset.clamp(16, 40);

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
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: _textColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _textColor.withOpacity(0.18)),
                ),
                child: Text(
                  '阅读让视线更轻松，好的排版能显著降低疲劳。',
                  style: TextStyle(
                    fontSize: fontSize.toDouble(),
                    height: _contentLineHeight,
                    color: _textColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _panelSubTitle('字体大小'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _stepButtonForTypography(
                    icon: Icons.remove_rounded,
                    enabled: fontSize > 16,
                    onTap: () => updateTypography(font: fontSize - 1),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 34,
                    width: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _textColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$fontSize',
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _stepButtonForTypography(
                    icon: Icons.add_rounded,
                    enabled: fontSize < 40,
                    onTap: () => updateTypography(font: fontSize + 1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildSteppedSlider(
                value: fontSize,
                min: 16,
                max: 40,
                showDivisions: false,
                onChanged: (v) => updateTypography(font: v),
              ),
              const SizedBox(height: 8),
              _panelSubTitle('页边距'),
              const SizedBox(height: 8),
              _segmentedChoices(
                labels: paddingLabels,
                selectedIndex: _paddingPreset,
                onSelect: (index) => updateTypography(padding: index),
              ),
              const SizedBox(height: 12),
              _panelSubTitle('行距'),
              const SizedBox(height: 8),
              _segmentedChoices(
                labels: lineHeightLabels,
                selectedIndex: _lineHeightPreset,
                onSelect: (index) => updateTypography(lineHeight: index),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _actionPill(
                      '恢复默认',
                      textColor: _textColor,
                      bgColor: _textColor.withOpacity(0.08),
                      onTap: () =>
                          updateTypography(font: 20, padding: 1, lineHeight: 2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionPill(
                      '完成',
                      textColor: _textColor,
                      bgColor: _textColor.withOpacity(0.08),
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

  Widget _buildSteppedSlider({
    required int value,
    int min = 0,
    required int max,
    bool showDivisions = true,
    required ValueChanged<int> onChanged,
  }) {
    if (_isIOS) {
      return CupertinoSlider(
        value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
        min: min.toDouble(),
        max: max.toDouble(),
        onChanged: (v) => onChanged(v.round()),
      );
    }
    return _buildThemedSlider(
      value: value.toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      divisions: showDivisions ? (max - min) : null,
      onChanged: (v) => onChanged(v.round()),
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
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
            color: bgColor ?? Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(21),
          ),
          child: Text(
            text,
            style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
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

  Widget _stepButtonForTypography({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    if (_isIOS) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(34, 34),
        onPressed: enabled ? onTap : null,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _textColor.withOpacity(enabled ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: _textColor.withOpacity(enabled ? 0.9 : 0.4),
          ),
        ),
      );
    }

    return SizedBox(
      width: 34,
      height: 34,
      child: Material(
        color: _textColor.withOpacity(enabled ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Icon(
            icon,
            size: 18,
            color: _textColor.withOpacity(enabled ? 0.9 : 0.4),
          ),
        ),
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
    final width = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;

    if (dx < width * 0.3) {
      if (_txtPages.isNotEmpty && _currentPage == 0) {
        _handleTxtEdgePaging(previous: true);
      }
      _jumpToPage(max(0, _currentPage - 1));
      return;
    }

    if (dx > width * 0.7) {
      if (_txtPages.isNotEmpty && _currentPage >= totalPages - 1) {
        _handleTxtEdgePaging(previous: false);
      }
      _jumpToPage(min(totalPages - 1, _currentPage + 1));
      return;
    }

    setState(() {
      _showControls = !_showControls;
    });
    _applySystemUiVisibility();
  }

  bool _isInAudiobookTriggerZone(Offset localPosition) {
    final size = MediaQuery.of(context).size;
    final side = size.width * 0.5;
    final left = (size.width - side) / 2;
    final top = (size.height - side) / 2;
    final rect = Rect.fromLTWH(left, top, side, side);
    return rect.contains(localPosition);
  }

  void _handleDoubleTap(Book book, int totalPages) async {
    await _openAudiobookSheet(book, totalPages);
  }

  _AudiobookLaunchData? _buildAudiobookLaunchData(Book book) {
    if (_isTxtBook(book) && _txtPages.isNotEmpty) {
      final page = _txtPages[_currentPage.clamp(0, _txtPages.length - 1)];
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

      return _AudiobookLaunchData(
        initialText: preview.isEmpty ? chapterText : preview,
        chapterTitle: page.title,
        chapterText: chapterText,
        chapterIndex: page.chapterIndex,
        initialOffset: safeStart,
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
          ),
        );
      },
    );

    _applySystemUiVisibility();

    if (result != null) {
      _handleAudiobookResult(result);
    }
  }

  void _handleAudiobookResult(Map<String, dynamic> result) {
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
    }
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

  void _jumpToPage(int page) {
    if (!_pageController.hasClients) {
      return;
    }
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _setUserPaging(bool paging) {
    if (_isUserPaging == paging) {
      return;
    }
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
            _usingQuickPages = false;
            _didUserTurnPageSinceOpen = false;
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
        _usingQuickPages = true;
        _didUserTurnPageSinceOpen = false;
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
      _usingQuickPages = false;
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
    );
  }

  StrutStyle get _contentStrutStyle => StrutStyle(
    fontSize: _contentFontSize,
    height: _contentLineHeight,
    forceStrutHeight: true,
    leading: 0.1,
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

    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: null,
      textScaler: TextScaler.noScaling,
      strutStyle: _contentStrutStyle,
    );
    final safeHeight = max(48.0, height - _paginationSafetyInset);

    while (true) {
      painter.text = TextSpan(text: text.substring(start, end), style: style);
      painter.layout(maxWidth: width);

      if (painter.height <= safeHeight) {
        if (end >= length) {
          return length;
        }
        final currentSize = end - start;
        final nextSize = min(length - start, currentSize * 2);
        if (nextSize <= currentSize) {
          return end;
        }
        end = start + nextSize;
        continue;
      }

      final position = painter.getPositionForOffset(
        Offset(width, max(0, safeHeight - 1)),
      );
      var localEnd = position.offset;
      if (localEnd <= 0) {
        localEnd = max(1, min(end - start, 64));
      }
      var rawEnd = start + localEnd;
      rawEnd = rawEnd.clamp(start + 1, end);
      final naturalEnd = _findNaturalBreakBefore(text, start, rawEnd);
      return naturalEnd.clamp(start + 1, length);
    }
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

  int _findNaturalBreakBefore(String text, int start, int end) {
    if (end <= start + 1) {
      return min(text.length, start + 1);
    }
    final minIndex = max(start + 1, end - 72);
    for (var i = end; i > minIndex; i--) {
      final char = text[i - 1];
      if (_breakChars.contains(char)) {
        return i;
      }
    }
    return end;
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

  EdgeInsets get _contentPadding {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 390;
    final horizontalBase = (width * 0.06).clamp(14.0, 30.0);
    final topBase = (width * 0.085).clamp(24.0, 42.0);
    final bottomBase = (width * 0.09).clamp(30.0, 52.0);

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
    final byFont = _contentFontSize * 0.7;
    return byFont.clamp(10.0, 22.0);
  }

  Color get _readerBgColor {
    const palette = [
      Color(0xFFF3F3F3),
      Color(0xFFE8E2D6),
      Color(0xFFA6C39D),
      Color(0xFF111111),
    ];
    return palette[_themeIndex.clamp(0, palette.length - 1)];
  }

  Color get _controlSurfaceColor {
    final hsl = HSLColor.fromColor(_readerBgColor);
    final darker = (hsl.lightness - 0.06).clamp(0.0, 1.0);
    return hsl.withLightness(darker).toColor();
  }

  Color get _textColor =>
      _themeIndex == 3 ? Colors.white70 : const Color(0xFF1F2A1F);

  Widget _buildFloatingAudiobookButton(Book book, int totalPages) {
    final ttsState = ref.watch(ttsProvider);
    const buttonSize = 68.0;

    return Positioned(
      right: 16,
      bottom: mediaQueryPadding.bottom + 78,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        opacity: _showControls ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !_showControls,
          child: GestureDetector(
            onTap: () async {
              await _openAudiobookSheet(book, totalPages);
            },
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF456757).withOpacity(0.92),
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
                      size: 34,
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),
                  if (ttsState.isSpeaking)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF6FCF97),
                        ),
                      ),
                    ),
                  if (ttsState.isSpeaking)
                    Positioned.fill(
                      child: Center(child: _buildPulseWave(buttonSize)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPulseWave(double baseSize) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return Container(
          width: baseSize + (value * 24),
          height: baseSize + (value * 24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.blue.withOpacity(1.0 - value),
              width: 2,
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted) {
          setState(() {}); // 触发重建以重复动画
        }
      },
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
