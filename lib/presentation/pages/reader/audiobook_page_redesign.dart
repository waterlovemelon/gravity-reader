import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/models/tts_chapter_payload.dart';
import 'package:myreader/core/providers/tts_provider.dart';
import 'package:myreader/core/providers/theme_provider.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:myreader/presentation/widgets/bookshelf/book_cover_widget.dart';

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

class AudiobookPageRedesign extends ConsumerStatefulWidget {
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
  final Color? textColor;

  const AudiobookPageRedesign({
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
    this.textColor,
  });

  @override
  ConsumerState<AudiobookPageRedesign> createState() =>
      _AudiobookPageRedesignState();
}

class _PlaybackSlice {
  final int startOffset;
  final String text;

  const _PlaybackSlice({required this.startOffset, required this.text});
}

class _AudiobookPageRedesignState extends ConsumerState<AudiobookPageRedesign>
    with SingleTickerProviderStateMixin {
  late final Color _bgTop;
  late final Color _bgBottom;
  late final Color _textPrimary;
  late final Color _textSecondary;
  late final Color _textTertiary;
  late final Color _controlBgColor;
  late final Color _accentGreen;
  late final Color _accentGreenSoft;
  late final Color _accentGreenStrong;
  late final Color _progressTrackColor;

  Timer? _progressTimer;
  late final AnimationController _discController;
  ProviderSubscription<TtsAppState>? _ttsStateSubscription;
  bool _isDiscSpinning = false;
  bool _isDraggingProgress = false;
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

  void _initColors() {
    final theme = ref.read(currentThemeProvider);
    final readerBg = widget.bgColor ?? theme.readingBackgroundColor;
    _bgTop = readerBg;
    _bgBottom =
        Color.lerp(readerBg, theme.scaffoldBackgroundColor, 0.08) ?? readerBg;
    final readerText = widget.textColor ?? theme.textColor;
    _textPrimary = readerText;
    _textSecondary = readerText;
    _textTertiary = readerText.withValues(alpha: 0.68);
    _controlBgColor = theme.cardBackgroundColor;
    _accentGreen = theme.primaryColor;
    _accentGreenSoft = theme.primaryColor.withValues(alpha: 0.14);
    _accentGreenStrong = theme.primaryDarkColor;
    _progressTrackColor = theme.progressTrackColor;
  }

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
      _showToast('当前没有可播放内容');
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
      _showToast('播放失败，请重试');
    }
  }

  List<TtsChapterPayload> _ttsChapterQueue() {
    if (_chapterQueue.isEmpty) {
      return const <TtsChapterPayload>[];
    }
    return _chapterQueue
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
      _showToast('当前没有可播放内容');
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
          _estimatedPlaybackProgress = state.playbackProgress.clamp(0.0, 1.0);
        });
        _maybePreloadNextChapter(state);
      }
    });
  }

  Future<void> _togglePlayback(TtsAppState ttsState) async {
    if (ttsState.isPaused) {
      await ref.read(ttsProvider.notifier).resume();
      _startProgressTracking();
      return;
    }

    if (ttsState.isSpeaking) {
      await ref.read(ttsProvider.notifier).pause();
      _progressTimer?.cancel();
      return;
    }

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

  Future<void> _seekByChars(int delta) async {
    if (!_isChapterMode) {
      return;
    }
    final target = (_effectiveChapterOffset(ref.read(ttsProvider)) + delta)
        .clamp(0, _safeChapterLength - 1);
    await _seekChapterOffset(target, force: true);
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
    unawaited(_seekChapterOffset(nextOffset, force: true));
  }

  void _closeWithSync() {
    final ttsState = ref.read(ttsProvider);
    _suppressAutoAdvanceOnce = true;
    if (_isChapterMode && _activeChapterIndex != null) {
      Navigator.pop(context, {
        'action': 'goto_txt_location',
        'chapterIndex': _activeChapterIndex,
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
    return '第 ${_currentPage + 1} 页';
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
    unawaited(
      ref.read(ttsProvider.notifier).preloadUpcomingText(nextChapter.text),
    );
  }

  void _handleTtsStateTransition(TtsAppState? previous, TtsAppState next) {
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
    return _switchToChapterInPlace(_chapterQueuePos + 1);
  }

  bool _switchToChapterInPlace(int nextQueuePos) {
    if (nextQueuePos < 0 || nextQueuePos >= _chapterQueue.length) {
      return false;
    }
    final nextChapter = _chapterQueue[nextQueuePos];
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

  bool _isAtStart() {
    if (_isChapterMode) {
      return _effectiveChapterOffset(ref.read(ttsProvider)) <= 0;
    }
    return _currentPage <= 0;
  }

  bool _isAtEnd() {
    if (_isChapterMode) {
      return _effectiveChapterOffset(ref.read(ttsProvider)) >=
          _safeChapterLength - 1;
    }
    return _currentPage >= _maxPageIndex;
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

  String _sleepTimerLabel(Duration? remaining) {
    if (remaining == null || remaining <= Duration.zero) {
      return '定时';
    }
    final totalMinutes = remaining.inMinutes;
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      return minutes == 0 ? '${hours}h' : '${hours}h${minutes}m';
    }
    return '${math.max(1, totalMinutes)}m';
  }

  String _sleepTimerStatusText(Duration? remaining) {
    if (remaining == null || remaining <= Duration.zero) {
      return '';
    }
    final totalMinutes = remaining.inMinutes;
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      return minutes == 0 ? '$hours 小时后停止' : '$hours 小时 $minutes 分后停止';
    }
    return '${math.max(1, totalMinutes)} 分钟后停止';
  }

  String _appLanguageCode() {
    // The app UI is Chinese-only today, so voice metadata should stay aligned
    // with the visible interface rather than the device locale.
    return 'zh';
  }

  Future<void> _showTimerSheet() async {
    const presets = <int>[10, 20, 30, 45, 60];
    final state = ref.read(ttsProvider);
    final activeMinutes = state.sleepTimerRemaining?.inMinutes;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _controlBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSheetHandle(),
                const SizedBox(height: 16),
                Text(
                  '定时关闭',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.sleepTimerRemaining == null
                      ? '选择自动停止播放的时间'
                      : '当前已设置 ${_sleepTimerStatusText(state.sleepTimerRemaining)}',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: presets
                      .map((minutes) {
                        final selected = activeMinutes == minutes;
                        return _buildActionChip(
                          label: '$minutes 分钟',
                          selected: selected,
                          emphasized: minutes == 30 || minutes == 45,
                          onTap: () {
                            ref
                                .read(ttsProvider.notifier)
                                .setSleepTimer(Duration(minutes: minutes));
                            Navigator.pop(context);
                            _showToast('已设置 $minutes 分钟后停止');
                          },
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: state.sleepTimerRemaining == null
                        ? null
                        : () {
                            ref.read(ttsProvider.notifier).clearSleepTimer();
                            Navigator.pop(context);
                            _showToast('已取消定时');
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textPrimary,
                      side: BorderSide(
                        color: _textTertiary.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('关闭定时'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSpeedControlSheet(double currentRate) async {
    const presets = <double>[0.8, 0.9, 1.0, 1.15, 1.25, 1.5];
    var tempRate = currentRate;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _controlBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSheetHandle(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          '语速',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _accentGreenSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${tempRate.toStringAsFixed(2)}x',
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '常用档位前置，滑杆微调。1.0x 和 1.25x 作为重点档位突出。',
                      style: TextStyle(color: _textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: presets
                          .map((value) {
                            final selected = (tempRate - value).abs() < 0.01;
                            final emphasized = value == 1.0 || value == 1.25;
                            return _buildActionChip(
                              label:
                                  '${value.toStringAsFixed(value == 1.0 ? 1 : 2)}x',
                              selected: selected,
                              emphasized: emphasized,
                              onTap: () {
                                setSheetState(() {
                                  tempRate = value;
                                });
                                unawaited(_applySpeechRateWithRestart(value));
                              },
                            );
                          })
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 18),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _textPrimary,
                        inactiveTrackColor: _progressTrackColor,
                        thumbColor: _textPrimary,
                        overlayColor: _textPrimary.withValues(alpha: 0.12),
                        trackHeight: 4,
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
                          unawaited(_applySpeechRate(value));
                        },
                        onChangeEnd: (value) {
                          unawaited(_applySpeechRateWithRestart(value));
                        },
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final state = ref.watch(ttsProvider);
        final voices = state.availableVoices;
        final languageCode = _appLanguageCode();
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSheetHandle(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '选择音色',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 18,
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
                      icon: Icon(Icons.refresh_rounded, color: _textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '列表已按当前书籍语言过滤，描述统一使用中文显示。',
                  style: TextStyle(color: _textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: state.isLoadingVoices
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : voices.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            '未获取到音色列表，请检查 TTS 服务连接。',
                            style: TextStyle(color: _textSecondary),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: voices.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: _textTertiary.withValues(alpha: 0.14),
                          ),
                          itemBuilder: (context, index) {
                            final voice = voices[index];
                            final selected = voice.value == state.selectedVoice;
                            final traits = voice.localizedTraits(languageCode);
                            final name = voice.localizedName(languageCode);

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
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
                                  _showToast('已切换为 $name');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? _accentGreenSoft
                                              : _accentGreenSoft.withValues(
                                                  alpha: 0.5,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.record_voice_over_rounded,
                                          color: _textPrimary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
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
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: _textPrimary,
                                                      fontSize: 14,
                                                      fontWeight: selected
                                                          ? FontWeight.w700
                                                          : FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _accentGreenSoft
                                                        .withValues(alpha: 0.8),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    voice.locale,
                                                    style: TextStyle(
                                                      color: _textPrimary,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              traits.isNotEmpty
                                                  ? traits.take(3).join(' / ')
                                                  : '默认音色',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: _textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: selected
                                              ? _textPrimary
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: selected
                                                ? _textPrimary
                                                : _textTertiary,
                                          ),
                                        ),
                                        child: selected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              )
                                            : null,
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

  Future<void> _showChapterSheet() async {
    if (_chapterQueue.isEmpty) {
      _showToast('当前书籍还没有可用章节');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _controlBgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSheetHandle(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '章节列表',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_chapterQueue.length} 章',
                      style: TextStyle(color: _textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.68,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _chapterQueue.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: _textTertiary.withValues(alpha: 0.14),
                    ),
                    itemBuilder: (context, index) {
                      final item = _chapterQueue[index];
                      final selected = item.index == _activeChapterIndex;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.pop(context);
                            if (selected) {
                              return;
                            }
                            _switchToChapterInPlace(index);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: selected
                                          ? _textPrimary
                                          : _textTertiary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.title.trim().isEmpty
                                        ? '未命名章节 ${index + 1}'
                                        : item.title.trim(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected
                                          ? _textPrimary
                                          : _textPrimary,
                                      fontSize: 14,
                                      height: 1.35,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (selected)
                                  Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: _textPrimary,
                                    size: 22,
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

  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: _textTertiary.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required String label,
    required bool selected,
    required bool emphasized,
    required VoidCallback onTap,
  }) {
    final bgColor = selected
        ? _textPrimary.withValues(alpha: 0.12)
        : emphasized
        ? _textPrimary.withValues(alpha: 0.06)
        : Colors.transparent;
    final fgColor = selected
        ? _textPrimary
        : emphasized
        ? _textPrimary
        : _textPrimary;
    final borderColor = selected
        ? _textPrimary.withValues(alpha: 0.3)
        : emphasized
        ? _textPrimary.withValues(alpha: 0.18)
        : _textTertiary.withValues(alpha: 0.22);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: emphasized ? 16 : 14,
          vertical: emphasized ? 12 : 10,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fgColor,
            fontSize: emphasized ? 14 : 13,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: Stack(
          children: [
            _buildAmbientGlow(),
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
                    const SizedBox(height: 28),
                    _buildBookCover(),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                        height: 1.35,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    _buildSecondaryControls(ttsState, rate),
                    const SizedBox(height: 28),
                    _buildProgressSection(ttsState),
                    const SizedBox(height: 32),
                    _buildPrimaryControls(ttsState, canPlay),
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
        _iconButton(
          icon: Icons.keyboard_arrow_down_rounded,
          onTap: _closeWithSync,
          size: 28,
          tooltip: '收起听书',
        ),
        const Spacer(),
        _iconButton(
          icon: Icons.share_outlined,
          onTap: () => _showToast('分享功能即将支持'),
          size: 22,
          tooltip: '分享',
        ),
        const SizedBox(width: 6),
        _iconButton(
          icon: Icons.more_horiz_rounded,
          onTap: () => _showToast('更多功能即将支持'),
          size: 22,
          tooltip: '更多',
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            splashColor: _textPrimary.withValues(alpha: 0.08),
            highlightColor: Colors.transparent,
            child: Icon(icon, size: size, color: _textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _buildBookCover() {
    final discSize = (MediaQuery.of(context).size.width * 0.58).clamp(
      220.0,
      306.0,
    );
    final coverSize = discSize * 0.78;
    final discSurface = Color.lerp(_bgTop, Colors.white, 0.38) ?? _bgTop;
    final discShadow = _accentGreenStrong.withValues(alpha: 0.14);

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
                  _accentGreen.withValues(alpha: 0.16),
                  _accentGreen.withValues(alpha: 0.04),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          RotationTransition(
            turns: _discController,
            child: Container(
              width: discSize,
              height: discSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.12, -0.16),
                  radius: 1.05,
                  colors: [
                    Colors.white.withValues(alpha: 0.94),
                    discSurface,
                    Color.lerp(discSurface, _accentGreenStrong, 0.14) ??
                        discSurface,
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: discShadow,
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (final factor in [0.95, 0.84, 0.73, 0.62, 0.52])
                    Container(
                      width: discSize * factor,
                      height: discSize * factor,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: factor > 0.84 ? 0.22 : 0.1,
                          ),
                          width: 0.8,
                        ),
                      ),
                    ),
                  Container(
                    width: coverSize,
                    height: coverSize,
                    padding: EdgeInsets.all(discSize * 0.028),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.34),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    child: ClipOval(child: BookCoverImage(book: widget.book)),
                  ),
                  Container(
                    width: discSize * 0.12,
                    height: discSize * 0.12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white,
                          Colors.white.withValues(alpha: 0.82),
                          _accentGreenStrong.withValues(alpha: 0.22),
                        ],
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

  Widget _buildSecondaryControls(TtsAppState ttsState, double rate) {
    return Row(
      children: [
        _secondaryActionButton(
          icon: Icons.timer_outlined,
          label: _sleepTimerLabel(ttsState.sleepTimerRemaining),
          emphasized: ttsState.sleepTimerRemaining != null,
          onTap: _showTimerSheet,
        ),
        const SizedBox(width: 10),
        _secondaryActionButton(
          icon: Icons.record_voice_over_outlined,
          label: '音色',
          onTap: () => _showVoicePickerSheet(ttsState),
        ),
        const SizedBox(width: 10),
        _secondaryActionButton(
          icon: Icons.speed_rounded,
          label: '${rate.toStringAsFixed(1)}x',
          emphasized: (rate - 1.0).abs() > 0.01,
          onTap: () => _showSpeedControlSheet(rate),
        ),
        const SizedBox(width: 10),
        _secondaryActionButton(
          icon: Icons.format_list_bulleted_rounded,
          label: '章节',
          emphasized: _chapterQueue.isNotEmpty,
          onTap: _showChapterSheet,
        ),
      ],
    );
  }

  Widget _secondaryActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool emphasized = false,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: _textPrimary.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 23, color: _textPrimary),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 11,
                    fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
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

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _isChapterMode
                    ? '章节 ${(ratio * 100).toStringAsFixed(0)}%'
                    : '第 ${_currentPage + 1} / ${_safeTotalPages} 页',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${_formatDuration(currentSeconds)} / ${_formatDuration(totalSeconds)}',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _textPrimary,
            inactiveTrackColor: _progressTrackColor,
            thumbColor: _textPrimary,
            overlayColor: _textPrimary.withValues(alpha: 0.12),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
          ),
          child: Slider(
            value: sliderValue.clamp(sliderMin, sliderMax),
            min: sliderMin,
            max: sliderMax,
            onChangeStart: (value) {
              if (_isChapterMode) {
                _onChapterSliderChangeStart(value);
              } else {
                _onPageSliderChangeStart(value);
              }
            },
            onChanged: (value) {
              setState(() {
                if (_isChapterMode) {
                  _currentOffset = value.round().clamp(
                    0,
                    _safeChapterLength - 1,
                  );
                  _estimatedPlaybackProgress = 0.0;
                } else {
                  _currentPage = value.round().clamp(0, _maxPageIndex);
                }
              });
            },
            onChangeEnd: (value) {
              if (_isChapterMode) {
                _onChapterSliderChangeEnd(value);
              } else {
                _onPageSliderChangeEnd(value);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryControls(TtsAppState ttsState, bool canPlay) {
    final isPlaying = ttsState.isSpeaking && !ttsState.isPaused;
    final isLoadingAudio =
        ttsState.isLoadingAudio && !ttsState.isSpeaking && !ttsState.isPaused;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _primaryControlButton(
          icon: Icons.replay_10_rounded,
          label: _isChapterMode ? '后退' : '上页',
          onTap: _isChapterMode ? () => _seekByChars(-480) : _goToPreviousPage,
          enabled: !_isAtStart() && canPlay,
        ),
        const SizedBox(width: 28),
        _buildPlayPauseButton(canPlay, isPlaying, isLoadingAudio, ttsState),
        const SizedBox(width: 28),
        _primaryControlButton(
          icon: Icons.forward_10_rounded,
          label: _isChapterMode ? '前进' : '下页',
          onTap: _isChapterMode ? () => _seekByChars(480) : _goToNextPage,
          enabled: !_isAtEnd() && canPlay,
        ),
      ],
    );
  }

  Widget _primaryControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 68,
          height: 68,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: enabled ? onTap : null,
              splashColor: _textPrimary.withValues(alpha: 0.08),
              highlightColor: Colors.transparent,
              child: Icon(
                icon,
                size: 30,
                color: enabled
                    ? _textPrimary
                    : _textTertiary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: enabled ? _textPrimary : _textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayPauseButton(
    bool canPlay,
    bool isPlaying,
    bool isLoadingAudio,
    TtsAppState ttsState,
  ) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: canPlay && !isLoadingAudio
              ? () => _togglePlayback(ttsState)
              : null,
          splashColor: _textPrimary.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Center(
            child: isLoadingAudio
                ? SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        canPlay ? _textPrimary : _textTertiary,
                      ),
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 44,
                    color: canPlay ? _textPrimary : _textTertiary,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmbientGlow() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 36,
            right: -90,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentGreen.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -80,
            bottom: 120,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentGreenStrong.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
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
