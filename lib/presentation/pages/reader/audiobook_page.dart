import 'dart:async';
import 'dart:math' as math;
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/models/tts_chapter_payload.dart';
import 'package:myreader/core/providers/book_providers.dart';
import 'package:myreader/core/providers/tts_provider.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/core/utils/locale_text.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/presentation/widgets/bookshelf/book_cover_widget.dart';

class AudiobookPage extends ConsumerStatefulWidget {
  final Book book;
  final String? initialText;
  final int initialPage;
  final int totalPages;
  final String? chapterTitle;
  final String? chapterText;
  final int? chapterIndex;
  final int initialOffset;
  final int lookbackStartOffset;
  final String? nextChapterTitle;
  final String? nextChapterText;
  final int? nextChapterIndex;
  final List<AudiobookChapterPayload> chapterQueue;
  final Color? bgColor;

  const AudiobookPage({
    super.key,
    required this.book,
    this.initialText,
    this.initialPage = 0,
    this.totalPages = 100,
    this.chapterTitle,
    this.chapterText,
    this.chapterIndex,
    this.initialOffset = 0,
    this.lookbackStartOffset = 0,
    this.nextChapterTitle,
    this.nextChapterText,
    this.nextChapterIndex,
    this.chapterQueue = const <AudiobookChapterPayload>[],
    this.bgColor,
  });

  @override
  ConsumerState<AudiobookPage> createState() => _AudiobookPageState();
}

class AudiobookChapterPayload {
  final String title;
  final String text;
  final int index;

  const AudiobookChapterPayload({
    required this.title,
    required this.text,
    required this.index,
  });
}

class _PlaybackSlice {
  final int startOffset;
  final String text;

  const _PlaybackSlice({required this.startOffset, required this.text});
}

class _AudiobookPageState extends ConsumerState<AudiobookPage>
    with SingleTickerProviderStateMixin {
  late final Color _bgStart;
  late final Color _bgEnd;
  late final Color _textPrimary;
  late final Color _textSecondary;
  late final Color _textTertiary;
  late final Color _controlBgColor;
  late final Color _accentGreen;
  late final Color _accentGreenSoft;

  void _initColors() {
    final theme = ref.read(currentThemeProvider);
    _bgStart = theme.scaffoldBackgroundColor;
    _bgEnd = theme.scaffoldBackgroundColor;
    _textPrimary = theme.textColor;
    _textSecondary = theme.secondaryTextColor;
    _textTertiary = theme.secondaryTextColor.withOpacity(0.6);
    _controlBgColor = theme.cardBackgroundColor;
    _accentGreen = theme.primaryColor;
    _accentGreenSoft = theme.primaryColor.withOpacity(0.16);
  }

  Timer? _progressTimer;
  late final AnimationController _discController;
  bool _isDiscSpinning = false;
  bool _isDraggingProgress = false;
  ProviderSubscription<TtsAppState>? _ttsStateSubscription;
  int _currentPage = 0;
  int? _pageBeforeDrag;
  int? _offsetBeforeDrag;
  int _currentOffset = 0;
  int _playbackStartOffset = 0;
  double _estimatedPlaybackProgress = 0.0;
  double _lastActivePlaybackProgress = 0.0;
  int _lastActiveChapterOffset = 0;
  bool _suppressAutoAdvanceOnce = false;
  bool _autoAdvanceTriggered = false;
  bool _nextChapterPreloadTriggered = false;
  List<AudiobookChapterPayload> _chapterQueue =
      const <AudiobookChapterPayload>[];
  int _chapterQueuePos = -1;
  String? _activeChapterTitle;
  String? _activeChapterText;
  int? _activeChapterIndex;
  int _activeLookbackStartOffset = 0;

  bool get _isChapterMode =>
      _activeChapterIndex != null &&
      _activeChapterText != null &&
      _activeChapterText!.trim().isNotEmpty;

  String get _chapterText => _activeChapterText ?? '';
  int get _safeChapterLength => math.max(1, _chapterText.length);
  int get _safeTotalPages => widget.totalPages <= 0 ? 1 : widget.totalPages;
  int get _maxPageIndex => _safeTotalPages - 1;
  int get _safeLookbackStartOffset =>
      _activeLookbackStartOffset.clamp(0, _safeChapterLength - 1);
  bool get _hasNextChapter =>
      _chapterQueuePos >= 0 && _chapterQueuePos + 1 < _chapterQueue.length;
  bool get _hasPreviousChapter => _chapterQueuePos > 0;

  @override
  void initState() {
    super.initState();
    _initColors();
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    _initializeChapterQueue();
    _currentPage = widget.initialPage.clamp(0, _maxPageIndex);
    _currentOffset = widget.initialOffset.clamp(0, _safeChapterLength - 1);
    _playbackStartOffset = _currentOffset;
    _ttsStateSubscription = ref.listenManual<TtsAppState>(ttsProvider, (
      previous,
      next,
    ) {
      _handleTtsStateTransition(previous, next);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(ttsProvider.notifier).setAudiobookUiVisible(true);
      ref.read(ttsProvider.notifier).setUiHandlesChapterAdvance(true);
      await ref
          .read(ttsProvider.notifier)
          .selectVoiceForBook(widget.book, sampleText: _initialPlaybackText());
      final currentTtsState = ref.read(ttsProvider);
      final isCurrentBookSession =
          currentTtsState.currentBook?.id == widget.book.id &&
          (currentTtsState.isSpeaking ||
              currentTtsState.isPaused ||
              currentTtsState.isLoadingAudio);
      if (isCurrentBookSession) {
        if (currentTtsState.isSpeaking) {
          _startProgressTracking();
        }
        return;
      }
      final launchText = _initialPlaybackText();
      if (launchText == null || launchText.trim().isEmpty) {
        return;
      }
      if (_isChapterMode) {
        await _startSpeakingFromOffset(_currentOffset);
        return;
      }
      await _startSpeaking(launchText);
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _ttsStateSubscription?.close();
    _discController.dispose();
    ref.read(ttsProvider.notifier).setAudiobookUiVisible(false);
    ref.read(ttsProvider.notifier).setUiHandlesChapterAdvance(false);
    super.dispose();
  }

  String? _initialPlaybackText() {
    if (_isChapterMode) {
      return _playbackSliceFromOffset(_currentOffset).text;
    }
    return widget.initialText;
  }

  _PlaybackSlice _playbackSliceFromOffset(int offset) {
    if (!_isChapterMode) {
      return _PlaybackSlice(
        startOffset: 0,
        text: (widget.initialText ?? '').trim(),
      );
    }
    final safeOffset = offset.clamp(0, _safeChapterLength - 1);
    final playbackStart = _sentenceStartOffset(safeOffset);
    return _PlaybackSlice(
      startOffset: playbackStart,
      text: _chapterText.substring(playbackStart).trim(),
    );
  }

  int _sentenceStartOffset(int offset) {
    if (!_isChapterMode || offset <= 0) {
      return offset.clamp(0, _safeChapterLength - 1);
    }

    final safeOffset = offset.clamp(0, _safeChapterLength - 1);
    final minOffset = math.min(_safeLookbackStartOffset, safeOffset);
    for (var i = safeOffset - 1; i >= minOffset; i--) {
      final char = _chapterText[i];
      if (_isPauseBoundaryChar(char) || char == '\n' || char == '\r') {
        var candidate = i + 1;
        while (candidate < safeOffset &&
            _chapterText[candidate].trim().isEmpty) {
          candidate++;
        }
        return candidate.clamp(0, safeOffset);
      }
    }

    return minOffset;
  }

  bool _isPauseBoundaryChar(String char) {
    const boundaries = <String>[
      '。',
      '！',
      '？',
      '.',
      '!',
      '?',
      '；',
      ';',
      '…',
      '，',
      ',',
      '、',
      ':',
      '：',
    ];
    return boundaries.contains(char);
  }

  Future<void> _startSpeaking(String text, {int? actualStartOffset}) async {
    if (text.trim().isEmpty) {
      _showToast(_text(zh: '当前没有可播放内容', en: 'No playable content'));
      return;
    }
    try {
      _progressTimer?.cancel();
      final resolvedStartOffset = actualStartOffset ?? _currentOffset;
      setState(() {
        _playbackStartOffset = resolvedStartOffset;
        _currentOffset = resolvedStartOffset;
        _estimatedPlaybackProgress = 0.0;
        _lastActivePlaybackProgress = 0.0;
        _lastActiveChapterOffset = _playbackStartOffset;
      });
      await ref
          .read(ttsProvider.notifier)
          .speak(
            text,
            book: widget.book,
            chapterTitle: _activeChapterTitle,
            startOffset: resolvedStartOffset,
            chapterIndex: _activeChapterIndex,
            chapterLength: _isChapterMode ? _safeChapterLength : null,
            chapterQueue: _ttsChapterQueue(),
          );
      _startProgressTracking();
    } catch (_) {
      _showToast(_text(zh: '播放失败，请重试', en: 'Playback failed, please retry'));
    }
  }

  List<TtsChapterPayload> _ttsChapterQueue() {
    if (widget.chapterQueue.isEmpty) {
      return const <TtsChapterPayload>[];
    }
    return widget.chapterQueue
        .map(
          (item) => TtsChapterPayload(
            title: item.title,
            text: item.text,
            index: item.index,
          ),
        )
        .toList(growable: false);
  }

  Future<void> _startSpeakingFromOffset(int offset) async {
    final slice = _playbackSliceFromOffset(offset);
    if (slice.text.trim().isEmpty) {
      _showToast(_text(zh: '当前没有可播放内容', en: 'No playable content'));
      return;
    }
    setState(() {
      _currentOffset = slice.startOffset;
    });
    await _startSpeaking(slice.text, actualStartOffset: slice.startOffset);
  }

  Future<void> _restartFromCurrentPosition() async {
    _suppressAutoAdvanceOnce = true;
    await ref.read(ttsProvider.notifier).stop();
    await _startSpeakingFromOffset(_currentOffset);
  }

  void _startProgressTracking() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final state = ref.read(ttsProvider);
      if (!state.isSpeaking && !state.isPaused) {
        timer.cancel();
        return;
      }
      if (state.isSpeaking) {
        setState(() {
          // Service-side progress already includes actual player position and
          // fallback estimation. Keep a single source of truth to avoid
          // double-advancing UI progress.
          _estimatedPlaybackProgress = state.playbackProgress.clamp(0.0, 1.0);
        });
        _maybePreloadNextChapter(state);
      }
    });
  }

  Future<void> _togglePlayback(TtsAppState ttsState) async {
    _uiLog(
      'togglePlayback: '
      'isSpeaking=${ttsState.isSpeaking}, '
      'isPaused=${ttsState.isPaused}, '
      'isLoadingAudio=${ttsState.isLoadingAudio}, '
      'currentOffset=$_currentOffset, '
      'playbackProgress=${ttsState.playbackProgress}',
    );
    if (ttsState.isPaused) {
      _uiLog('togglePlayback -> resume');
      await ref.read(ttsProvider.notifier).resume();
      _startProgressTracking();
      return;
    }

    if (ttsState.isSpeaking) {
      _uiLog('togglePlayback -> pause');
      await ref.read(ttsProvider.notifier).pause();
      _progressTimer?.cancel();
      return;
    }

    _uiLog('togglePlayback -> startSpeakingFromOffset');
    await _startSpeakingFromOffset(_currentOffset);
  }

  void _stopSpeaking() {
    _suppressAutoAdvanceOnce = true;
    ref.read(ttsProvider.notifier).stop();
    _progressTimer?.cancel();
    _estimatedPlaybackProgress = 0.0;
  }

  Future<void> _seekChapterOffset(
    int targetOffset, {
    bool force = false,
  }) async {
    if (!_isChapterMode) {
      return;
    }
    final safeOffset = targetOffset.clamp(0, _safeChapterLength - 1);
    final playbackSlice = _playbackSliceFromOffset(safeOffset);
    final resolvedOffset = playbackSlice.startOffset;
    if (!force && resolvedOffset == _currentOffset) {
      return;
    }

    final ttsState = ref.read(ttsProvider);
    final shouldContinue = ttsState.isSpeaking || ttsState.isPaused;
    setState(() {
      _currentOffset = resolvedOffset;
      _playbackStartOffset = resolvedOffset;
      _estimatedPlaybackProgress = 0.0;
    });

    if (shouldContinue) {
      await _restartFromCurrentPosition();
    }
  }

  Future<void> _applySpeechRate(double value) async {
    final safeValue = value.clamp(0.5, 2.0);
    await ref.read(ttsProvider.notifier).setSpeechRate(safeValue);
  }

  Future<void> _applySpeechRateWithRestart(double value) async {
    final ttsState = ref.read(ttsProvider);
    await _applySpeechRate(value);
    if (ttsState.isSpeaking || ttsState.isPaused) {
      await _restartFromCurrentPosition();
    }
  }

  void _onPageSliderChangeStart(double value) {
    _pageBeforeDrag = _currentPage;
    _isDraggingProgress = true;
  }

  void _goToPreviousPage() {
    if (_currentPage <= 0) {
      return;
    }
    setState(() {
      _currentPage--;
    });
    _stopSpeaking();
    Navigator.pop(context, {'action': 'prev_page', 'page': _currentPage});
  }

  void _goToNextPage() {
    if (_currentPage >= _maxPageIndex) {
      return;
    }
    setState(() {
      _currentPage++;
    });
    _stopSpeaking();
    Navigator.pop(context, {'action': 'next_page', 'page': _currentPage});
  }

  void _onPageSliderChangeEnd(double value) {
    final page = value.round().clamp(0, _maxPageIndex);
    _isDraggingProgress = false;
    if (_pageBeforeDrag != null && _pageBeforeDrag == page) {
      _pageBeforeDrag = null;
      return;
    }
    _stopSpeaking();
    Navigator.pop(context, {'action': 'goto_page', 'page': page});
  }

  void _onChapterSliderChangeStart(double value) {
    _offsetBeforeDrag = _currentOffset;
    _isDraggingProgress = true;
  }

  void _onChapterSliderChangeEnd(double value) {
    final nextOffset = value.round().clamp(0, _safeChapterLength - 1);
    final before = _offsetBeforeDrag;
    _offsetBeforeDrag = null;
    _isDraggingProgress = false;
    if (before != null && before == nextOffset) {
      return;
    }
    _seekChapterOffset(nextOffset, force: true);
  }

  void _updateProgressValue(double value) {
    setState(() {
      if (_isChapterMode) {
        _currentOffset = value.round().clamp(0, _safeChapterLength - 1);
        _estimatedPlaybackProgress = 0.0;
      } else {
        _currentPage = value.round().clamp(0, _maxPageIndex);
        _estimatedPlaybackProgress = 0.0;
      }
    });
  }

  void _updateProgressFromLocalDx(
    double localDx,
    double width,
    double sliderMin,
    double sliderMax,
  ) {
    if (width <= 0) {
      return;
    }
    final ratio = (localDx / width).clamp(0.0, 1.0);
    final value = sliderMin + (sliderMax - sliderMin) * ratio;
    _updateProgressValue(value);
  }

  void _closeWithSync() {
    final ttsState = ref.read(ttsProvider);
    _suppressAutoAdvanceOnce = true;
    if (_isChapterMode && widget.chapterIndex != null) {
      Navigator.pop(context, {
        'action': 'goto_txt_location',
        'chapterIndex': widget.chapterIndex,
        'offset': _effectiveChapterOffset(ttsState),
      });
      return;
    }
    Navigator.pop(context, {'action': 'goto_page', 'page': _currentPage});
  }

  void _showToast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  double _safeSpeechRate(double speechRate) {
    return speechRate.clamp(0.5, 2.0);
  }

  String _displayTitle() {
    final chapter = (_activeChapterTitle ?? widget.chapterTitle ?? '').trim();
    if (chapter.isNotEmpty) {
      return chapter;
    }
    return LocaleText.of(
      context,
      zh: '第 ${_currentPage + 1} 页',
      en: 'Page ${_currentPage + 1}',
    );
  }

  void _uiLog(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final formatted = '[$timestamp] [AudiobookPage] $message';
    debugPrint(formatted);
    developer.log(formatted, name: 'AudiobookPage');
  }

  void _maybePreloadNextChapter(TtsAppState ttsState) {
    if (!_isChapterMode || !_hasNextChapter || _nextChapterPreloadTriggered) {
      return;
    }
    final progress = ttsState.playbackProgress > 0
        ? ttsState.playbackProgress
        : _estimatedPlaybackProgress;
    if (progress < 0.82) {
      return;
    }
    _nextChapterPreloadTriggered = true;
    final nextChapter = _chapterQueue[_chapterQueuePos + 1];
    _uiLog(
      'preloading next chapter: '
      'nextChapterIndex=${nextChapter.index}, progress=$progress',
    );
    unawaited(
      ref.read(ttsProvider.notifier).preloadUpcomingText(nextChapter.text),
    );
  }

  void _handleTtsStateTransition(TtsAppState? previous, TtsAppState next) {
    _uiLog(
      'tts transition: '
      'prevSpeaking=${previous?.isSpeaking}, '
      'prevPaused=${previous?.isPaused}, '
      'prevProgress=${previous?.playbackProgress}, '
      'nextSpeaking=${next.isSpeaking}, '
      'nextPaused=${next.isPaused}, '
      'nextProgress=${next.playbackProgress}',
    );
    if (!_isChapterMode || _activeChapterIndex == null || !mounted) {
      return;
    }
    final isActiveNow = next.isSpeaking || next.isPaused;
    if (isActiveNow) {
      final activeOffset = _effectiveChapterOffset(next);
      if (next.playbackProgress > 0) {
        _lastActivePlaybackProgress = next.playbackProgress;
      }
      if (activeOffset > _lastActiveChapterOffset) {
        _lastActiveChapterOffset = activeOffset;
      }
    }
    final wasActive =
        previous?.isSpeaking == true || previous?.isPaused == true;
    final isStoppedNow = !next.isSpeaking && !next.isPaused;
    if (!wasActive || !isStoppedNow) {
      return;
    }
    if (_suppressAutoAdvanceOnce) {
      _suppressAutoAdvanceOnce = false;
      _uiLog('auto advance suppressed for manual stop');
      return;
    }
    if (_autoAdvanceTriggered) {
      return;
    }

    final previousProgress = math.max(
      previous?.playbackProgress ?? 0.0,
      _lastActivePlaybackProgress,
    );
    final previousOffset = math.max(
      previous != null ? _effectiveChapterOffset(previous) : 0,
      _lastActiveChapterOffset,
    );
    final reachedEnd =
        previousProgress >= 0.98 || previousOffset >= _safeChapterLength - 1;
    _uiLog(
      'tts stopped: previousProgress=$previousProgress, '
      'previousOffset=$previousOffset, reachedEnd=$reachedEnd',
    );
    if (!reachedEnd) {
      return;
    }

    if (_advanceToNextChapterInPlace()) {
      return;
    }

    _autoAdvanceTriggered = true;
    Navigator.pop(context, {
      'action': 'auto_next_txt_chapter',
      'chapterIndex': _activeChapterIndex,
    });
  }

  void _initializeChapterQueue() {
    if (widget.chapterQueue.isNotEmpty) {
      _chapterQueue = List<AudiobookChapterPayload>.from(widget.chapterQueue);
      _chapterQueuePos = _chapterQueue.indexWhere(
        (chapter) => chapter.index == widget.chapterIndex,
      );
    }

    if (_chapterQueuePos >= 0) {
      final current = _chapterQueue[_chapterQueuePos];
      _activeChapterTitle = current.title;
      _activeChapterText = current.text;
      _activeChapterIndex = current.index;
      _activeLookbackStartOffset = widget.lookbackStartOffset;
      return;
    }

    _activeChapterTitle = widget.chapterTitle;
    _activeChapterText = widget.chapterText;
    _activeChapterIndex = widget.chapterIndex;
    _activeLookbackStartOffset = widget.lookbackStartOffset;
  }

  bool _advanceToNextChapterInPlace() {
    if (!_hasNextChapter) {
      return false;
    }
    _uiLog('advancing in place to next chapter');
    return _switchToChapterInPlace(_chapterQueuePos + 1);
  }

  bool _switchToChapterInPlace(int nextQueuePos) {
    if (nextQueuePos < 0 || nextQueuePos >= _chapterQueue.length) {
      return false;
    }
    final nextChapter = _chapterQueue[nextQueuePos];
    _uiLog('switching in place to chapter ${nextChapter.index}');
    _progressTimer?.cancel();
    setState(() {
      _chapterQueuePos = nextQueuePos;
      _activeChapterTitle = nextChapter.title;
      _activeChapterText = nextChapter.text;
      _activeChapterIndex = nextChapter.index;
      _activeLookbackStartOffset = 0;
      _currentOffset = 0;
      _playbackStartOffset = 0;
      _estimatedPlaybackProgress = 0.0;
      _lastActivePlaybackProgress = 0.0;
      _lastActiveChapterOffset = 0;
      _nextChapterPreloadTriggered = false;
      _suppressAutoAdvanceOnce = false;
      _autoAdvanceTriggered = false;
    });
    unawaited(_startSpeakingFromOffset(0));
    return true;
  }

  void _goToPreviousChapter() {
    if (!_hasPreviousChapter) {
      return;
    }
    _switchToChapterInPlace(_chapterQueuePos - 1);
  }

  void _goToNextChapter() {
    if (!_hasNextChapter) {
      return;
    }
    _switchToChapterInPlace(_chapterQueuePos + 1);
  }

  int _estimatedDurationSeconds() {
    if (_isChapterMode) {
      final estimate = (_safeChapterLength / 6).round();
      return estimate.clamp(120, 4 * 60 * 60);
    }
    final estimate = _safeTotalPages * 45;
    return estimate.clamp(90, 3 * 60 * 60);
  }

  String _formatDuration(int seconds) {
    final safe = seconds.clamp(0, 24 * 60 * 60);
    final h = safe ~/ 3600;
    final m = (safe % 3600) ~/ 60;
    final s = safe % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int _effectiveChapterOffset(TtsAppState ttsState) {
    if (!_isChapterMode) {
      return _currentOffset;
    }
    if (_isDraggingProgress) {
      return _currentOffset;
    }
    final absolutePlaybackOffset = ttsState.currentPlaybackOffset;
    if (absolutePlaybackOffset != null &&
        (ttsState.isSpeaking || ttsState.isPaused || ttsState.isLoadingAudio)) {
      return absolutePlaybackOffset.clamp(0, _safeChapterLength - 1);
    }
    final hasLiveProgress =
        (ttsState.isSpeaking || ttsState.isPaused) &&
        ttsState.playbackProgress > 0;
    final progress = hasLiveProgress
        ? ttsState.playbackProgress
        : _estimatedPlaybackProgress;
    if (progress <= 0) {
      return _playbackStartOffset;
    }
    final remainingLength = math.max(
      1,
      _safeChapterLength - _playbackStartOffset,
    );
    final progressedChars = (remainingLength * progress).round();
    return (_playbackStartOffset + progressedChars).clamp(
      0,
      _safeChapterLength - 1,
    );
  }

  double _effectiveSliderValue(TtsAppState ttsState) {
    if (_isChapterMode) {
      return _effectiveChapterOffset(ttsState).toDouble();
    }
    if (_isDraggingProgress) {
      return _currentPage.toDouble();
    }
    final hasLiveProgress =
        (ttsState.isSpeaking || ttsState.isPaused) &&
        ttsState.playbackProgress > 0;
    if (!hasLiveProgress) {
      return _currentPage.toDouble();
    }
    return (_maxPageIndex * ttsState.playbackProgress).clamp(
      0,
      _maxPageIndex.toDouble(),
    );
  }

  Future<void> _showSpeedControlSheet(double currentRate) async {
    var tempRate = currentRate;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _controlBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      LocaleText.of(
                        context,
                        zh: '语速 ${tempRate.toStringAsFixed(2)}x',
                        en: 'Speed ${tempRate.toStringAsFixed(2)}x',
                      ),
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _text(
                        zh: '建议区间 0.9x - 1.3x',
                        en: 'Suggested range 0.9x - 1.3x',
                      ),
                      style: TextStyle(color: _textTertiary, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _accentGreen,
                        inactiveTrackColor: _textTertiary.withValues(
                          alpha: 0.25,
                        ),
                        thumbColor: _accentGreen,
                        overlayColor: _accentGreen.withValues(alpha: 0.16),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                      ),
                      child: Slider(
                        value: tempRate,
                        min: 0.5,
                        max: 2.0,
                        divisions: 15,
                        onChanged: (value) {
                          setSheetState(() {
                            tempRate = value;
                          });
                          _applySpeechRate(value);
                        },
                        onChangeEnd: _applySpeechRateWithRestart,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showVoicePickerSheet(TtsAppState ttsState) async {
    final locale = ref
        .read(ttsProvider.notifier)
        .inferLocaleForBook(widget.book, sampleText: _initialPlaybackText());
    await ref.read(ttsProvider.notifier).loadVoices(locale: locale);

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _controlBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final state = ref.watch(ttsProvider);
        final voices = state.availableVoices;
        final languageCode = Localizations.localeOf(context).languageCode;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      _text(zh: '选择音色', en: 'Choose Voice'),
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: state.isLoadingVoices
                          ? null
                          : () => ref
                                .read(ttsProvider.notifier)
                                .loadVoices(locale: locale),
                      icon: Icon(Icons.refresh, color: _accentGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: state.isLoadingVoices
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : voices.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            _text(
                              zh: '未获取到音色列表，请检查 TTS 服务连接。',
                              en: 'No voices loaded. Please check the TTS service connection.',
                            ),
                            style: TextStyle(color: _textSecondary),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          itemCount: voices.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 1.42,
                              ),
                          itemBuilder: (context, index) {
                            final voice = voices[index];
                            final selected = voice.value == state.selectedVoice;
                            final traits = voice.localizedTraits(languageCode);
                            final name = voice.localizedName(languageCode);

                            return Material(
                              color: selected
                                  ? _accentGreen.withValues(alpha: 0.18)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  final shouldRestart =
                                      state.isSpeaking || state.isPaused;
                                  await ref
                                      .read(ttsProvider.notifier)
                                      .setVoice(
                                        voice.value,
                                        bookId: widget.book.id,
                                      );
                                  if (shouldRestart) {
                                    await _restartFromCurrentPosition();
                                  }
                                  if (!mounted) {
                                    return;
                                  }
                                  Navigator.pop(context);
                                  _showToast(
                                    LocaleText.of(
                                      context,
                                      zh: '已切换为 $name',
                                      en: 'Switched to $name',
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    12,
                                    10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: _textPrimary,
                                                fontSize: 14,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (selected)
                                            Icon(
                                              Icons.check_circle,
                                              color: _accentGreen,
                                              size: 18,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        traits.isNotEmpty
                                            ? traits.join(' / ')
                                            : _text(zh: '默认', en: 'Default'),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _textSecondary,
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isAtStart() {
    if (_isChapterMode) {
      return !_hasPreviousChapter;
    }
    return _currentPage <= 0;
  }

  bool _isAtEnd() {
    if (_isChapterMode) {
      return !_hasNextChapter;
    }
    return _currentPage >= _maxPageIndex;
  }

  @override
  Widget build(BuildContext context) {
    final systemPadding = MediaQueryData.fromView(View.of(context)).padding;
    final topInset = systemPadding.top;
    final bottomInset = systemPadding.bottom;
    final ttsState = ref.watch(ttsProvider);
    final rate = _safeSpeechRate(ttsState.speechRate);
    final title = _displayTitle();
    final canPlay = _isChapterMode
        ? _chapterText.trim().isNotEmpty
        : (ttsState.currentText?.trim().isNotEmpty == true) ||
              (widget.initialText?.trim().isNotEmpty == true);
    _syncDiscAnimation(ttsState);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgStart, _bgEnd],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: topInset + 84, left: -36, child: _ambientGlow(140)),
            Positioned(
              top: topInset + 120,
              right: -28,
              child: _ambientGlow(120),
            ),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  topInset + 6,
                  20,
                  bottomInset + 16,
                ),
                child: Column(
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 24),
                    _buildBookCover(),
                    const SizedBox(height: 36),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    _buildMetaRow(rate, ttsState),
                    const SizedBox(height: 28),
                    _buildProgressSection(ttsState),
                    const SizedBox(height: 30),
                    _buildBottomControls(ttsState, canPlay),
                    if (!canPlay) ...[
                      const SizedBox(height: 12),
                      Text(
                        _text(
                          zh: '当前页没有可播放文本',
                          en: 'No playable text on this page',
                        ),
                        style: TextStyle(color: _textTertiary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _topIconButton(
          icon: Icons.keyboard_arrow_down_rounded,
          tooltip: _text(zh: '收起听书', en: 'Close audiobook'),
          onTap: _closeWithSync,
        ),
        const Spacer(),
        _topIconButton(
          icon: Icons.share_outlined,
          tooltip: _text(zh: '分享', en: 'Share'),
          onTap: () =>
              _showToast(_text(zh: '分享功能即将支持', en: 'Share is coming soon')),
        ),
        const SizedBox(width: 4),
        _topIconButton(
          icon: Icons.more_vert_rounded,
          tooltip: _text(zh: '更多', en: 'More'),
          onTap: () => _showToast(
            _text(zh: '更多功能即将支持', en: 'More actions are coming soon'),
          ),
        ),
      ],
    );
  }

  Widget _topIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            focusColor: _accentGreenSoft,
            splashColor: _accentGreenSoft,
            highlightColor: Colors.transparent,
            child: Icon(icon, size: 26, color: _textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildBookCover() {
    final discSize = (MediaQuery.of(context).size.width * 0.618).clamp(
      176.0,
      300.0,
    );
    final syncedTtsBook = ref.watch(
      ttsProvider.select(
        (state) =>
            state.currentBook?.id == widget.book.id ? state.currentBook : null,
      ),
    );
    final latestBook = ref.watch(bookByIdProvider(widget.book.id)).valueOrNull;
    final displayBook = latestBook ?? syncedTtsBook ?? widget.book;
    final discEdge = const Color(0xFFE7E1D5);
    final discSurface = const Color(0xFFD9D4C6);
    final discShadow = const Color(0xFFB9B09D);
    final ringHighlight = const Color(0xFFF9F5EE);
    final spindleColor = const Color(0xFFFFFBF4);
    final mintReflection = _accentGreen.withValues(alpha: 0.16);
    final mintReflectionSoft = _accentGreen.withValues(alpha: 0.08);

    return SizedBox(
      width: discSize.toDouble(),
      height: discSize.toDouble(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: discSize * 1.08,
            height: discSize * 1.08,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _accentGreenSoft.withValues(alpha: 0.28),
                  _accentGreenSoft.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          RotationTransition(
            turns: _discController,
            child: SizedBox(
              width: discSize,
              height: discSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: discSize,
                    height: discSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.16, -0.2),
                        radius: 1.08,
                        colors: [ringHighlight, discSurface, discShadow],
                        stops: const [0.0, 0.52, 1.0],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: discShadow.withValues(alpha: 0.28),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: discSize * 0.92,
                    height: discSize * 0.92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.38),
                        width: 1,
                      ),
                      gradient: SweepGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.32),
                          mintReflection,
                          Colors.white.withValues(alpha: 0.08),
                          discShadow.withValues(alpha: 0.08),
                          mintReflectionSoft,
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.14, 0.28, 0.52, 0.82, 1.0],
                      ),
                    ),
                  ),
                  for (final factor in [0.98, 0.88, 0.78, 0.68, 0.58])
                    Container(
                      width: discSize * factor,
                      height: discSize * factor,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: factor > 0.9 ? 0.22 : 0.12,
                          ),
                          width: 0.8,
                        ),
                      ),
                    ),
                  Container(
                    width: discSize * 0.72,
                    height: discSize * 0.72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.34),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: mintReflectionSoft,
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: discSize * 0.66,
                    height: discSize * 0.66,
                    padding: EdgeInsets.all(discSize * 0.055),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.14, -0.18),
                        colors: [
                          Colors.white.withValues(alpha: 0.26),
                          mintReflectionSoft,
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: ClipOval(child: BookCoverImage(book: displayBook)),
                  ),
                  Container(
                    width: discSize * 0.12,
                    height: discSize * 0.12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.16, -0.18),
                        colors: [spindleColor, discEdge, discShadow],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.72),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: discShadow.withValues(alpha: 0.24),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: discSize * 0.1,
                    left: discSize * 0.16,
                    child: Container(
                      width: discSize * 0.24,
                      height: discSize * 0.085,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(discSize),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.42),
                            mintReflectionSoft,
                            Colors.white.withValues(alpha: 0.06),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(double rate, TtsAppState ttsState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _metaAction(
          icon: Icons.timer_outlined,
          label: _text(zh: '定时', en: 'Timer'),
          onTap: () => _showToast(
            _text(zh: '定时关闭即将支持', en: 'Sleep timer is coming soon'),
          ),
        ),
        _metaAction(
          icon: Icons.record_voice_over_outlined,
          label: _text(zh: '音色', en: 'Voice'),
          onTap: () => _showVoicePickerSheet(ttsState),
        ),
        _metaAction(
          icon: Icons.speed_rounded,
          label: '${rate.toStringAsFixed(1)}x',
          onTap: () => _showSpeedControlSheet(rate),
        ),
        _metaAction(
          icon: Icons.format_list_bulleted_rounded,
          label: _text(zh: '章节', en: 'Chapters'),
          onTap: () => _showToast(
            _text(zh: '章节列表即将支持', en: 'Chapter list is coming soon'),
          ),
        ),
      ],
    );
  }

  Widget _metaAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 64,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            focusColor: _accentGreenSoft,
            splashColor: _accentGreenSoft,
            highlightColor: Colors.transparent,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 25, color: _textSecondary),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(TtsAppState ttsState) {
    final sliderMin = 0.0;
    final sliderMax = _isChapterMode
        ? (_safeChapterLength - 1).toDouble()
        : _maxPageIndex.toDouble();
    final sliderValue = _effectiveSliderValue(ttsState);
    final totalSeconds = _estimatedDurationSeconds();
    final ratio = sliderMax <= 0
        ? 0.0
        : (sliderValue / sliderMax).clamp(0.0, 1.0);
    final currentSeconds = (totalSeconds * ratio).round();
    final timeLabel =
        '${_formatDuration(currentSeconds)} / ${_formatDuration(totalSeconds)}';

    return Row(
      children: [
        _transportButton(
          icon: Icons.keyboard_double_arrow_left_rounded,
          tooltip: _isChapterMode
              ? _text(zh: '上一章', en: 'Previous chapter')
              : _text(zh: '上一页', en: 'Previous page'),
          onTap: _isChapterMode ? _goToPreviousChapter : _goToPreviousPage,
          enabled: !_isAtStart(),
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              final bubbleWidth = 72.0;
              final effectiveTrackWidth = math.max(
                0.0,
                trackWidth - bubbleWidth,
              );
              final bubbleLeft = (effectiveTrackWidth * ratio)
                  .clamp(0.0, effectiveTrackWidth)
                  .toDouble();
              final progressWidth = bubbleLeft + bubbleWidth;

              return SizedBox(
                height: 32,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    if (_isChapterMode) {
                      _onChapterSliderChangeStart(sliderValue);
                    } else {
                      _onPageSliderChangeStart(sliderValue);
                    }
                    _updateProgressFromLocalDx(
                      details.localPosition.dx,
                      trackWidth,
                      sliderMin,
                      sliderMax,
                    );
                  },
                  onTapUp: (_) {
                    if (_isChapterMode) {
                      _onChapterSliderChangeEnd(_currentOffset.toDouble());
                    } else {
                      _onPageSliderChangeEnd(_currentPage.toDouble());
                    }
                  },
                  onHorizontalDragStart: (_) {
                    if (_isChapterMode) {
                      _onChapterSliderChangeStart(sliderValue);
                    } else {
                      _onPageSliderChangeStart(sliderValue);
                    }
                  },
                  onHorizontalDragUpdate: (details) {
                    _updateProgressFromLocalDx(
                      details.localPosition.dx,
                      trackWidth,
                      sliderMin,
                      sliderMax,
                    );
                  },
                  onHorizontalDragEnd: (_) {
                    if (_isChapterMode) {
                      _onChapterSliderChangeEnd(_currentOffset.toDouble());
                    } else {
                      _onPageSliderChangeEnd(_currentPage.toDouble());
                    }
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 12,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 12,
                        child: Container(
                          height: 4,
                          width: progressWidth.clamp(0.0, trackWidth),
                          decoration: BoxDecoration(
                            color: _accentGreen,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Positioned(
                        left: bubbleLeft,
                        top: 4,
                        child: _progressThumbBubble(timeLabel),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        _transportButton(
          icon: Icons.keyboard_double_arrow_right_rounded,
          tooltip: _isChapterMode
              ? _text(zh: '下一章', en: 'Next chapter')
              : _text(zh: '下一页', en: 'Next page'),
          onTap: _isChapterMode ? _goToNextChapter : _goToNextPage,
          enabled: !_isAtEnd(),
          size: 22,
        ),
      ],
    );
  }

  Widget _progressThumbBubble(String label) {
    return Container(
      width: 72,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _accentGreen.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }

  Widget _transportButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool enabled,
    required double size,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: enabled ? onTap : null,
            splashColor: _accentGreenSoft,
            highlightColor: Colors.transparent,
            focusColor: _accentGreenSoft,
            child: Icon(
              icon,
              size: size,
              color: enabled
                  ? _textSecondary
                  : _textTertiary.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(TtsAppState ttsState, bool canPlay) {
    final isPlaying = ttsState.isSpeaking && !ttsState.isPaused;
    final isLoadingAudio =
        ttsState.isLoadingAudio && !ttsState.isSpeaking && !ttsState.isPaused;
    final canTapPlayback = canPlay && (!isLoadingAudio || ttsState.isPaused);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _transportButton(
          icon: Icons.skip_previous_rounded,
          tooltip: _isChapterMode
              ? _text(zh: '上一章', en: 'Previous chapter')
              : _text(zh: '上一页', en: 'Previous page'),
          onTap: _isChapterMode ? _goToPreviousChapter : _goToPreviousPage,
          enabled: !_isAtStart(),
          size: 34,
        ),
        const SizedBox(width: 30),
        SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  splashColor: _accentGreenSoft,
                  highlightColor: Colors.transparent,
                  onTap: () {
                    _uiLog(
                      'playback button tapped: canPlay=$canPlay, '
                      'isLoadingAudio=$isLoadingAudio, '
                      'isPaused=${ttsState.isPaused}, '
                      'isSpeaking=${ttsState.isSpeaking}, '
                      'canTapPlayback=$canTapPlayback',
                    );
                    if (!canTapPlayback) {
                      _uiLog('playback button blocked');
                      return;
                    }
                    unawaited(_togglePlayback(ttsState));
                  },
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 42,
                    color: _textPrimary,
                  ),
                ),
              ),
              if (isLoadingAudio)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(_accentGreen),
                        backgroundColor: _accentGreen.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 30),
        _transportButton(
          icon: Icons.skip_next_rounded,
          tooltip: _isChapterMode
              ? _text(zh: '下一章', en: 'Next chapter')
              : _text(zh: '下一页', en: 'Next page'),
          onTap: _isChapterMode ? _goToNextChapter : _goToNextPage,
          enabled: !_isAtEnd(),
          size: 34,
        ),
      ],
    );
  }

  String _text({required String zh, required String en}) {
    return LocaleText.of(context, zh: zh, en: en);
  }

  Widget _ambientGlow(double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              _accentGreenSoft.withValues(alpha: 0.18),
              _accentGreenSoft.withValues(alpha: 0.04),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }

  void _syncDiscAnimation(TtsAppState ttsState) {
    final shouldSpin = ttsState.isSpeaking && !ttsState.isPaused;
    if (shouldSpin == _isDiscSpinning) {
      return;
    }
    _isDiscSpinning = shouldSpin;
    if (shouldSpin) {
      _discController.repeat();
    } else {
      _discController.stop();
    }
  }
}
