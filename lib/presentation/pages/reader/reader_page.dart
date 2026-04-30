import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:charset_converter/charset_converter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myreader/core/models/tts_chapter_payload.dart';
import 'package:myreader/core/providers/book_providers.dart';
import 'package:myreader/core/providers/tts_provider.dart';
import 'package:myreader/core/providers/usecase_providers.dart';
import 'package:myreader/core/utils/locale_text.dart';
import 'package:myreader/data/services/epub/epub_archive_service.dart';
import 'package:myreader/data/services/epub/epub_import_cache_service.dart';
import 'package:myreader/data/services/epub/epub_package.dart';
import 'package:myreader/data/services/reader_pagination/epub_paginator.dart';
import 'package:myreader/data/services/reader_pagination/epub_pagination_cache_service.dart';
import 'package:myreader/data/services/reader_pagination/flutter_layout_measurer.dart';
import 'package:myreader/data/services/reader_pagination/locator_mapper.dart';
import 'package:myreader/data/services/reader_pagination/page_layout_model.dart';
import 'package:myreader/data/services/reader_pagination/pagination_settings.dart';
import 'package:myreader/data/services/txt_import_cache_service.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/domain/entities/reading_progress.dart';
import 'package:myreader/domain/entities/reader_document/block_node.dart';
import 'package:myreader/domain/entities/reader_document/book_document.dart';
import 'package:myreader/domain/entities/reader_document/chapter_document.dart';
import 'package:myreader/domain/entities/reader_document/inline_node.dart';
import 'package:myreader/domain/entities/reader_document/reader_locator.dart';
import 'package:myreader/presentation/pages/reader/audiobook_page_redesign.dart';
import 'package:myreader/presentation/pages/reader/widgets/epub_page_content.dart';
import 'package:myreader/presentation/widgets/bookshelf/book_cover_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final String bookId;
  final Book? initialBook;
  final String? openTraceId;
  final int? openStartedAtMicros;
  final bool autoStartFloatingPlayback;
  final bool popAfterAutoStart;
  final bool hiddenForAutoStart;

  const ReaderPage({
    super.key,
    required this.bookId,
    this.initialBook,
    this.openTraceId,
    this.openStartedAtMicros,
    this.autoStartFloatingPlayback = false,
    this.popAfterAutoStart = false,
    this.hiddenForAutoStart = false,
  });

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

class _EpubPageEntry {
  final ChapterDocument chapter;
  final PageLayout layout;

  const _EpubPageEntry({required this.chapter, required this.layout});
}

class _TxtLocation {
  final int chapterIndex;
  final int offset;

  const _TxtLocation({required this.chapterIndex, required this.offset});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TxtLocation &&
          runtimeType == other.runtimeType &&
          chapterIndex == other.chapterIndex &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(chapterIndex, offset);
}

class _DecodedTxtContent {
  final String text;
  final String encoding;

  const _DecodedTxtContent({required this.text, required this.encoding});
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

enum _ReaderPanel { none, toc, notes, progress, typography }

enum _SettingsPanelPage { root, fontStyle, layout, customBackground, more }

enum _ReaderBackgroundMode { preset, customImage }

enum _ReaderBackgroundImageFit { cover, contain, fill }

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
                        decoration: InputDecoration(
                          hintText: LocaleText.of(
                            context,
                            zh: '搜本书',
                            en: 'Search this book',
                          ),
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
                              SnackBar(
                                content: Text(
                                  LocaleText.of(
                                    context,
                                    zh: '未找到匹配的章节',
                                    en: 'No matching chapter found',
                                  ),
                                ),
                                duration: const Duration(seconds: 2),
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
                      LocaleText.of(context, zh: '目录', en: 'Contents'),
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
                        LocaleText.of(
                          context,
                          zh: '未找到匹配章节',
                          en: 'No matching chapters',
                        ),
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
  static const String _prefBackgroundMode = 'reader_background_mode_v1';
  static const String _prefBackgroundPresetIndex =
      'reader_background_preset_index_v1';
  static const String _prefBackgroundLightPresetIndex =
      'reader_background_light_preset_index_v1';
  static const String _prefBackgroundDarkPresetIndex =
      'reader_background_dark_preset_index_v1';
  static const String _prefBackgroundImagePath =
      'reader_background_image_path_v1';
  static const String _prefBackgroundImageFit =
      'reader_background_image_fit_v1';
  static const String _prefBackgroundOverlayOpacity =
      'reader_background_overlay_opacity_v1';
  static const String _prefBackgroundBlurSigma =
      'reader_background_blur_sigma_v1';
  static const String _prefBackgroundBrightness =
      'reader_background_brightness_v1';
  static const String _prefOneHandMode = 'reader_one_hand_mode_v1';
  static const String _prefEdgeSwipeExit = 'reader_edge_swipe_exit_v1';
  static const String _prefBrightnessFollowSystem =
      'reader_brightness_follow_system_v1';
  // 禁用 keepPage 以避免 page storage 延迟
  late PageController _pageController;
  final int _fallbackPages = 100;
  late final AnimationController _floatingCoverController;
  final EpubArchiveService _epubArchiveService = const EpubArchiveService();
  final EpubImportCacheService _epubImportCacheService =
      const EpubImportCacheService();
  final EpubPaginationCacheService _epubPaginationCacheService =
      const EpubPaginationCacheService();
  final TxtImportCacheService _txtImportCacheService =
      const TxtImportCacheService();

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
  _TxtLocation? _currentTxtLocation;
  bool _showTxtOpeningView = false;
  bool _isAdjustingTxtPageStream = false;
  bool _isLoadingEpub = false;
  bool _epubLoadScheduled = false;
  String? _epubError;
  String? _loadedEpubPath;
  List<_EpubPageEntry> _epubPages = const [];
  List<_TocEntry> _epubToc = const [];
  ReaderLocator? _currentEpubLocator;
  bool _showEpubOpeningView = false;
  Map<String, Uint8List> _epubResourceBytes = const {};
  String? _epubBookLanguage;
  int? _lastPageTurnStart; // 用于追踪翻页延迟

  Timer? _progressSaveDebounce;
  Timer? _repaginateDebounce;
  Timer? _readerPrefsSaveDebounce;
  Timer? _txtOpeningViewDelayTimer;
  Timer? _epubOpeningViewDelayTimer;
  int _readingTimeSeconds = 0;
  _ReaderPanel _activePanel = _ReaderPanel.none;
  int _fontSizePreset = 20;
  int _themeIndex = 2;
  int _lightThemeIndex = 1;
  int _darkThemeIndex = 9;
  int _paddingPreset = 1;
  int _lineHeightPreset = 2;
  _ReaderBackgroundMode _backgroundMode = _ReaderBackgroundMode.preset;
  String? _customBackgroundImagePath;
  _ReaderBackgroundImageFit _backgroundImageFit =
      _ReaderBackgroundImageFit.cover;
  double _backgroundOverlayOpacity = 0.18;
  double _backgroundBlurSigma = 0;
  double? _customBackgroundBrightness;
  bool _isPickingBackgroundImage = false;
  bool _autoPageEnabled = false;
  Timer? _autoPageTimer;
  bool _canStartTxtLoad = true;
  int _textAlignPreset = 0;
  bool _paragraphIndentEnabled = true;
  int _fontStylePreset = 0;
  bool _oneHandModeEnabled = false;
  bool _edgeSwipeExitEnabled = false;
  bool _isFloatingCoverSpinning = false;
  Offset? _floatingPlaybackOffset;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool _didLogFirstFrame = false;
  bool _didLogTxtContentFrame = false;
  bool _didAutoStartFloatingPlayback = false;

  void _logOpenTrace(String message) {
    final traceId = widget.openTraceId;
    final startedAtMicros = widget.openStartedAtMicros;
    if (traceId == null || startedAtMicros == null) {
      return;
    }
    final elapsedMs =
        (DateTime.now().microsecondsSinceEpoch - startedAtMicros) / 1000.0;
    debugPrint(
      '[open-book][$traceId][${elapsedMs.toStringAsFixed(1)}ms] $message',
    );
  }

  @override
  void initState() {
    super.initState();
    _logOpenTrace('reader initState');
    _pageController = PageController(keepPage: false);
    _floatingCoverController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    if (!widget.hiddenForAutoStart) {
      _applySystemUiVisibility();
    }
    _loadReaderPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didLogFirstFrame) {
        return;
      }
      _didLogFirstFrame = true;
      _logOpenTrace('reader first frame rendered');
    });
  }

  @override
  void dispose() {
    _progressSaveDebounce?.cancel();
    _repaginateDebounce?.cancel();
    _readerPrefsSaveDebounce?.cancel();
    _txtOpeningViewDelayTimer?.cancel();
    _epubOpeningViewDelayTimer?.cancel();
    _autoPageTimer?.cancel();
    _floatingCoverController.dispose();
    if (!widget.hiddenForAutoStart) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
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
        backgroundColor: Colors.transparent,
        body: bookAsync.when(
          data: (book) => _buildReader(book ?? widget.initialBook),
          loading: () => widget.initialBook != null
              ? _buildReader(widget.initialBook)
              : const Center(child: CircularProgressIndicator()),
          error: (error, stack) => widget.initialBook != null
              ? _buildReader(widget.initialBook)
              : Center(
                  child: Text(
                    LocaleText.of(
                      context,
                      zh: '加载失败: $error',
                      en: 'Error: $error',
                    ),
                  ),
                ),
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
    _logOpenTrace('reader prefs load start');
    final prefs = await SharedPreferences.getInstance();
    final font = prefs.getInt(_prefFontSizePreset);
    final padding = prefs.getInt(_prefPaddingPreset);
    final lineHeight = prefs.getInt(_prefLineHeightPreset);
    final textAlignPreset = prefs.getInt(_prefTextAlignPreset);
    final paragraphIndent = prefs.getBool(_prefParagraphIndent);
    final fontStylePreset = prefs.getInt(_prefFontStylePreset);
    final backgroundModeValue = prefs.getString(_prefBackgroundMode);
    final backgroundPresetIndex = prefs.getInt(_prefBackgroundPresetIndex);
    final backgroundLightPresetIndex = prefs.getInt(
      _prefBackgroundLightPresetIndex,
    );
    final backgroundDarkPresetIndex = prefs.getInt(
      _prefBackgroundDarkPresetIndex,
    );
    final backgroundImagePath = prefs.getString(_prefBackgroundImagePath);
    final backgroundImageFitValue = prefs.getString(_prefBackgroundImageFit);
    final backgroundOverlayOpacity = prefs.getDouble(
      _prefBackgroundOverlayOpacity,
    );
    final backgroundBlurSigma = prefs.getDouble(_prefBackgroundBlurSigma);
    var backgroundBrightness = prefs.getDouble(_prefBackgroundBrightness);
    final oneHandModeEnabled = prefs.getBool(_prefOneHandMode);
    final edgeSwipeExitEnabled = prefs.getBool(_prefEdgeSwipeExit);
    var resolvedBackgroundMode = _readerBackgroundModeFromValue(
      backgroundModeValue,
    );
    var resolvedBackgroundImagePath = backgroundImagePath;

    if (resolvedBackgroundImagePath != null &&
        resolvedBackgroundImagePath.isNotEmpty) {
      final exists = await File(resolvedBackgroundImagePath).exists();
      if (!exists) {
        resolvedBackgroundMode = _ReaderBackgroundMode.preset;
        resolvedBackgroundImagePath = null;
        backgroundBrightness = null;
      } else if (backgroundBrightness == null) {
        backgroundBrightness = await _computeImageBrightness(
          resolvedBackgroundImagePath,
        );
      }
    } else {
      resolvedBackgroundMode = _ReaderBackgroundMode.preset;
      resolvedBackgroundImagePath = null;
      backgroundBrightness = null;
    }

    if (!mounted) {
      return;
    }
    _logOpenTrace('reader prefs load complete');
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
      if (backgroundPresetIndex != null) {
        _themeIndex = backgroundPresetIndex.clamp(0, 11);
      }
      if (backgroundLightPresetIndex != null) {
        _lightThemeIndex = _clampLightThemeIndex(backgroundLightPresetIndex);
      }
      if (backgroundDarkPresetIndex != null) {
        _darkThemeIndex = _clampDarkThemeIndex(backgroundDarkPresetIndex);
      }
      if (_isDarkThemeIndex(_themeIndex)) {
        _darkThemeIndex = _clampDarkThemeIndex(_themeIndex);
      } else {
        _lightThemeIndex = _clampLightThemeIndex(_themeIndex);
      }
      _backgroundMode = resolvedBackgroundMode;
      _customBackgroundImagePath = resolvedBackgroundImagePath;
      _backgroundImageFit = _readerBackgroundImageFitFromValue(
        backgroundImageFitValue,
      );
      if (backgroundOverlayOpacity != null) {
        _backgroundOverlayOpacity = backgroundOverlayOpacity.clamp(0.0, 0.6);
      }
      if (backgroundBlurSigma != null) {
        _backgroundBlurSigma = backgroundBlurSigma.clamp(0.0, 12.0);
      }
      _customBackgroundBrightness = backgroundBrightness;
      if (oneHandModeEnabled != null) {
        _oneHandModeEnabled = oneHandModeEnabled;
      }
      if (edgeSwipeExitEnabled != null) {
        _edgeSwipeExitEnabled = edgeSwipeExitEnabled;
      }
    });
    if (resolvedBackgroundMode == _ReaderBackgroundMode.preset &&
        backgroundImagePath != null &&
        backgroundImagePath.isNotEmpty) {
      _scheduleSaveReaderPreferences();
    }
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
        await prefs.setString(
          _prefBackgroundMode,
          _backgroundMode == _ReaderBackgroundMode.customImage
              ? 'custom_image'
              : 'preset',
        );
        await prefs.setInt(_prefBackgroundPresetIndex, _themeIndex);
        await prefs.setInt(
          _prefBackgroundLightPresetIndex,
          _clampLightThemeIndex(_lightThemeIndex),
        );
        await prefs.setInt(
          _prefBackgroundDarkPresetIndex,
          _clampDarkThemeIndex(_darkThemeIndex),
        );
        if (_customBackgroundImagePath != null &&
            _customBackgroundImagePath!.isNotEmpty) {
          await prefs.setString(
            _prefBackgroundImagePath,
            _customBackgroundImagePath!,
          );
        } else {
          await prefs.remove(_prefBackgroundImagePath);
        }
        await prefs.setString(
          _prefBackgroundImageFit,
          _readerBackgroundImageFitValue(_backgroundImageFit),
        );
        await prefs.setDouble(
          _prefBackgroundOverlayOpacity,
          _backgroundOverlayOpacity,
        );
        await prefs.setDouble(_prefBackgroundBlurSigma, _backgroundBlurSigma);
        await prefs.setBool(_prefOneHandMode, _oneHandModeEnabled);
        await prefs.setBool(_prefEdgeSwipeExit, _edgeSwipeExitEnabled);
        if (_customBackgroundBrightness != null) {
          await prefs.setDouble(
            _prefBackgroundBrightness,
            _customBackgroundBrightness!,
          );
        } else {
          await prefs.remove(_prefBackgroundBrightness);
        }
      },
    );
  }

  _ReaderBackgroundMode _readerBackgroundModeFromValue(String? value) {
    return value == 'custom_image'
        ? _ReaderBackgroundMode.customImage
        : _ReaderBackgroundMode.preset;
  }

  _ReaderBackgroundImageFit _readerBackgroundImageFitFromValue(String? value) {
    switch (value) {
      case 'contain':
        return _ReaderBackgroundImageFit.contain;
      case 'fill':
        return _ReaderBackgroundImageFit.fill;
      default:
        return _ReaderBackgroundImageFit.cover;
    }
  }

  String _readerBackgroundImageFitValue(_ReaderBackgroundImageFit fit) {
    switch (fit) {
      case _ReaderBackgroundImageFit.contain:
        return 'contain';
      case _ReaderBackgroundImageFit.fill:
        return 'fill';
      case _ReaderBackgroundImageFit.cover:
        return 'cover';
    }
  }

  int _clampLightThemeIndex(int value) => value.clamp(0, 7);

  int _clampDarkThemeIndex(int value) => value.clamp(8, 11);

  bool _isDarkThemeIndex(int value) => value >= 8;

  List<_ThemeOption> get _presetThemes => [
    _ThemeOption(
      id: 0,
      color: const Color(0xFFF3F3F3),
      name: _text(zh: '浅色', en: 'Light'),
      icon: Icons.light_mode_rounded,
    ),
    _ThemeOption(
      id: 1,
      color: const Color(0xFFE8E2D6),
      name: _text(zh: '米色', en: 'Beige'),
      icon: Icons.brightness_4_rounded,
    ),
    _ThemeOption(
      id: 2,
      color: const Color(0xFFF1F4EE),
      name: _text(zh: '薄荷绿', en: 'Mint'),
      icon: Icons.emoji_nature_rounded,
    ),
    _ThemeOption(
      id: 3,
      color: const Color(0xFFA6C39D),
      name: _text(zh: '浅绿', en: 'Soft Green'),
      icon: Icons.nature_rounded,
    ),
    _ThemeOption(
      id: 4,
      color: const Color(0xFFF5ECD7),
      name: _text(zh: '羊皮纸', en: 'Parchment'),
      icon: Icons.auto_stories_rounded,
    ),
    _ThemeOption(
      id: 5,
      color: const Color(0xFFE3EBF2),
      name: _text(zh: '雾蓝', en: 'Mist Blue'),
      icon: Icons.water_drop_outlined,
    ),
    _ThemeOption(
      id: 6,
      color: const Color(0xFFF5E8EA),
      name: _text(zh: '玫瑰粉', en: 'Rose Pink'),
      icon: Icons.local_florist_outlined,
    ),
    _ThemeOption(
      id: 7,
      color: const Color(0xFFFFF8E7),
      name: _text(zh: '奶油黄', en: 'Cream Yellow'),
      icon: Icons.wb_sunny_outlined,
    ),
    _ThemeOption(
      id: 8,
      color: const Color(0xFF121212),
      name: _text(zh: '深灰', en: 'Dark Gray'),
      icon: Icons.dark_mode_rounded,
    ),
    _ThemeOption(
      id: 9,
      color: const Color(0xFF1A1B26),
      name: _text(zh: '深靛', en: 'Deep Indigo'),
      icon: Icons.nights_stay_outlined,
    ),
    _ThemeOption(
      id: 10,
      color: const Color(0xFF1C1C1C),
      name: _text(zh: '深咖', en: 'Dark Brown'),
      icon: Icons.coffee_outlined,
    ),
    _ThemeOption(
      id: 11,
      color: const Color(0xFF1A2A1F),
      name: _text(zh: '墨绿', en: 'Ink Green'),
      icon: Icons.forest_outlined,
    ),
  ];

  void _activatePresetTheme(int themeIndex, {bool syncQuickSelection = true}) {
    final resolvedThemeIndex = themeIndex.clamp(0, _presetThemes.length - 1);
    setState(() {
      _backgroundMode = _ReaderBackgroundMode.preset;
      _themeIndex = resolvedThemeIndex;
      if (syncQuickSelection) {
        if (_isDarkThemeIndex(resolvedThemeIndex)) {
          _darkThemeIndex = _clampDarkThemeIndex(resolvedThemeIndex);
        } else {
          _lightThemeIndex = _clampLightThemeIndex(resolvedThemeIndex);
        }
      }
    });
    HapticFeedback.selectionClick();
    _scheduleSaveReaderPreferences();
  }

  void _toggleQuickBrightnessTheme() {
    final nextThemeIndex = _backgroundMode == _ReaderBackgroundMode.customImage
        ? _lightThemeIndex
        : _isDarkThemeIndex(_themeIndex)
        ? _lightThemeIndex
        : _darkThemeIndex;
    _activatePresetTheme(nextThemeIndex, syncQuickSelection: false);
  }

  Future<double?> _computeImageBrightness(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 32,
        targetHeight: 32,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData == null) {
        return null;
      }

      final data = byteData.buffer.asUint8List();
      if (data.isEmpty) {
        return null;
      }

      var luminance = 0.0;
      var pixels = 0;
      for (var index = 0; index + 3 < data.length; index += 4) {
        final alpha = data[index + 3] / 255.0;
        if (alpha <= 0) {
          continue;
        }
        final red = data[index] / 255.0;
        final green = data[index + 1] / 255.0;
        final blue = data[index + 2] / 255.0;
        luminance += (0.2126 * red + 0.7152 * green + 0.0722 * blue) * alpha;
        pixels++;
      }
      return pixels == 0 ? null : luminance / pixels;
    } catch (_) {
      return null;
    }
  }

  Future<String> _readerBackgroundsDirectoryPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/reader_backgrounds');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  Future<void> _pickCustomBackgroundImage() async {
    if (_isPickingBackgroundImage) {
      return;
    }
    setState(() {
      _isPickingBackgroundImage = true;
    });
    try {
      String? pickedPath;
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android) {
        final picker = ImagePicker();
        final image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1800,
          imageQuality: 92,
        );
        pickedPath = image?.path;
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: false,
        );
        if (result != null && result.files.isNotEmpty) {
          pickedPath = result.files.first.path;
        }
      }

      if (pickedPath == null || pickedPath.isEmpty) {
        return;
      }

      final sourceFile = File(pickedPath);
      if (!await sourceFile.exists()) {
        throw Exception(_text(zh: '图片文件不存在', en: 'Image file not found'));
      }

      final backgroundDir = await _readerBackgroundsDirectoryPath();
      final extension = pickedPath.contains('.')
          ? pickedPath.split('.').last.toLowerCase()
          : 'jpg';
      final targetPath =
          '$backgroundDir/reader_background_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final previousPath = _customBackgroundImagePath;
      final copiedFile = await sourceFile.copy(targetPath);
      await FileImage(copiedFile).evict();
      final brightness = await _computeImageBrightness(copiedFile.path);

      if (!mounted) {
        return;
      }
      setState(() {
        _backgroundMode = _ReaderBackgroundMode.customImage;
        _customBackgroundImagePath = copiedFile.path;
        _customBackgroundBrightness = brightness;
      });
      _scheduleSaveReaderPreferences();

      if (previousPath != null &&
          previousPath.isNotEmpty &&
          previousPath != copiedFile.path &&
          previousPath.contains('/reader_backgrounds/')) {
        unawaited(() async {
          try {
            await File(previousPath).delete();
          } catch (_) {}
        }());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _text(zh: '正文背景图片已更新', en: 'Reader background updated'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_text(zh: '选择背景图片失败', en: 'Failed to choose background image')}: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingBackgroundImage = false;
        });
      }
    }
  }

  Future<void> _clearCustomBackgroundImage() async {
    final previousPath = _customBackgroundImagePath;
    setState(() {
      _backgroundMode = _ReaderBackgroundMode.preset;
      _customBackgroundImagePath = null;
      _customBackgroundBrightness = null;
      _backgroundOverlayOpacity = 0.18;
      _backgroundBlurSigma = 0;
      _backgroundImageFit = _ReaderBackgroundImageFit.cover;
    });
    _scheduleSaveReaderPreferences();
    if (previousPath != null &&
        previousPath.isNotEmpty &&
        previousPath.contains('/reader_backgrounds/')) {
      unawaited(() async {
        try {
          await File(previousPath).delete();
        } catch (_) {}
      }());
    }
  }

  Widget _buildReader(Book? book) {
    if (book == null) {
      return Center(
        child: Text(_text(zh: '未找到书籍', en: 'Book not found')),
      );
    }

    if (_isTxtBook(book) &&
        _loadedTxtPath != book.epubPath &&
        !_isLoadingTxt &&
        !_txtLoadScheduled &&
        _canStartTxtLoad) {
      _txtLoadScheduled = true;
      _logOpenTrace('txt load scheduled');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadTxtBook(book);
        }
      });
    }

    if (!_isTxtBook(book) &&
        _loadedEpubPath != book.epubPath &&
        !_isLoadingEpub &&
        !_epubLoadScheduled) {
      _epubLoadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadEpubBook(book);
        }
      });
    }

    if (_isTxtBook(book) && _txtError != null) {
      return Center(child: Text(_txtError!));
    }

    if (!_isTxtBook(book) && _epubError != null) {
      return Center(child: Text(_epubError!));
    }

    final isPreparingTxt =
        _isTxtBook(book) &&
        (_isLoadingTxt ||
            _loadedTxtPath != book.epubPath ||
            _txtChapters.isEmpty);
    final isPreparingEpub =
        !_isTxtBook(book) &&
        (_isLoadingEpub ||
            _loadedEpubPath != book.epubPath ||
            _epubPages.isEmpty);

    final shouldShowTxtOpeningView =
        isPreparingTxt || (_isTxtBook(book) && _txtPages.isEmpty);
    final shouldShowEpubOpeningView =
        isPreparingEpub || (!_isTxtBook(book) && _epubPages.isEmpty);
    final shouldShowOpeningView = _isTxtBook(book)
        ? shouldShowTxtOpeningView
        : shouldShowEpubOpeningView;

    if (shouldShowOpeningView && widget.hiddenForAutoStart) {
      return const SizedBox.shrink();
    }

    if (shouldShowOpeningView &&
        (_isTxtBook(book) ? _showTxtOpeningView : _showEpubOpeningView)) {
      return _buildOpeningView(book);
    }

    if (shouldShowOpeningView) {
      return Stack(
        children: [
          Positioned.fill(child: _buildReaderBackgroundLayer()),
          if (_isCustomBackgroundActive)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: _readerReadingVeilColor),
              ),
            ),
        ],
      );
    }

    final ttsState = ref.watch(ttsProvider);
    final totalPages = _resolveTotalPages(book);

    if (widget.autoStartFloatingPlayback && !_didAutoStartFloatingPlayback) {
      _didAutoStartFloatingPlayback = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          return;
        }
        await _startFloatingPlayback(book: book, totalPages: totalPages);
        if (widget.popAfterAutoStart && mounted) {
          Navigator.of(context).pop();
        }
      });
    }

    if (widget.hiddenForAutoStart) {
      return const SizedBox.shrink();
    }

    final readerContent = Stack(
      children: [
        Positioned.fill(child: _buildReaderBackgroundLayer()),
        if (_isCustomBackgroundActive)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: _readerReadingVeilColor),
            ),
          ),
        // 底层：全局单击检测（立即响应）
        // 只处理点击，不参与拖动手势竞技，避免干扰 PageView 的滑动
        RawGestureDetector(
          gestures: <Type, GestureRecognizerFactory>{
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(),
                  (TapGestureRecognizer instance) {
                    instance.onTapUp = (details) {
                      _handleTap(details, totalPages);
                    };
                  },
                ),
          },
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) =>
                    _handlePageScrollNotification(notification, totalPages),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: totalPages,
                  pageSnapping: true,
                  onPageChanged: (page) {
                    if (_isTxtBook(book)) {
                      final txtPage = _txtPages[page];
                      final nextLocation = _TxtLocation(
                        chapterIndex: txtPage.chapterIndex,
                        offset: txtPage.startOffset,
                      );
                      setState(() {
                        _currentPage = page;
                        _currentTxtLocation = nextLocation;
                        _txtToc = _buildTocFromChaptersForLocation(
                          txtPage.chapterIndex,
                        );
                      });
                      if (!_isAdjustingTxtPageStream) {
                        _ensureTxtPageStreamAround(page);
                      }
                      _scheduleSaveTxtProgress(book);
                      return;
                    }
                    final nextLocator = _locatorForEpubPage(page);
                    setState(() {
                      _currentPage = page;
                      _currentEpubLocator = nextLocator;
                    });
                    _scheduleSaveCurrentBookProgress(book);
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
        if (_edgeSwipeExitEnabled)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 20,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) async {
                if (details.primaryDelta == null ||
                    details.primaryDelta! <= 14) {
                  return;
                }
                if (!Navigator.of(context).canPop()) {
                  return;
                }
                final bookAsync = ref.read(bookByIdProvider(widget.bookId));
                final currentBook = bookAsync.valueOrNull ?? widget.initialBook;
                await _persistCurrentBookProgress(currentBook);
                if (mounted) {
                  Navigator.of(context).maybePop();
                }
              },
            ),
          ),
      ], // 最外层 Stack children 闭合
    ); // 最外层 Stack 闭合

    if (!widget.hiddenForAutoStart) {
      return readerContent;
    }

    return IgnorePointer(child: Opacity(opacity: 0, child: readerContent));
  }

  Widget _buildOpeningView(Book book) {
    return Stack(
      children: [
        Positioned.fill(child: _buildReaderBackgroundLayer()),
        if (_isCustomBackgroundActive)
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: _readerReadingVeilColor),
            ),
          ),
        SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: const Color(0xFF757575),
                      ), // Gray for back navigation
                      const SizedBox(width: 12),
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text(
                          zh: '正在打开《${book.title}》',
                          en: 'Opening "${book.title}"',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textColor.withOpacity(0.72),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        height: 18,
                        width: 112,
                        decoration: BoxDecoration(
                          color: _textColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final widthFactor in [
                              0.96,
                              0.92,
                              0.88,
                              0.94,
                              0.84,
                              0.9,
                              0.78,
                            ])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: FractionallySizedBox(
                                  widthFactor: widthFactor,
                                  child: Container(
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: _textColor.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                            const Spacer(),
                            Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.1,
                                    color: _textColor.withOpacity(0.55),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _text(
                                    zh: '正在恢复阅读进度',
                                    en: 'Restoring reading progress',
                                  ),
                                  style: TextStyle(
                                    color: _textColor.withOpacity(0.6),
                                    fontSize: 13,
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageContent(int index, Book book, TtsAppState ttsState) {
    if (_isTxtBook(book)) {
      final page = _txtPages[index];
      final chapter = _txtChapterByIndex[page.chapterIndex];
      final chapterText = chapter?.content ?? '';
      final safeStart = page.startOffset.clamp(0, chapterText.length);
      final safeEnd = page.endOffset.clamp(safeStart, chapterText.length);
      final previousPage = index > 0 ? _txtPages[index - 1] : null;
      final nextPage = index + 1 < _txtPages.length
          ? _txtPages[index + 1]
          : null;
      final showChapterHeader =
          page.startOffset == 0 ||
          previousPage == null ||
          previousPage.chapterIndex != page.chapterIndex;
      final isLastPageOfChapter =
          safeEnd >= chapterText.length ||
          nextPage == null ||
          nextPage.chapterIndex != page.chapterIndex;
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
      final chapterLabel = page.title.trim();
      final shouldShowChapterOverlay =
          !showChapterHeader && chapterLabel.isNotEmpty;
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

      return SafeArea(
        key: ValueKey(
          'reader-page-$index-${page.chapterIndex}-${page.startOffset}-${page.endOffset}-'
          'theme-$_themeIndex-'
          'speaking-${ttsState.isSpeaking}-'
          'paused-${ttsState.isPaused}'
          '${useHighlightKey ? '-highlight-${(ttsState.playbackProgress * 1000).round()}' : ''}',
        ),
        child: Padding(
          padding: _contentPadding,
          child: Builder(
            builder: (context) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (shouldShowChapterOverlay)
                        SizedBox(height: _chapterOverlayReservedHeight),
                      if (showChapterHeader && chapterLabel.isNotEmpty) ...[
                        _buildChapterHeaderTitle(chapterLabel),
                        SizedBox(
                          height: (_contentFontSize * 0.9).clamp(16.0, 28.0),
                        ),
                      ],
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
                  ),
                  if (shouldShowChapterOverlay)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 48,
                      child: IgnorePointer(
                        child: Text(
                          chapterLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: _chapterOverlayFontSize,
                            height: 1.1,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                            color: _readerSecondaryInfoColor,
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

    if (_epubPages.isEmpty || index >= _epubPages.length) {
      return const SizedBox.shrink();
    }

    final page = _epubPages[index];
    return EpubPageContent(
      key: ValueKey(
        'epub-page-$index-${page.chapter.spineIndex}-${page.layout.pageIndex}-theme-$_themeIndex',
      ),
      chapter: page.chapter,
      layout: page.layout,
      contentPadding: _contentPadding,
      bodyTextStyle: TextStyle(
        fontSize: _contentFontSize,
        height: _contentLineHeight,
        color: _textColor,
        fontFamily: _contentFontFamily,
      ),
      chapterHeaderTitleStyle: _chapterHeaderTitleStyle,
      chapterOverlayFontSize: _chapterOverlayFontSize,
      chapterOverlayReservedHeight: _chapterOverlayReservedHeight,
      chapterOverlayColor: _readerSecondaryInfoColor,
      textStrutStyle: _contentStrutStyle,
      imageBytesByPath: _epubResourceBytes,
      imageMaxHeight: _contentMaxHeight * 0.45,
      bookTitle: book.title,
      bookAuthor: book.author,
      bookLanguage: _epubBookLanguage,
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
                        icon: Icon(
                          Icons.arrow_back,
                          color: const Color(0xFF757575),
                        ), // Gray for back navigation
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
            color: _readerSecondaryInfoColor,
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildChapterNavigationBar(book),
                  const SizedBox(height: 2),
                  Row(
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
                            title: _text(zh: '笔记', en: 'Notes'),
                            child: Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text(
                                _text(
                                  zh: '暂无笔记，长按正文即可添加。',
                                  en: 'No notes yet. Long press the text to add one.',
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      _toolButton(
                        icon: CupertinoIcons.circle,
                        active: _activePanel == _ReaderPanel.progress,
                        onTap: () =>
                            _openPanel(_ReaderPanel.progress, () async {
                              await _showProgressPanel(book, totalPages);
                            }),
                      ),
                      _toolButton(
                        icon: _isDarkReaderBackground
                            ? CupertinoIcons.moon_fill
                            : CupertinoIcons.sun_max_fill,
                        active: true,
                        onTap: _toggleQuickBrightnessTheme,
                        onLongPress: () => _showQuickBrightnessSlider(),
                      ),
                      _toolButton(
                        icon: CupertinoIcons.slider_horizontal_3,
                        active: _activePanel == _ReaderPanel.typography,
                        onTap: () =>
                            _openPanel(_ReaderPanel.typography, () async {
                              await _showSettingsPanel();
                            }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChapterNavigationBar(Book book) {
    final entries = _buildTocEntries(book);
    final currentIndex = _currentChapterNavigationIndex(book, entries);
    final previousEntry = currentIndex > 0 ? entries[currentIndex - 1] : null;
    final nextEntry = currentIndex >= 0 && currentIndex + 1 < entries.length
        ? entries[currentIndex + 1]
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 6),
      child: Row(
        children: [
          _buildChapterNavButton(
            label: _text(zh: '上一章', en: 'Previous'),
            enabled: previousEntry != null,
            onTap: previousEntry == null
                ? null
                : () => _jumpToNavigationEntry(book, previousEntry),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildThemedSlider(
              value: _currentProgressPercent.clamp(0.0, 1.0),
              min: 0,
              max: 1,
              onChanged: (value) {
                if (_isTxtBook(book)) {
                  _jumpToTxtProgress(value);
                  return;
                }
                final maxPage = max(0, _resolveTotalPages(book) - 1);
                _jumpToPage((value * maxPage).round().clamp(0, maxPage));
              },
            ),
          ),
          const SizedBox(width: 10),
          _buildChapterNavButton(
            label: _text(zh: '下一章', en: 'Next'),
            enabled: nextEntry != null,
            onTap: nextEntry == null
                ? null
                : () => _jumpToNavigationEntry(book, nextEntry),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterNavButton({
    required String label,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    final foregroundColor = enabled
        ? _textColor
        : _textColor.withOpacity(_isDarkReaderBackground ? 0.32 : 0.38);

    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: foregroundColor,
        minimumSize: const Size(56, 36),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  double _floatingBottomControlOffset(Book book) {
    const toolbarBaseHeight = 78.0;
    const chapterNavigationExtraHeight = 46.0;
    return toolbarBaseHeight + chapterNavigationExtraHeight;
  }

  Widget _toolButton({
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    bool active = false,
  }) {
    final baseColor = _textColor;
    return GestureDetector(
      onLongPress: onLongPress,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        iconSize: 24,
        splashRadius: 22,
        color: active ? baseColor : baseColor.withOpacity(0.82),
        onPressed: onTap,
        icon: Icon(icon, weight: 50, grade: -25, opticalSize: 22),
      ),
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
    final currentTxtChapter = _currentTxtLocation?.chapterIndex;
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
      title: _text(zh: '阅读进度', en: 'Reading Progress'),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              _metricCell(
                '${(progressValue * 100).toStringAsFixed(1)}%',
                _text(zh: '约21小时后读完', en: 'About 21 hours left'),
              ),
              _metricCell(
                LocaleText.of(context, zh: '18 分钟', en: '18 min'),
                _text(zh: '阅读时长', en: 'Reading Time'),
              ),
              _metricCell(
                LocaleText.of(context, zh: '0 条', en: '0'),
                _text(zh: '笔记', en: 'Notes'),
              ),
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
              Expanded(
                child: _actionPill(_text(zh: '阅读明细', en: 'Reading Details')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionPill(
                  _text(zh: '开启自动翻页', en: 'Enable Auto Page Turn'),
                ),
              ),
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
            title: Text(
              _text(zh: '自动翻页', en: 'Auto Page Turn'),
              style: TextStyle(color: _textColor),
            ),
            dense: true,
          ),
        ],
      ),
    );
  }

  String get _backgroundImageFitLabel {
    switch (_backgroundImageFit) {
      case _ReaderBackgroundImageFit.contain:
        return _text(zh: '适应', en: 'Fit');
      case _ReaderBackgroundImageFit.fill:
        return _text(zh: '拉伸', en: 'Stretch');
      case _ReaderBackgroundImageFit.cover:
        return _text(zh: '填充', en: 'Fill');
    }
  }

  Future<void> _showQuickBrightnessSlider() async {
    HapticFeedback.mediumImpact();
    setState(() => _showControls = false);

    double current = 0.5;
    final prefs = await SharedPreferences.getInstance();
    bool followSystem = prefs.getBool(_prefBrightnessFollowSystem) ?? false;

    try {
      current = followSystem
          ? await ScreenBrightness.instance.system
          : await ScreenBrightness.instance.application;
    } catch (_) {}

    if (!mounted) return;

    StreamSubscription<double>? brightnessSub;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void startListening() {
              brightnessSub?.cancel();
              brightnessSub = ScreenBrightness
                  .instance
                  .onSystemScreenBrightnessChanged
                  .listen((v) {
                    current = v;
                    setModalState(() {});
                  });
            }

            void stopListening() {
              brightnessSub?.cancel();
              brightnessSub = null;
            }

            if (followSystem && brightnessSub == null) {
              startListening();
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: _controlSurfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _textColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.sun_min,
                          size: 20,
                          color: _textColor.withOpacity(0.5),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              activeTrackColor: _textColor.withOpacity(0.5),
                              inactiveTrackColor: _textColor.withOpacity(0.12),
                              thumbColor: _textColor,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                              ),
                              overlayColor: _textColor.withOpacity(0.08),
                            ),
                            child: Slider(
                              value: current,
                              onChanged: (v) {
                                current = v;
                                if (followSystem) {
                                  followSystem = false;
                                  prefs.setBool(
                                    _prefBrightnessFollowSystem,
                                    false,
                                  );
                                  stopListening();
                                }
                                setModalState(() {});
                                ScreenBrightness.instance.setScreenBrightness(
                                  v,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          CupertinoIcons.sun_max_fill,
                          size: 20,
                          color: _textColor.withOpacity(0.5),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: _textColor.withOpacity(0.08)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _text(zh: '跟随系统', en: 'Follow System'),
                            style: TextStyle(fontSize: 14, color: _textColor),
                          ),
                          const Spacer(),
                          CupertinoSwitch(
                            value: followSystem,
                            activeTrackColor: const Color(0xFF3B82F6),
                            onChanged: (v) async {
                              followSystem = v;
                              prefs.setBool(_prefBrightnessFollowSystem, v);
                              setModalState(() {});
                              if (v) {
                                ScreenBrightness.instance
                                    .resetScreenBrightness();
                                try {
                                  current =
                                      await ScreenBrightness.instance.system;
                                } catch (_) {}
                                startListening();
                                setModalState(() {});
                              } else {
                                stopListening();
                                ScreenBrightness.instance.setScreenBrightness(
                                  current,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      brightnessSub?.cancel();
    });
  }

  Future<void> _showSettingsPanel() async {
    final currentIndex = _backgroundMode == _ReaderBackgroundMode.preset
        ? _themeIndex
        : _lightThemeIndex;
    final rootPageKey = GlobalKey();
    double? rootPageHeight;
    var currentPage = _SettingsPanelPage.root;
    var previousPage = _SettingsPanelPage.root;
    var draftFontSizePreset = _fontSizePreset.clamp(16, 40);
    const swatchWidth = 58.0;
    const swatchSpacing = 8.0;
    final viewportWidth = MediaQuery.of(context).size.width - 76;
    final initialOffset = max(
      0.0,
      currentIndex * (swatchWidth + swatchSpacing) -
          (viewportWidth - swatchWidth) / 2,
    );
    final paletteController = ScrollController(
      initialScrollOffset: initialOffset,
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final fontSize = draftFontSizePreset.clamp(16, 40);
          final isForward = currentPage.index >= previousPage.index;
          void syncRootPageHeight() {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final measuredHeight = rootPageKey.currentContext?.size?.height;
              if (measuredHeight == null) {
                return;
              }
              if (rootPageHeight == null ||
                  (rootPageHeight! - measuredHeight).abs() > 1) {
                rootPageHeight = measuredHeight;
                if (mounted) {
                  setModalState(() {});
                }
              }
            });
          }

          void navigateTo(_SettingsPanelPage page) {
            previousPage = currentPage;
            currentPage = page;
            setModalState(() {});
          }

          Widget buildPanelScrollView({
            required Widget child,
            Key? key,
            double bottomPadding = 0,
          }) {
            return ColoredBox(
              color: _controlSurfaceColor,
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  key: key,
                  constraints: BoxConstraints(
                    minHeight: currentPage == _SettingsPanelPage.root
                        ? 0
                        : (rootPageHeight ?? 0),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: child,
                  ),
                ),
              ),
            );
          }

          if (currentPage == _SettingsPanelPage.root) {
            syncRootPageHeight();
          }

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: _controlSurfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(height: 8),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeOutCubic,
                          layoutBuilder: (currentChild, previousChildren) =>
                              ClipRect(
                                child: Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                ),
                              ),
                          transitionBuilder: (child, animation) {
                            final begin = Offset(isForward ? 0.16 : -0.16, 0);
                            return ClipRect(
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: begin,
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(currentPage),
                            child: switch (currentPage) {
                              _SettingsPanelPage.root => buildPanelScrollView(
                                key: rootPageKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSettingsSection(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionHeader(
                                            title: _text(
                                              zh: '背景',
                                              en: 'Background',
                                            ),
                                            value:
                                                _presetThemes[_themeIndex].name,
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            height: 60,
                                            child: ListView.separated(
                                              controller: paletteController,
                                              scrollDirection: Axis.horizontal,
                                              physics:
                                                  const BouncingScrollPhysics(),
                                              itemCount: _presetThemes.length,
                                              separatorBuilder: (_, _) =>
                                                  const SizedBox(width: 8),
                                              itemBuilder: (context, index) {
                                                final theme =
                                                    _presetThemes[index];
                                                final isActive =
                                                    _backgroundMode ==
                                                        _ReaderBackgroundMode
                                                            .preset &&
                                                    _themeIndex == index;
                                                final isStored =
                                                    index == _lightThemeIndex ||
                                                    index == _darkThemeIndex;
                                                return _buildThemeSwatch(
                                                  theme: theme,
                                                  isActive: isActive,
                                                  isStored: isStored,
                                                  onTap: () {
                                                    _activatePresetTheme(index);
                                                    setModalState(() {});
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          _buildCompactSettingRow(
                                            title: _text(
                                              zh: '自定义图片背景',
                                              en: 'Custom Image Background',
                                            ),
                                            subtitle: _isCustomBackgroundActive
                                                ? _text(
                                                    zh: '已设置',
                                                    en: 'Configured',
                                                  )
                                                : _text(
                                                    zh: '未设置',
                                                    en: 'Not set',
                                                  ),
                                            onTap: () => navigateTo(
                                              _SettingsPanelPage
                                                  .customBackground,
                                            ),
                                            isLast: true,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildSettingsSection(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionHeader(
                                            title: _text(
                                              zh: '字体与排版',
                                              en: 'Typography',
                                            ),
                                            value: '$fontSize',
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              _buildScaleMark(
                                                label: 'A',
                                                small: true,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: _buildThemedSlider(
                                                  value: fontSize.toDouble(),
                                                  min: 16,
                                                  max: 40,
                                                  divisions: 12,
                                                  onChanged: (v) {
                                                    draftFontSizePreset = v
                                                        .round()
                                                        .clamp(16, 40);
                                                    setModalState(() {});
                                                  },
                                                  onChangeEnd: (_) {
                                                    final nextFontSize =
                                                        draftFontSizePreset
                                                            .clamp(16, 40);
                                                    if (nextFontSize ==
                                                        _fontSizePreset) {
                                                      return;
                                                    }
                                                    setState(() {
                                                      _fontSizePreset =
                                                          nextFontSize;
                                                    });
                                                    _scheduleSaveReaderPreferences();
                                                    _scheduleRepaginate();
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              _buildScaleMark(
                                                label: 'A',
                                                small: false,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          _buildCompactSettingRow(
                                            title: _text(
                                              zh: '字体样式',
                                              en: 'Font Style',
                                            ),
                                            subtitle: _text(
                                              zh: '默认',
                                              en: 'Default',
                                            ),
                                            onTap: () => navigateTo(
                                              _SettingsPanelPage.fontStyle,
                                            ),
                                          ),
                                          _buildCompactSettingRow(
                                            title: _text(
                                              zh: '版式',
                                              en: 'Layout',
                                            ),
                                            subtitle:
                                                '${_paddingPreset == 0
                                                    ? _text(zh: '边距小', en: 'Small margin')
                                                    : _paddingPreset == 1
                                                    ? _text(zh: '边距中', en: 'Medium margin')
                                                    : _text(zh: '边距大', en: 'Large margin')} / ${_lineHeightPreset <= 1
                                                    ? _text(zh: '行距紧', en: 'Tight')
                                                    : _lineHeightPreset == 2
                                                    ? _text(zh: '行距适中', en: 'Medium')
                                                    : _text(zh: '行距松', en: 'Loose')}',
                                            emphasis: false,
                                            onTap: () => navigateTo(
                                              _SettingsPanelPage.layout,
                                            ),
                                          ),
                                          _buildCompactSettingRow(
                                            title: _text(
                                              zh: '更多设置',
                                              en: 'More Settings',
                                            ),
                                            subtitle:
                                                '${_oneHandModeEnabled ? _text(zh: '单手模式开', en: 'One-hand on') : _text(zh: '单手模式关', en: 'One-hand off')} / ${_edgeSwipeExitEnabled ? _text(zh: '右滑退出开', en: 'Edge swipe on') : _text(zh: '右滑退出关', en: 'Edge swipe off')}',
                                            emphasis: false,
                                            onTap: () => navigateTo(
                                              _SettingsPanelPage.more,
                                            ),
                                            isLast: true,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _SettingsPanelPage.fontStyle =>
                                buildPanelScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildInlineSubpageHeader(
                                        title: _text(
                                          zh: '字体样式',
                                          en: 'Font Style',
                                        ),
                                        onBack: () =>
                                            navigateTo(_SettingsPanelPage.root),
                                      ),
                                      _buildSettingsSection(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _panelSubTitle(
                                              _text(zh: '字体', en: 'Font'),
                                            ),
                                            const SizedBox(height: 8),
                                            _segmentedChoices(
                                              labels: [
                                                _text(zh: '默认', en: 'Default'),
                                                _text(zh: '衬线', en: 'Serif'),
                                                _text(zh: '等宽', en: 'Mono'),
                                              ],
                                              selectedIndex: _fontStylePreset,
                                              onSelect: (index) {
                                                setState(() {
                                                  _fontStylePreset = index
                                                      .clamp(0, 2);
                                                });
                                                _scheduleSaveReaderPreferences();
                                                _scheduleRepaginate();
                                                setModalState(() {});
                                              },
                                            ),
                                            const SizedBox(height: 12),
                                            _panelSubTitle(
                                              _text(zh: '布局方式', en: 'Layout'),
                                            ),
                                            const SizedBox(height: 8),
                                            _segmentedChoices(
                                              labels: [
                                                _text(zh: '自动', en: 'Auto'),
                                                _text(zh: '两端', en: 'Justify'),
                                                _text(zh: '左对齐', en: 'Left'),
                                                _text(zh: '居中', en: 'Center'),
                                              ],
                                              selectedIndex: _textAlignPreset,
                                              onSelect: (index) {
                                                setState(() {
                                                  _textAlignPreset = index
                                                      .clamp(0, 3);
                                                });
                                                _scheduleSaveReaderPreferences();
                                                _scheduleRepaginate();
                                                setModalState(() {});
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              _SettingsPanelPage.layout => buildPanelScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInlineSubpageHeader(
                                      title: _text(zh: '版式', en: 'Layout'),
                                      onBack: () =>
                                          navigateTo(_SettingsPanelPage.root),
                                    ),
                                    _buildBackgroundControlCard(
                                      title: _text(zh: '边距', en: 'Margin'),
                                      subtitle: _paddingPreset == 0
                                          ? _text(zh: '小', en: 'Small')
                                          : _paddingPreset == 1
                                          ? _text(zh: '中', en: 'Medium')
                                          : _text(zh: '大', en: 'Large'),
                                      enabled: true,
                                      child: _buildThemedSlider(
                                        value: _paddingPreset.toDouble(),
                                        min: 0,
                                        max: 2,
                                        divisions: 2,
                                        onChanged: (value) {
                                          setState(() {
                                            _paddingPreset = value
                                                .round()
                                                .clamp(0, 2);
                                          });
                                          _scheduleSaveReaderPreferences();
                                          _scheduleRepaginate();
                                          setModalState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _buildBackgroundControlCard(
                                      title: _text(zh: '行距', en: 'Line Height'),
                                      subtitle: _lineHeightPreset <= 1
                                          ? _text(zh: '紧', en: 'Tight')
                                          : _lineHeightPreset == 2
                                          ? _text(zh: '适中', en: 'Medium')
                                          : _text(zh: '松', en: 'Loose'),
                                      enabled: true,
                                      child: _buildThemedSlider(
                                        value:
                                            (_lineHeightPreset <= 1
                                                    ? 0
                                                    : _lineHeightPreset == 2
                                                    ? 1
                                                    : 2)
                                                .toDouble(),
                                        min: 0,
                                        max: 2,
                                        divisions: 2,
                                        onChanged: (value) {
                                          setState(() {
                                            _lineHeightPreset =
                                                value.round() == 0
                                                ? 1
                                                : value.round() == 1
                                                ? 2
                                                : 3;
                                          });
                                          _scheduleSaveReaderPreferences();
                                          _scheduleRepaginate();
                                          setModalState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    _buildSettingsSection(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _panelSubTitle(
                                            _text(zh: '首行缩进', en: 'Indent'),
                                          ),
                                          const SizedBox(height: 8),
                                          _segmentedChoices(
                                            labels: [
                                              _text(
                                                zh: '首行缩进',
                                                en: 'First-line indent',
                                              ),
                                              _text(
                                                zh: '首行顶格',
                                                en: 'Flush left',
                                              ),
                                            ],
                                            selectedIndex:
                                                _paragraphIndentEnabled ? 0 : 1,
                                            onSelect: (index) {
                                              setState(() {
                                                _paragraphIndentEnabled =
                                                    index == 0;
                                              });
                                              _scheduleSaveReaderPreferences();
                                              _scheduleRepaginate();
                                              setModalState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _SettingsPanelPage.customBackground => buildPanelScrollView(
                                bottomPadding: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInlineSubpageHeader(
                                      title: _text(
                                        zh: '自定义图片背景',
                                        en: 'Custom Image Background',
                                      ),
                                      onBack: () =>
                                          navigateTo(_SettingsPanelPage.root),
                                    ),
                                    _buildCustomBackgroundPreviewCard(),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _modernActionButton(
                                            label: _isPickingBackgroundImage
                                                ? _text(
                                                    zh: '选择中...',
                                                    en: 'Selecting...',
                                                  )
                                                : _text(
                                                    zh: '更换图片',
                                                    en: 'Change Image',
                                                  ),
                                            isSecondary: false,
                                            icon: Icons.photo_library_outlined,
                                            onTap: _isPickingBackgroundImage
                                                ? null
                                                : () async {
                                                    await _pickCustomBackgroundImage();
                                                    if (mounted) {
                                                      setModalState(() {});
                                                    }
                                                  },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _modernActionButton(
                                            label: _text(
                                              zh: '恢复纯色',
                                              en: 'Restore Solid',
                                            ),
                                            isSecondary: true,
                                            icon: Icons.layers_clear_outlined,
                                            onTap: _isCustomBackgroundActive
                                                ? () {
                                                    _clearCustomBackgroundImage();
                                                    setModalState(() {});
                                                  }
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    _buildSettingsSection(
                                      child: Opacity(
                                        opacity: _isCustomBackgroundActive
                                            ? 1
                                            : 0.55,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildEmbeddedBackgroundControl(
                                              title: _text(
                                                zh: '显示方式',
                                                en: 'Display Mode',
                                              ),
                                              subtitle:
                                                  _backgroundImageFitLabel,
                                              child: Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  _backgroundFitChip(
                                                    label: _text(
                                                      zh: '填充',
                                                      en: 'Fill',
                                                    ),
                                                    fit:
                                                        _ReaderBackgroundImageFit
                                                            .cover,
                                                    onChanged: setModalState,
                                                  ),
                                                  _backgroundFitChip(
                                                    label: _text(
                                                      zh: '适应',
                                                      en: 'Fit',
                                                    ),
                                                    fit:
                                                        _ReaderBackgroundImageFit
                                                            .contain,
                                                    onChanged: setModalState,
                                                  ),
                                                  _backgroundFitChip(
                                                    label: _text(
                                                      zh: '拉伸',
                                                      en: 'Stretch',
                                                    ),
                                                    fit:
                                                        _ReaderBackgroundImageFit
                                                            .fill,
                                                    onChanged: setModalState,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            _buildEmbeddedBackgroundControl(
                                              title: _text(
                                                zh: '遮罩强度',
                                                en: 'Overlay Strength',
                                              ),
                                              subtitle:
                                                  '${(_backgroundOverlayOpacity * 100).round()}%',
                                              showDivider: true,
                                              child: _buildThemedSlider(
                                                value:
                                                    _backgroundOverlayOpacity,
                                                min: 0,
                                                max: 0.6,
                                                divisions: 12,
                                                onChanged:
                                                    _isCustomBackgroundActive
                                                    ? (value) {
                                                        setState(() {
                                                          _backgroundOverlayOpacity =
                                                              value;
                                                        });
                                                        _scheduleSaveReaderPreferences();
                                                        setModalState(() {});
                                                      }
                                                    : null,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            _buildEmbeddedBackgroundControl(
                                              title: _text(
                                                zh: '背景模糊',
                                                en: 'Background Blur',
                                              ),
                                              subtitle: _backgroundBlurSigma
                                                  .toStringAsFixed(1),
                                              showDivider: true,
                                              child: _buildThemedSlider(
                                                value: _backgroundBlurSigma,
                                                min: 0,
                                                max: 12,
                                                divisions: 12,
                                                onChanged:
                                                    _isCustomBackgroundActive
                                                    ? (value) {
                                                        setState(() {
                                                          _backgroundBlurSigma =
                                                              value;
                                                        });
                                                        _scheduleSaveReaderPreferences();
                                                        setModalState(() {});
                                                      }
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _SettingsPanelPage.more => buildPanelScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInlineSubpageHeader(
                                      title: _text(
                                        zh: '更多设置',
                                        en: 'More Settings',
                                      ),
                                      onBack: () =>
                                          navigateTo(_SettingsPanelPage.root),
                                    ),
                                    _buildSettingsSection(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildSwitchSettingRow(
                                            title: _text(
                                              zh: '单手模式',
                                              en: 'One-hand Mode',
                                            ),
                                            subtitle: _text(
                                              zh: '点击正文界面的左侧和右侧都向后翻页',
                                              en: 'Tapping both the left and right side turns to the next page',
                                            ),
                                            value: _oneHandModeEnabled,
                                            onChanged: (value) {
                                              setState(() {
                                                _oneHandModeEnabled = value;
                                              });
                                              _scheduleSaveReaderPreferences();
                                              setModalState(() {});
                                            },
                                          ),
                                          _buildSwitchSettingRow(
                                            title: _text(
                                              zh: '右滑退出',
                                              en: 'Edge Swipe Exit',
                                            ),
                                            subtitle: _text(
                                              zh: '从屏幕左边缘向右滑动退出阅读',
                                              en: 'Swipe right from the left screen edge to exit reading',
                                            ),
                                            value: _edgeSwipeExitEnabled,
                                            onChanged: (value) {
                                              setState(() {
                                                _edgeSwipeExitEnabled = value;
                                              });
                                              _scheduleSaveReaderPreferences();
                                              setModalState(() {});
                                            },
                                            isLast: true,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    paletteController.dispose();
  }

  Widget _buildSettingsSection({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _readerBgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }

  Widget _buildSectionHeader({required String title, required String value}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textColor,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF3B82F6),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInlineSubpageHeader({
    required String title,
    required VoidCallback onBack,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            onPressed: onBack,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: const Color(
                0xFF757575,
              ).withValues(alpha: 0.72), // Gray for navigation
            ),
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSwatch({
    required _ThemeOption theme,
    required bool isActive,
    required bool isStored,
    required VoidCallback onTap,
  }) {
    final isDarkTheme = _isDarkThemeIndex(theme.id);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 58,
        decoration: BoxDecoration(
          color: theme.color,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: isActive ? const Color(0xFF3B82F6) : Colors.transparent,
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: (isStored ? const Color(0xFF3B82F6) : Colors.black)
                    .withOpacity(isStored ? 0.08 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 7),
            width: 20,
            height: 4,
            decoration: BoxDecoration(
              color: isStored
                  ? (isDarkTheme ? Colors.white : const Color(0xFF3B82F6))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScaleMark({required String label, required bool small}) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _textColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: small ? 13 : 22,
          color: _textColor.withOpacity(0.7),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCompactSettingRow({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool emphasis = true,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(color: _textColor.withOpacity(0.08)),
                  ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: emphasis
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: _textColor.withOpacity(emphasis ? 0.62 : 0.54),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: const Color(
                  0xFF757575,
                ).withValues(alpha: 0.38), // Gray for navigation
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchSettingRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: _textColor.withOpacity(0.08))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _textColor.withOpacity(0.58),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (_isIOS)
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: const Color(0xFF3B82F6),
            )
          else
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: const Color(0xFF3B82F6),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomBackgroundPreviewCard() {
    final hasImage = _isCustomBackgroundActive;
    final imagePath = _customBackgroundImagePath;
    final preview = hasImage && imagePath != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(imagePath),
                  fit: _readerBackgroundBoxFit,
                  errorBuilder: (context, error, stackTrace) {
                    return ColoredBox(
                      color: _readerBgColor,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: _textColor.withOpacity(0.55),
                        size: 28,
                      ),
                    );
                  },
                ),
                if (_backgroundOverlayOpacity > 0)
                  ColoredBox(color: _readerBackgroundOverlayColor),
                Center(
                  child: Container(
                    width: 132,
                    height: 78,
                    decoration: BoxDecoration(
                      color: _readerContentSurfaceColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _textColor.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Text(
                      _text(
                        zh: '正文预览\n风吹一页，光落一行。',
                        en: 'Preview\nA page turns, and light lands on each line.',
                      ),
                      style: TextStyle(
                        color: _textColor,
                        height: 1.5,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        : Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _readerBgColor.withOpacity(0.95),
                  _readerBgColor.withOpacity(0.78),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 30,
                    color: _textColor.withOpacity(0.62),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _text(
                      zh: '选择一张本地图片作为正文背景',
                      en: 'Choose a local image for the reading background',
                    ),
                    style: TextStyle(
                      color: _textColor.withOpacity(0.72),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );

    return Container(
      height: 148,
      decoration: BoxDecoration(
        color: _readerBgColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasImage
                      ? _text(zh: '当前正文背景', en: 'Current Reading Background')
                      : _text(zh: '未设置图片背景', en: 'No Image Background'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
              ),
              if (hasImage)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _isDarkReaderBackground
                        ? _text(zh: '深图', en: 'Dark')
                        : _text(zh: '浅图', en: 'Light'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(child: preview),
        ],
      ),
    );
  }

  Widget _buildBackgroundControlCard({
    required String title,
    required String subtitle,
    required bool enabled,
    required Widget child,
  }) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: _readerBgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildEmbeddedBackgroundControl({
    required String title,
    required String subtitle,
    required Widget child,
    bool showDivider = false,
  }) {
    return Container(
      padding: EdgeInsets.only(top: showDivider ? 8 : 0),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(top: BorderSide(color: _textColor.withOpacity(0.08)))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _backgroundFitChip({
    required String label,
    required _ReaderBackgroundImageFit fit,
    required void Function(void Function()) onChanged,
  }) {
    final selected = _backgroundImageFit == fit;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _isCustomBackgroundActive
            ? () {
                setState(() {
                  _backgroundImageFit = fit;
                });
                _scheduleSaveReaderPreferences();
                onChanged(() {});
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF3B82F6)
                : _textColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : _textColor.withOpacity(0.82),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modernActionButton({
    required String label,
    required bool isSecondary,
    VoidCallback? onTap,
    IconData? icon,
  }) {
    final isEnabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSecondary
                ? const Color(0xFF3B82F6).withOpacity(isEnabled ? 1 : 0.45)
                : _textColor.withOpacity(isEnabled ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSecondary && isEnabled
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
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: isSecondary
                      ? Colors.white
                      : _textColor.withOpacity(isEnabled ? 0.74 : 0.38),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isSecondary
                      ? Colors.white
                      : _textColor.withOpacity(isEnabled ? 1 : 0.45),
                  letterSpacing: 0.3,
                ),
              ),
              if (!isSecondary && icon == null) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.refresh_rounded,
                  size: 16,
                  color: _textColor.withOpacity(isEnabled ? 0.6 : 0.32),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemedSlider({
    required double value,
    required double min,
    required double max,
    int? divisions,
    ValueChanged<double>? onChanged,
    ValueChanged<double>? onChangeEnd,
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
        onChangeEnd: onChangeEnd,
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
      final shouldForward = _oneHandModeEnabled;
      if (_txtPages.isNotEmpty && _currentTxtLocation != null) {
        _turnTxtPage(forward: shouldForward, book: null);
        _lastPageTurnStart = tapStart;
        return;
      }
      _turnPage(
        forward: shouldForward,
        totalPages: totalPages,
        tapStart: tapStart,
      );
      _lastPageTurnStart = tapStart;
      return;
    }

    if (dx > width * 0.7) {
      if (_txtPages.isNotEmpty && _currentTxtLocation != null) {
        _turnTxtPage(forward: true, book: null);
        _lastPageTurnStart = tapStart;
        return;
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

      var lookbackStartOffset = safeStart;
      final previousPage = _currentPage > 0
          ? _txtPages[_currentPage - 1]
          : null;
      if (previousPage != null &&
          previousPage.chapterIndex == page.chapterIndex) {
        lookbackStartOffset = previousPage.startOffset.clamp(0, safeStart);
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
          child: AudiobookPageRedesign(
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
            textColor: _textColor,
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

  /// 直接开始播放，不打开全屏界面，让悬浮控制面板显示
  Future<void> _startFloatingPlayback({
    required Book book,
    required int totalPages,
  }) async {
    final launchData = _buildAudiobookLaunchData(book);
    if (!mounted || launchData == null) {
      return;
    }

    try {
      // 选择音色
      await ref
          .read(ttsProvider.notifier)
          .selectVoiceForBook(book, sampleText: launchData.initialText);

      final chapterText = launchData.chapterText;
      final textToSpeak = (chapterText != null && chapterText.trim().isNotEmpty)
          ? chapterText
                .substring(
                  launchData.initialOffset.clamp(0, chapterText.length).toInt(),
                )
                .trim()
          : launchData.initialText;

      if (textToSpeak.trim().isEmpty) {
        return;
      }

      await ref
          .read(ttsProvider.notifier)
          .speak(
            textToSpeak,
            book: book,
            chapterTitle: launchData.chapterTitle,
            startOffset: launchData.initialOffset,
            chapterIndex: launchData.chapterIndex,
            chapterLength: launchData.chapterText?.length,
            chapterQueue: _mapTtsChapterQueue(launchData.chapterQueue),
            continuousChapterQueue: true,
          );
    } catch (_) {
      // 播放失败，静默处理
    }
  }

  List<TtsChapterPayload> _mapTtsChapterQueue(
    List<AudiobookChapterPayload> queue,
  ) {
    if (queue.isEmpty) {
      return const <TtsChapterPayload>[];
    }
    return queue
        .map(
          (item) => TtsChapterPayload(
            title: item.title,
            text: item.text,
            index: item.index,
          ),
        )
        .toList(growable: false);
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

    // 修改为直接开始播放，不打开全屏界面
    await _startFloatingPlayback(book: book, totalPages: totalPages);
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

  int? _previousTxtChapterIndex(int? currentChapterIndex) {
    if (currentChapterIndex == null || _txtChapters.isEmpty) {
      return null;
    }
    final currentPos = _txtChapters.indexWhere(
      (chapter) => chapter.index == currentChapterIndex,
    );
    if (currentPos <= 0) {
      return null;
    }
    return _txtChapters[currentPos - 1].index;
  }

  int _currentChapterNavigationIndex(Book book, List<_TocEntry> entries) {
    if (entries.isEmpty) {
      return -1;
    }
    if (_isTxtBook(book)) {
      final currentChapterIndex = _currentTxtLocation?.chapterIndex;
      if (currentChapterIndex != null) {
        final txtIndex = entries.indexWhere(
          (entry) => entry.chapterIndex == currentChapterIndex,
        );
        if (txtIndex >= 0) {
          return txtIndex;
        }
      }
    }

    final pageIndex = entries.lastIndexWhere(
      (entry) => entry.pageIndex <= _currentPage,
    );
    return pageIndex >= 0 ? pageIndex : 0;
  }

  void _jumpToNavigationEntry(Book book, _TocEntry entry) {
    if (_isTxtBook(book) && entry.chapterIndex != null) {
      _jumpToTxtChapter(entry.chapterIndex!);
      _scheduleSaveTxtProgress(book);
      return;
    }
    _jumpToPage(entry.pageIndex);
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
    _loadTxtChapterAtLocation(
      _TxtLocation(chapterIndex: chapterIndex, offset: safeOffset),
    );
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
    if (tapStart != null && computeStart != null) {
      print('📊 翻页延迟分析:');
      print('  点击事件 → _handleTap: 0ms');
      print(
        '  _handleTap → _turnPage: ${(computeStart - tapStart) / 1000}μs = ${(computeStart - tapStart) / 1000.0}ms',
      );
      print(
        '  _turnPage → _jumpToPage: ${(jumpStart - computeStart) / 1000}μs = ${(jumpStart - computeStart) / 1000.0}ms',
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

  bool _handlePageScrollNotification(
    ScrollNotification notification,
    int totalPages,
  ) {
    return false;
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

  void _replacePageController(int initialPage) {
    final previous = _pageController;
    _pageController = PageController(
      keepPage: false,
      initialPage: max(0, initialPage),
    );
    previous.dispose();
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
      if (_txtPages.isNotEmpty && _currentTxtLocation != null) {
        _turnTxtPage(forward: true, book: null);
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
    _logOpenTrace('txt load start');
    _txtOpeningViewDelayTimer?.cancel();
    _txtOpeningViewDelayTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted || !_isLoadingTxt) {
        return;
      }
      setState(() {
        _showTxtOpeningView = true;
      });
    });
    setState(() {
      _isLoadingTxt = true;
      _txtError = null;
    });

    try {
      final resolvedPath = await _resolveTxtPath(book.epubPath);
      if (resolvedPath == null) {
        throw Exception('TXT file not found. Please re-import this book.');
      }

      var cacheData = await _txtImportCacheService.read(book.id);
      if (cacheData == null) {
        final readStart = DateTime.now().microsecondsSinceEpoch;
        final decoded = await _readTxtContentFromResolvedPath(resolvedPath);
        _logOpenTrace(
          'txt bytes+decode complete (${((DateTime.now().microsecondsSinceEpoch - readStart) / 1000.0).toStringAsFixed(1)}ms)',
        );
        final parseStart = DateTime.now().microsecondsSinceEpoch;
        cacheData = await _txtImportCacheService.prepare(
          text: decoded.text,
          encoding: decoded.encoding,
        );
        _logOpenTrace(
          'txt chapter parse complete (${((DateTime.now().microsecondsSinceEpoch - parseStart) / 1000.0).toStringAsFixed(1)}ms)',
        );
        await _txtImportCacheService.write(bookId: book.id, data: cacheData);
      } else {
        _logOpenTrace('txt structure cache hit');
      }
      final chapters = cacheData.chapters
          .map(
            (chapter) => _TxtChapter(
              title: chapter.title,
              content: chapter.content,
              index: chapter.index,
            ),
          )
          .toList(growable: false);

      final progressStart = DateTime.now().microsecondsSinceEpoch;
      final existingProgress = await ref
          .read(getReadingProgressUseCaseProvider)
          .call(book.id);
      _logOpenTrace(
        'reading progress restored (${((DateTime.now().microsecondsSinceEpoch - progressStart) / 1000.0).toStringAsFixed(1)}ms)',
      );
      _readingTimeSeconds = existingProgress?.readingTimeSeconds ?? 0;

      if (!mounted) {
        return;
      }

      final chapterByIndex = <int, _TxtChapter>{
        for (final chapter in chapters) chapter.index: chapter,
      };
      final chapterGlobalStart = <int, int>{
        for (final chapter in cacheData.chapters)
          chapter.index: chapter.globalStart,
      };
      final totalLength = cacheData.totalLength;

      final layoutStart = DateTime.now().microsecondsSinceEpoch;
      _logOpenTrace(
        'txt initial viewport build start, chapters=${chapters.length}, totalLength=$totalLength',
      );
      final initialLocation = _resolveTxtLocationFromData(
        chapters: chapters,
        chapterByIndex: chapterByIndex,
        location: existingProgress?.location,
      );
      final initialPages = _buildTxtPageWindowForLocation(
        location: initialLocation,
        chapters: chapters,
        chapterByIndex: chapterByIndex,
      );
      final initialPageIndex = _resolvePageFromLocation(
        'txt:${initialLocation.chapterIndex}:${initialLocation.offset}',
        initialPages,
      );
      _logOpenTrace(
        'txt initial viewport build complete (${((DateTime.now().microsecondsSinceEpoch - layoutStart) / 1000.0).toStringAsFixed(1)}ms), chapter=${initialLocation.chapterIndex}, offset=${initialLocation.offset}, pageIndex=$initialPageIndex',
      );
      _replacePageController(initialPageIndex);
      _didLogTxtContentFrame = false;
      setState(() {
        _txtChapters = chapters;
        _txtChapterByIndex = chapterByIndex;
        _txtChapterGlobalStart = chapterGlobalStart;
        _txtTotalLength = totalLength;
        _txtPages = initialPages;
        _txtToc = _buildTocFromChapters();
        _currentTxtLocation = initialLocation;
        _loadedTxtPath = book.epubPath;
        _currentPage = initialPageIndex;
        _isLoadingTxt = false;
        _showTxtOpeningView = false;
        _txtLoadScheduled = false;
      });
      _logOpenTrace('txt reader state committed');

      _txtOpeningViewDelayTimer?.cancel();
      _logOpenTrace(
        'txt load ready from location, chapter=${initialLocation.chapterIndex}, offset=${initialLocation.offset}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didLogTxtContentFrame || _txtPages.isEmpty) {
          return;
        }
        _didLogTxtContentFrame = true;
        final page = _txtPages[_currentPage.clamp(0, _txtPages.length - 1)];
        _logOpenTrace(
          'txt content frame rendered, chapter=${page.chapterIndex}, page=${page.startOffset}-${page.endOffset}',
        );
      });
    } catch (e) {
      _logOpenTrace('txt load failed: $e');
      if (!mounted) {
        return;
      }
      setState(() {
        _txtError = 'Failed to load TXT: $e';
        _loadedTxtPath = book.epubPath;
        _isLoadingTxt = false;
        _showTxtOpeningView = false;
        _txtLoadScheduled = false;
      });
      _txtOpeningViewDelayTimer?.cancel();
    }
  }

  Future<void> _loadEpubBook(Book book, {String? preferredLocation}) async {
    _epubOpeningViewDelayTimer?.cancel();
    _epubOpeningViewDelayTimer = Timer(const Duration(milliseconds: 140), () {
      if (!mounted || !_isLoadingEpub) {
        return;
      }
      setState(() {
        _showEpubOpeningView = true;
      });
    });
    setState(() {
      _isLoadingEpub = true;
      _epubError = null;
    });

    try {
      var cacheData = await _epubImportCacheService.read(book.id);
      if (cacheData == null) {
        cacheData = await _epubImportCacheService.prepare(
          bookId: book.id,
          epubPath: book.epubPath,
        );
        await _epubImportCacheService.write(bookId: book.id, data: cacheData);
      }
      if (cacheData.document.chapters.isEmpty) {
        throw StateError('EPUB has no readable chapters.');
      }
      final resolvedCacheData = cacheData;

      final sourceFileExists = await File(book.epubPath).exists();
      final resources = sourceFileExists
          ? _collectEpubResourceBytes(
              document: resolvedCacheData.document,
              entries: await _epubArchiveService.readEntries(book.epubPath),
            )
          : <String, Uint8List>{};
      final progress = await ref
          .read(getReadingProgressUseCaseProvider)
          .call(book.id);
      _readingTimeSeconds = progress?.readingTimeSeconds ?? 0;

      if (!mounted) {
        return;
      }

      final settings = _buildEpubPaginationSettings();
      final paginator = EpubPaginator(
        measurer: FlutterLayoutMeasurer(fontFamily: _contentFontFamily),
      );
      final chapterPagesBySpine = <int, List<PageLayout>>{};
      final chapterStartPageBySpine = <int, int>{};
      final flattenedPages = <_EpubPageEntry>[];

      for (final chapter in resolvedCacheData.document.chapters) {
        chapterStartPageBySpine[chapter.spineIndex] = flattenedPages.length;
        final cacheKey = EpubPaginationCacheKey(
          bookId: book.id,
          spineIndex: chapter.spineIndex,
          viewportWidth: settings.viewportWidth,
          viewportHeight: settings.viewportHeight,
          fontSize: settings.fontSize,
          lineHeight: settings.lineHeight,
          paddingPreset: 'p$_paddingPreset-f$_fontStylePreset',
          imageLayoutPolicy: 'contain',
          themeProfileVersion: 1,
        );
        final cachedPages = await _epubPaginationCacheService.read(
          cacheKey: cacheKey,
        );
        final pages =
            cachedPages ??
            paginator.paginate(chapter: chapter, settings: settings).pages;
        if (cachedPages == null) {
          await _epubPaginationCacheService.write(
            cacheKey: cacheKey,
            pages: pages,
          );
        }
        chapterPagesBySpine[chapter.spineIndex] = pages;
        flattenedPages.addAll(
          pages.map((page) => _EpubPageEntry(chapter: chapter, layout: page)),
        );
      }

      final initialPage = _resolveInitialEpubPage(
        location: preferredLocation ?? progress?.location,
        chapterPagesBySpine: chapterPagesBySpine,
        chapterStartPageBySpine: chapterStartPageBySpine,
        totalPages: flattenedPages.length,
      );
      final safeInitialPage = initialPage
          .clamp(0, max(0, flattenedPages.length - 1))
          .toInt();
      final initialLocator = flattenedPages.isEmpty
          ? null
          : _locatorForEpubPage(safeInitialPage, pages: flattenedPages);
      _replacePageController(safeInitialPage);
      setState(() {
        _epubPages = List<_EpubPageEntry>.unmodifiable(flattenedPages);
        _epubToc = _buildEpubToc(
          document: resolvedCacheData.document,
          packageToc: resolvedCacheData.package.toc,
          pages: flattenedPages,
        );
        _currentPage = safeInitialPage;
        _currentEpubLocator = initialLocator;
        _epubResourceBytes = resources;
        _epubBookLanguage =
            resolvedCacheData.document.language ??
            resolvedCacheData.package.metadata.language;
        _loadedEpubPath = book.epubPath;
        _isLoadingEpub = false;
        _showEpubOpeningView = false;
        _epubLoadScheduled = false;
      });
      _restorePageAfterBuild(safeInitialPage);
      _epubOpeningViewDelayTimer?.cancel();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _epubError = 'Failed to load EPUB: $e';
        _loadedEpubPath = book.epubPath;
        _isLoadingEpub = false;
        _showEpubOpeningView = false;
        _epubLoadScheduled = false;
      });
      _epubOpeningViewDelayTimer?.cancel();
    }
  }

  PaginationSettings _buildEpubPaginationSettings() {
    final media = MediaQuery.of(context);
    return PaginationSettings(
      viewportWidth: media.size.width,
      viewportHeight:
          media.size.height -
          media.padding.top -
          media.padding.bottom -
          _chapterHeaderBlockHeight,
      contentPaddingTop: _contentPadding.top,
      contentPaddingBottom: _contentPadding.bottom + _paginationSafetyInset,
      contentPaddingHorizontal: _contentPadding.left,
      fontSize: _contentFontSize,
      lineHeight: _contentLineHeight,
    );
  }

  Map<String, Uint8List> _collectEpubResourceBytes({
    required BookDocument document,
    required Map<String, List<int>> entries,
  }) {
    final resourcePaths = <String>{
      for (final chapter in document.chapters)
        for (final block in chapter.blocks)
          if (block.type == BlockNodeType.image && block.src != null)
            block.src!,
    };
    return {
      for (final path in resourcePaths)
        if (entries.containsKey(path)) path: Uint8List.fromList(entries[path]!),
    };
  }

  int _resolveInitialEpubPage({
    required String? location,
    required Map<int, List<PageLayout>> chapterPagesBySpine,
    required Map<int, int> chapterStartPageBySpine,
    required int totalPages,
  }) {
    if (totalPages <= 0) {
      return 0;
    }
    if (location != null && location.startsWith('epub:')) {
      try {
        final locator = ReaderLocator.decode(location.substring(5));
        final chapterPages = chapterPagesBySpine[locator.spineIndex];
        final chapterStartPage = chapterStartPageBySpine[locator.spineIndex];
        if (chapterPages != null &&
            chapterPages.isNotEmpty &&
            chapterStartPage != null) {
          return (chapterStartPage +
                  LocatorMapper.pageIndexFor(
                    locator: locator,
                    pages: chapterPages,
                  ))
              .clamp(0, totalPages - 1);
        }
      } catch (_) {}
    }
    if (location != null && location.startsWith('page:')) {
      final savedPage = int.tryParse(location.substring(5));
      if (savedPage != null) {
        return savedPage.clamp(0, totalPages - 1);
      }
    }
    return 0;
  }

  List<_TocEntry> _buildEpubToc({
    required BookDocument document,
    required List<EpubTocEntry> packageToc,
    required List<_EpubPageEntry> pages,
  }) {
    if (pages.isEmpty) {
      return const [];
    }

    final chapterFirstPage = <String, int>{};
    for (var index = 0; index < pages.length; index++) {
      chapterFirstPage.putIfAbsent(
        _normalizeEpubHref(pages[index].chapter.href),
        () => index,
      );
    }

    final tocEntries = <_TocEntry>[];
    final seenPages = <int>{};
    for (final entry in packageToc) {
      final pageIndex = chapterFirstPage[_normalizeEpubHref(entry.href)];
      if (pageIndex == null || !seenPages.add(pageIndex)) {
        continue;
      }
      tocEntries.add(_TocEntry(title: entry.title, pageIndex: pageIndex));
    }
    if (tocEntries.isNotEmpty) {
      return tocEntries;
    }

    for (var index = 0; index < document.chapters.length; index++) {
      final chapter = document.chapters[index];
      final pageIndex = chapterFirstPage[_normalizeEpubHref(chapter.href)];
      if (pageIndex == null) {
        continue;
      }
      tocEntries.add(
        _TocEntry(
          title: chapter.title.trim().isEmpty
              ? _text(zh: '第${index + 1}章', en: 'Chapter ${index + 1}')
              : chapter.title,
          pageIndex: pageIndex,
        ),
      );
    }
    return tocEntries;
  }

  String _normalizeEpubHref(String href) => href.split('#').first;

  ReaderLocator? _locatorForEpubPage(
    int pageIndex, {
    List<_EpubPageEntry>? pages,
  }) {
    final sourcePages = pages ?? _epubPages;
    if (sourcePages.isEmpty ||
        pageIndex < 0 ||
        pageIndex >= sourcePages.length) {
      return null;
    }
    return LocatorMapper.locatorForPageStart(sourcePages[pageIndex].layout);
  }

  List<_TocEntry> _buildTocEntries(Book book) {
    if (_isTxtBook(book) && _txtChapters.isNotEmpty) {
      return _buildTocFromChapters();
    }

    if (_isTxtBook(book) && _txtToc.isNotEmpty) {
      return _txtToc;
    }

    if (!_isTxtBook(book) && _epubToc.isNotEmpty) {
      return _epubToc;
    }

    final total = _resolveTotalPages(book);
    return List<_TocEntry>.generate(
      total,
      (index) => _TocEntry(
        title: LocaleText.of(
          context,
          zh: '第${index + 1}页',
          en: 'Page ${index + 1}',
        ),
        pageIndex: index,
      ),
    );
  }

  int _resolveTotalPages(Book book) {
    if (_isTxtBook(book)) {
      return max(1, _txtPages.length);
    }
    if (_epubPages.isNotEmpty) {
      return _epubPages.length;
    }
    return book.totalPages ?? _fallbackPages;
  }

  bool _isTxtBook(Book book) => book.epubPath.toLowerCase().endsWith('.txt');

  List<_TocEntry> _buildTocFromChapters() {
    if (_txtChapters.isEmpty) {
      return const [];
    }
    return _buildTocFromChaptersForLocation(_currentTxtLocation?.chapterIndex);
  }

  List<_TocEntry> _buildTocFromChaptersForLocation(int? currentChapterIndex) {
    if (_txtChapters.isEmpty) {
      return const [];
    }
    final toc = _txtChapters
        .asMap()
        .entries
        .map(
          (entry) => _TocEntry(
            title: entry.value.title,
            pageIndex: entry.key,
            chapterIndex: entry.value.index,
          ),
        )
        .toList();
    if (currentChapterIndex != null &&
        !toc.any((entry) => entry.chapterIndex == currentChapterIndex)) {
      toc.insert(
        0,
        _TocEntry(
          title:
              _txtChapterByIndex[currentChapterIndex]?.title ??
              _text(zh: '当前位置', en: 'Current Position'),
          pageIndex: 0,
          chapterIndex: currentChapterIndex,
        ),
      );
    }
    return toc;
  }

  List<_TxtPage> _paginateChapterPages(_TxtChapter chapter) {
    final text = chapter.content;
    if (text.isEmpty) {
      return [
        _TxtPage(
          title: chapter.title,
          chapterIndex: chapter.index,
          startOffset: 0,
          endOffset: 0,
        ),
      ];
    }

    final width = _contentMaxWidth;
    final height = _contentMaxHeight;
    final style = _paginationTextStyle();
    final pages = <_TxtPage>[];
    var start = 0;
    while (start < text.length) {
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
      if (end <= start) {
        break;
      }
      start = end;
    }
    if (pages.isEmpty) {
      pages.add(
        _TxtPage(
          title: chapter.title,
          chapterIndex: chapter.index,
          startOffset: 0,
          endOffset: min(1, text.length),
        ),
      );
    }
    return pages;
  }

  List<_TxtPage> _buildTxtPageWindowForLocation({
    required _TxtLocation location,
    List<_TxtChapter>? chapters,
    Map<int, _TxtChapter>? chapterByIndex,
  }) {
    final sourceChapters = chapters ?? _txtChapters;
    final sourceChapterByIndex = chapterByIndex ?? _txtChapterByIndex;
    if (sourceChapters.isEmpty || sourceChapterByIndex.isEmpty) {
      return const [];
    }

    final currentPos = sourceChapters.indexWhere(
      (chapter) => chapter.index == location.chapterIndex,
    );
    if (currentPos < 0) {
      return const [];
    }

    final pages = <_TxtPage>[];
    final startPos = max(0, currentPos - 1);
    final endPos = min(sourceChapters.length - 1, currentPos + 1);
    for (var pos = startPos; pos <= endPos; pos++) {
      pages.addAll(_paginateChapterPages(sourceChapters[pos]));
    }
    return pages;
  }

  void _ensureTxtPageStreamAround(int page) {
    if (_txtPages.isEmpty ||
        _txtChapters.isEmpty ||
        _isAdjustingTxtPageStream) {
      return;
    }
    if (page <= 1) {
      final firstChapterIndex = _txtPages.first.chapterIndex;
      final previousChapterIndex = _previousTxtChapterIndex(firstChapterIndex);
      if (previousChapterIndex != null &&
          previousChapterIndex != firstChapterIndex &&
          !_txtPages.any((item) => item.chapterIndex == previousChapterIndex)) {
        _prependTxtChapter(previousChapterIndex);
      }
    }
    if (page >= _txtPages.length - 2) {
      final lastChapterIndex = _txtPages.last.chapterIndex;
      final nextChapterIndex = _nextTxtChapterIndex(lastChapterIndex);
      if (nextChapterIndex != null &&
          nextChapterIndex != lastChapterIndex &&
          !_txtPages.any((item) => item.chapterIndex == nextChapterIndex)) {
        _appendTxtChapter(nextChapterIndex);
      }
    }
  }

  void _appendTxtChapter(int chapterIndex) {
    final chapter = _txtChapterByIndex[chapterIndex];
    if (chapter == null) {
      return;
    }
    final additionalPages = _paginateChapterPages(chapter);
    if (additionalPages.isEmpty) {
      return;
    }
    setState(() {
      _txtPages = List<_TxtPage>.unmodifiable(<_TxtPage>[
        ..._txtPages,
        ...additionalPages,
      ]);
    });
  }

  void _prependTxtChapter(int chapterIndex) {
    final chapter = _txtChapterByIndex[chapterIndex];
    if (chapter == null) {
      return;
    }
    final additionalPages = _paginateChapterPages(chapter);
    if (additionalPages.isEmpty) {
      return;
    }
    final shiftedPage = _currentPage + additionalPages.length;
    _isAdjustingTxtPageStream = true;
    setState(() {
      _txtPages = List<_TxtPage>.unmodifiable(<_TxtPage>[
        ...additionalPages,
        ..._txtPages,
      ]);
      _currentPage = shiftedPage;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_pageController.hasClients) {
        _pageController.jumpToPage(shiftedPage);
      }
      _isAdjustingTxtPageStream = false;
    });
  }

  void _loadTxtChapterAtLocation(
    _TxtLocation location, {
    bool resetController = true,
    bool jumpToLastPage = false,
  }) {
    if (_txtChapters.isEmpty || _txtChapterByIndex.isEmpty) {
      return;
    }
    final chapter = _txtChapterByIndex[location.chapterIndex];
    if (chapter == null) {
      return;
    }
    final pages = _buildTxtPageWindowForLocation(location: location);
    if (pages.isEmpty) {
      return;
    }
    final targetPage = jumpToLastPage
        ? max(
            0,
            pages.lastIndexWhere(
              (page) => page.chapterIndex == location.chapterIndex,
            ),
          )
        : _resolvePageFromLocation(
            'txt:${location.chapterIndex}:${location.offset}',
            pages,
          );
    final targetTxtPage = pages[targetPage];
    final resolvedLocation = _TxtLocation(
      chapterIndex: targetTxtPage.chapterIndex,
      offset: targetTxtPage.startOffset,
    );

    if (resetController) {
      _replacePageController(targetPage);
    }

    setState(() {
      _txtPages = List<_TxtPage>.unmodifiable(pages);
      _txtToc = _buildTocFromChaptersForLocation(chapter.index);
      _currentTxtLocation = resolvedLocation;
      _currentPage = targetPage;
    });

    if (resetController) {
      _restorePageAfterBuild(targetPage);
    }
  }

  void _scheduleRepaginate({bool immediate = false}) {
    _repaginateDebounce?.cancel();
    _repaginateDebounce = Timer(
      Duration(milliseconds: immediate ? 0 : 120),
      () async {
        if (!mounted) {
          return;
        }
        final currentBook =
            ref.read(bookByIdProvider(widget.bookId)).valueOrNull ??
            widget.initialBook;
        if (currentBook == null) {
          return;
        }
        if (_isTxtBook(currentBook)) {
          if (_txtChapters.isEmpty || _currentTxtLocation == null) {
            return;
          }
          _repaginateVisibleTxtPages();
          return;
        }
        final preferredLocation = _currentEpubLocator == null
            ? null
            : 'epub:${_currentEpubLocator!.encode()}';
        _loadedEpubPath = null;
        _epubLoadScheduled = false;
        await _loadEpubBook(currentBook, preferredLocation: preferredLocation);
      },
    );
  }

  void _repaginateVisibleTxtPages() {
    final location = _currentTxtLocation;
    if (location == null ||
        _txtChapters.isEmpty ||
        _txtChapterByIndex.isEmpty) {
      return;
    }
    final pages = _buildTxtPageWindowForLocation(location: location);
    if (pages.isEmpty) {
      return;
    }
    final restoredPage = _resolvePageFromLocation(
      'txt:${location.chapterIndex}:${location.offset}',
      pages,
    );
    final currentChapter = _txtChapterByIndex[location.chapterIndex];
    if (currentChapter == null) {
      return;
    }
    _replacePageController(restoredPage);
    setState(() {
      _txtPages = List<_TxtPage>.unmodifiable(pages);
      _txtToc = _buildTocFromChaptersForLocation(currentChapter.index);
      _currentPage = restoredPage;
      _currentTxtLocation = location;
    });
    _restorePageAfterBuild(restoredPage);
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
    required bool startsAtParagraphBoundary,
    bool useWidgetIndent = true,
    int? highlightStart,
    int? highlightEnd,
  }) {
    return _buildParagraphSpans(
      text,
      bodyStyle,
      startsAtParagraphBoundary: startsAtParagraphBoundary,
      useWidgetIndent: useWidgetIndent,
      highlightStart: highlightStart,
      highlightEnd: highlightEnd,
    );
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

    bool fits(int candidateEnd) {
      final showChapterHeader = start == 0;
      final safeHeight = max(
        48.0,
        height -
            _paginationSafetyInset -
            (showChapterHeader ? _chapterHeaderBlockHeight : 0.0),
      );
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

  double get _currentProgressPercent {
    if (_currentTxtLocation != null && _txtTotalLength > 0) {
      return (_globalOffsetForLocation(_currentTxtLocation!) / _txtTotalLength)
          .clamp(0.0, 1.0);
    }
    if (_epubPages.isNotEmpty) {
      if (_epubPages.length == 1) {
        return 1.0;
      }
      return (_currentPage / (_epubPages.length - 1)).clamp(0.0, 1.0);
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

    _loadTxtChapterAtLocation(
      _TxtLocation(
        chapterIndex: targetChapterIndex,
        offset: targetOffsetInChapter,
      ),
    );
  }

  void _jumpToTxtChapter(int chapterIndex) {
    if (_txtChapters.isEmpty || _txtChapterByIndex.isEmpty) {
      return;
    }
    _loadTxtChapterAtLocation(
      _TxtLocation(chapterIndex: chapterIndex, offset: 0),
    );
  }

  void _scheduleSaveTxtProgress(Book book) {
    _progressSaveDebounce?.cancel();
    _progressSaveDebounce = Timer(const Duration(milliseconds: 220), () {
      _persistTxtProgress(book);
    });
  }

  void _scheduleSaveCurrentBookProgress(Book book) {
    _progressSaveDebounce?.cancel();
    _progressSaveDebounce = Timer(const Duration(milliseconds: 220), () {
      _persistCurrentBookProgress(book);
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
    final locator = _locatorForEpubPage(safePage);
    final progress = ReadingProgress(
      bookId: book.id,
      location: locator == null ? 'page:$safePage' : 'epub:${locator.encode()}',
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
    final currentLocation = _currentTxtLocation;
    final location = currentLocation == null
        ? 'txt:0:0'
        : 'txt:${currentLocation.chapterIndex}:${currentLocation.offset}';
    final globalOffset = currentLocation == null
        ? 0
        : _globalOffsetForLocation(currentLocation);
    final percent = currentLocation == null || _txtTotalLength <= 0
        ? 0.0
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

  int _globalOffsetForLocation(_TxtLocation location) {
    final chapterStart = _txtChapterGlobalStart[location.chapterIndex] ?? 0;
    return chapterStart + location.offset;
  }

  // ignore: unused_element
  _TxtLocation _resolveTxtLocation(String? location) {
    if (_txtChapters.isEmpty) {
      return const _TxtLocation(chapterIndex: 0, offset: 0);
    }
    return _resolveTxtLocationFromData(
      chapters: _txtChapters,
      chapterByIndex: _txtChapterByIndex,
      location: location,
    );
  }

  _TxtLocation _resolveTxtLocationFromData({
    required List<_TxtChapter> chapters,
    required Map<int, _TxtChapter> chapterByIndex,
    required String? location,
  }) {
    if (chapters.isEmpty) {
      return const _TxtLocation(chapterIndex: 0, offset: 0);
    }
    var chapterIndex = chapters.first.index;
    var offset = 0;
    if (location != null && location.startsWith('txt:')) {
      final parts = location.split(':');
      if (parts.length >= 3) {
        chapterIndex = int.tryParse(parts[1]) ?? chapterIndex;
        offset = int.tryParse(parts[2]) ?? 0;
      }
    }
    final chapter = chapterByIndex[chapterIndex] ?? chapters.first;
    return _TxtLocation(
      chapterIndex: chapter.index,
      offset: offset.clamp(0, chapter.content.length),
    );
  }

  void _turnTxtPage({required bool forward, Book? book}) {
    if (_txtPages.isEmpty || _currentTxtLocation == null) {
      return;
    }
    if (forward && _currentPage >= _txtPages.length - 2) {
      final nextChapterIndex = _nextTxtChapterIndex(
        _txtPages.last.chapterIndex,
      );
      if (nextChapterIndex != null &&
          !_txtPages.any((item) => item.chapterIndex == nextChapterIndex)) {
        _appendTxtChapter(nextChapterIndex);
      }
    }
    if (!forward && _currentPage <= 1) {
      final previousChapterIndex = _previousTxtChapterIndex(
        _txtPages.first.chapterIndex,
      );
      if (previousChapterIndex != null &&
          !_txtPages.any((item) => item.chapterIndex == previousChapterIndex)) {
        _prependTxtChapter(previousChapterIndex);
      }
    }

    final targetPage = forward ? _currentPage + 1 : _currentPage - 1;
    if (targetPage >= 0 && targetPage < _txtPages.length) {
      _jumpToPage(targetPage);
      if (book != null) {
        _scheduleSaveTxtProgress(book);
      }
      return;
    }
  }

  Future<_DecodedTxtContent> _readTxtContentFromResolvedPath(
    String resolvedPath,
  ) async {
    final bytes = await File(resolvedPath).readAsBytes();

    try {
      return _DecodedTxtContent(text: utf8.decode(bytes), encoding: 'utf8');
    } catch (_) {
      final gb18030Text = await CharsetConverter.decode('gb18030', bytes);
      if (_containsReadableCjk(gb18030Text)) {
        return _DecodedTxtContent(text: gb18030Text, encoding: 'gb18030');
      }

      final gbkText = await CharsetConverter.decode('gbk', bytes);
      if (_containsReadableCjk(gbkText)) {
        return _DecodedTxtContent(text: gbkText, encoding: 'gbk');
      }

      final utf8Text = utf8.decode(bytes, allowMalformed: true);
      if (utf8Text.trim().isNotEmpty) {
        return _DecodedTxtContent(text: utf8Text, encoding: 'utf8_malformed');
      }

      final latinText = latin1.decode(bytes, allowInvalid: true);
      if (latinText.trim().isNotEmpty) {
        return _DecodedTxtContent(text: latinText, encoding: 'latin1');
      }

      if (gb18030Text.trim().isNotEmpty) {
        return _DecodedTxtContent(text: gb18030Text, encoding: 'gb18030');
      }
      if (gbkText.trim().isNotEmpty) {
        return _DecodedTxtContent(text: gbkText, encoding: 'gbk');
      }
      return _DecodedTxtContent(text: utf8Text, encoding: 'utf8_malformed');
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
          _contentPadding.vertical -
          _chapterOverlayReservedHeight,
    );
  }

  double get _paginationSafetyInset {
    // Keep only a small guard band now that pagination/rendering models are aligned.
    final byFont = _contentFontSize * 0.24;
    return byFont.clamp(3.0, 8.0);
  }

  Color get _readerBgColor {
    if (_isCustomBackgroundActive) {
      return _isDarkReaderBackground
          ? const Color(0xFF0F1210)
          : const Color(0xFFF6F1E7);
    }
    const palette = [
      Color(0xFFF3F3F3), // 0: 浅色
      Color(0xFFE8E2D6), // 1: 米色
      Color(0xFFF1F4EE), // 2: 薄荷绿
      Color(0xFFA6C39D), // 3: 浅绿
      Color(0xFFF5ECD7), // 4: 羊皮纸
      Color(0xFFE3EBF2), // 5: 雾蓝
      Color(0xFFF5E8EA), // 6: 玫瑰粉
      Color(0xFFFFF8E7), // 7: 奶油黄
      Color(0xFF121212), // 8: 深灰 (经典护眼)
      Color(0xFF1A1B26), // 9: 深靛 (柔和冷调)
      Color(0xFF1C1C1C), // 10: 深咖 (温暖怀旧)
      Color(0xFF1A2A1F), // 11: 墨绿
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

  bool get _isCustomBackgroundActive =>
      _backgroundMode == _ReaderBackgroundMode.customImage &&
      _customBackgroundImagePath != null &&
      _customBackgroundImagePath!.isNotEmpty;

  bool get _isDarkReaderBackground {
    if (_isCustomBackgroundActive) {
      return (_customBackgroundBrightness ?? 0.42) < 0.45;
    }
    // 夜晚模式: themeIndex >= 8 (深灰、深靛、深咖、墨绿)
    return _themeIndex >= 8;
  }

  Color get _textColor {
    if (_isCustomBackgroundActive) {
      return _isDarkReaderBackground
          ? const Color(0xFF94969B)
          : const Color(0xFF1F2A1F);
    }

    // 根据背景色返回匹配的文字色
    switch (_themeIndex) {
      // 白天模式 (浅色背景 + 深色文字)
      case 0: // 浅色 #F3F3F3
      case 1: // 米色 #E8E2D6
      case 2: // 薄荷绿 #F1F4EE
      case 4: // 羊皮纸 #F5ECD7
      case 5: // 雾蓝 #E3EBF2
      case 6: // 玫瑰粉 #F5E8EA
      case 7: // 奶油黄 #FFF8E7
        return const Color(0xFF1F2A1F); // 深绿色文字

      case 3: // 浅绿 #A6C39D
        return const Color(0xFF1A2218); // 更深的绿色文字

      // 夜晚模式 (深色背景 + 低亮度文字)
      case 8: // 深灰 #121212
        return const Color(0xFF7A7A7A);

      case 9: // 深靛 #1A1B26
        return const Color(0xFF6E8090);

      case 10: // 深咖 #1C1C1C
        return const Color(0xFF817564);

      case 11: // 墨绿 #1A2A1F
        return const Color(0xFF94969B);

      default:
        return const Color(0xFF1F2A1F); // 默认深绿色文字
    }
  }

  Color get _readerContentSurfaceColor {
    if (!_isCustomBackgroundActive) {
      return Colors.transparent;
    }
    if (_isDarkReaderBackground) {
      final opacity = (0.18 + _backgroundOverlayOpacity * 0.56).clamp(
        0.18,
        0.54,
      );
      return const Color(0xFF0A0C0A).withOpacity(opacity);
    }
    final opacity = (0.22 + _backgroundOverlayOpacity * 0.5).clamp(0.22, 0.52);
    return const Color(0xFFFFFCF4).withOpacity(opacity);
  }

  Color get _readerReadingVeilColor {
    if (!_isCustomBackgroundActive) {
      return Colors.transparent;
    }
    if (_isDarkReaderBackground) {
      final opacity = (0.08 + _backgroundOverlayOpacity * 0.34).clamp(
        0.08,
        0.28,
      );
      return const Color(0xFF050705).withOpacity(opacity);
    }
    final opacity = (0.06 + _backgroundOverlayOpacity * 0.3).clamp(0.06, 0.24);
    return const Color(0xFFFFFBF2).withOpacity(opacity);
  }

  Color get _readerBackgroundOverlayColor {
    if (!_isCustomBackgroundActive) {
      return Colors.transparent;
    }
    final overlayBase = _isDarkReaderBackground ? Colors.black : Colors.white;
    return overlayBase.withOpacity(_backgroundOverlayOpacity);
  }

  Color get _ttsHighlightColor => _isDarkReaderBackground
      ? const Color(0xFF4C7D5B).withValues(alpha: 0.72)
      : const Color(0xFFBFE7A8).withValues(alpha: 0.9);

  Color get _ttsHighlightTextColor =>
      _isDarkReaderBackground ? _textColor : const Color(0xFF182118);

  Color get _readerSecondaryInfoColor => _isDarkReaderBackground
      ? _textColor.withOpacity(0.72)
      : _textColor.withOpacity(0.48);

  double get _chapterOverlayFontSize =>
      (_contentFontSize * 0.66).clamp(11.0, 15.0);

  double get _chapterOverlayReservedHeight {
    final gap = (_contentFontSize * 0.22).clamp(3.0, 6.0);
    return _chapterOverlayFontSize * 1.1 + gap;
  }

  TextStyle get _chapterHeaderTitleStyle => TextStyle(
    fontSize: (_contentFontSize * 1.52).clamp(24.0, 36.0),
    height: 1.18,
    fontWeight: FontWeight.w700,
    color: _textColor,
    fontFamily: _contentFontFamily,
  );

  double get _chapterHeaderBlockHeight {
    final titleLineHeight =
        _chapterHeaderTitleStyle.fontSize! * _chapterHeaderTitleStyle.height!;
    final titleBottomGap = (_contentFontSize * 0.9).clamp(16.0, 28.0);
    return titleLineHeight + titleBottomGap;
  }

  Widget _buildChapterHeaderTitle(String title) {
    return Text(
      title,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      textScaler: TextScaler.noScaling,
      style: _chapterHeaderTitleStyle,
    );
  }

  BoxFit get _readerBackgroundBoxFit {
    switch (_backgroundImageFit) {
      case _ReaderBackgroundImageFit.contain:
        return BoxFit.contain;
      case _ReaderBackgroundImageFit.fill:
        return BoxFit.fill;
      case _ReaderBackgroundImageFit.cover:
        return BoxFit.cover;
    }
  }

  Widget _buildReaderBackgroundLayer() {
    if (!_isCustomBackgroundActive) {
      return ColoredBox(color: _readerBgColor);
    }

    final imagePath = _customBackgroundImagePath;
    if (imagePath == null || imagePath.isEmpty) {
      return ColoredBox(color: _readerBgColor);
    }

    final image = Image.file(
      File(imagePath),
      fit: _readerBackgroundBoxFit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _backgroundMode == _ReaderBackgroundMode.customImage) {
            _clearCustomBackgroundImage();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _text(
                    zh: '背景图片不可用，已恢复纯色背景',
                    en: 'Background image unavailable. Restored solid background.',
                  ),
                ),
              ),
            );
          }
        });
        return ColoredBox(color: _readerBgColor);
      },
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: _readerBgColor),
        if (_backgroundBlurSigma > 0)
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: _backgroundBlurSigma,
              sigmaY: _backgroundBlurSigma,
            ),
            child: image,
          )
        else
          image,
        if (_backgroundOverlayOpacity > 0)
          ColoredBox(color: _readerBackgroundOverlayColor),
      ],
    );
  }

  Widget _buildFloatingAudiobookButton(Book book, int totalPages) {
    final ttsState = ref.watch(ttsProvider);
    const buttonSize = 54.0;
    final viewPadding = MediaQuery.of(context).viewPadding;
    final bottomOffset = _floatingBottomControlOffset(book);

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
      bottom: viewPadding.bottom + bottomOffset,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        opacity: shouldShow ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !shouldShow,
          child: GestureDetector(
            onTap: () async {
              await _startFloatingPlayback(book: book, totalPages: totalPages);
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
    final latestBook = ref.watch(bookByIdProvider(book.id)).valueOrNull;
    final displayBook = latestBook ?? ttsState.currentBook ?? book;
    const capsuleWidth = 164.0;
    const capsuleHeight = 59.0;
    const coverSize = 49.0;
    const ringSize = 55.0;
    const actionButtonSize = 34.0;
    final launchData = _buildAudiobookLaunchData(displayBook);
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
    // Blue for play/pause, Red for close
    final primaryIconColor = const Color(0xFF2196F3);
    final secondaryIconColor = const Color(0xFFF44336);
    final progressColor = _isDarkReaderBackground
        ? Colors.white.withOpacity(0.82)
        : const Color(0xFFF0F8F2);
    final trackColor = _isDarkReaderBackground
        ? Colors.white.withOpacity(0.14)
        : Colors.white.withOpacity(0.18);
    final chapterProgress = _currentChapterReadingProgress(
      displayBook,
      totalPages,
    );
    final mediaSize = MediaQuery.of(context).size;
    final viewPadding = MediaQuery.of(context).viewPadding;
    final bottomOffset = _floatingBottomControlOffset(book);
    final defaultOffset = Offset(
      16,
      mediaSize.height - viewPadding.bottom - bottomOffset - capsuleHeight,
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
                      _isDarkReaderBackground ? 0.16 : 0.24,
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
                      onTap: () async =>
                          _openAudiobookSheet(displayBook, totalPages),
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
                                    child: BookCoverImage(book: displayBook),
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
                                  book: displayBook,
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
    final playbackOffset = ttsState.currentPlaybackOffset;
    if (chapterLength != null &&
        chapterLength > 0 &&
        playbackOffset != null &&
        (ttsState.isSpeaking || ttsState.isPaused || ttsState.isLoadingAudio)) {
      return (playbackOffset / chapterLength).clamp(0.0, 1.0);
    }

    if (!_isTxtBook(book) || _txtPages.isEmpty) {
      return ((_currentPage + 1) / max(1, totalPages)).clamp(0.0, 1.0);
    }

    final currentPage = _txtPages[_currentPage.clamp(0, _txtPages.length - 1)];
    final chapter = _txtChapterByIndex[currentPage.chapterIndex];
    if (chapter == null || chapter.content.isEmpty) {
      return 0.0;
    }
    return (currentPage.endOffset / chapter.content.length).clamp(0.0, 1.0);
  }

  String? _getEpubPageText(Book book) {
    if (_isTxtBook(book) || _epubPages.isEmpty) {
      return null;
    }
    final page = _epubPages[_currentPage.clamp(0, _epubPages.length - 1)];
    final parts = <String>[];
    for (final segment in page.layout.segments) {
      if (segment.blockIndex < 0 ||
          segment.blockIndex >= page.chapter.blocks.length) {
        continue;
      }
      final block = page.chapter.blocks[segment.blockIndex];
      switch (block.type) {
        case BlockNodeType.heading:
        case BlockNodeType.paragraph:
        case BlockNodeType.quote:
          final text = _flattenInlineNodes(block.children);
          final safeStart = segment.startInlineOffset.clamp(0, text.length);
          final safeEnd = segment.endInlineOffset.clamp(safeStart, text.length);
          final sliced = text.substring(safeStart, safeEnd).trim();
          if (sliced.isNotEmpty) {
            parts.add(sliced);
          }
          break;
        case BlockNodeType.separator:
          break;
        case BlockNodeType.image:
          final alt = block.alt?.trim();
          if (alt != null && alt.isNotEmpty) {
            parts.add(alt);
          }
          break;
      }
    }
    final joined = parts.join('\n').trim();
    return joined.isEmpty ? null : joined;
  }

  String _flattenInlineNodes(List<InlineNode> nodes) {
    return nodes.map(_flattenInlineNode).join();
  }

  String _flattenInlineNode(InlineNode node) {
    if (node.type == InlineNodeType.text) {
      return node.text;
    }
    return node.children.map(_flattenInlineNode).join();
  }

  EdgeInsets get mediaQueryPadding => MediaQuery.of(context).padding;

  String _text({required String zh, required String en}) {
    return LocaleText.of(context, zh: zh, en: en);
  }
}
