import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/tts_provider.dart';
import 'package:myreader/domain/entities/book.dart';

class AudiobookPage extends ConsumerStatefulWidget {
  final Book book;
  final String? initialText;
  final int initialPage;
  final int totalPages;
  final String? chapterTitle;
  final String? chapterText;
  final int? chapterIndex;
  final int initialOffset;

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
  });

  @override
  ConsumerState<AudiobookPage> createState() => _AudiobookPageState();
}

class _AudiobookPageState extends ConsumerState<AudiobookPage> {
  Timer? _progressTimer;
  int _currentPage = 0;
  int? _pageBeforeDrag;
  int? _offsetBeforeDrag;
  int _currentOffset = 0;

  bool get _isChapterMode =>
      widget.chapterIndex != null &&
      widget.chapterText != null &&
      widget.chapterText!.trim().isNotEmpty;

  String get _chapterText => widget.chapterText ?? '';
  int get _safeChapterLength => math.max(1, _chapterText.length);
  int get _safeTotalPages => widget.totalPages <= 0 ? 1 : widget.totalPages;
  int get _maxPageIndex => _safeTotalPages - 1;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, _maxPageIndex);
    _currentOffset = widget.initialOffset.clamp(0, _safeChapterLength - 1);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final launchText = _initialPlaybackText();
      if (launchText == null || launchText.trim().isEmpty) {
        return;
      }
      await _startSpeaking(launchText);
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    try {
      ref.read(ttsProvider.notifier).stop();
    } catch (_) {}
    super.dispose();
  }

  String? _initialPlaybackText() {
    if (_isChapterMode) {
      return _textFromOffset(_currentOffset);
    }
    return widget.initialText;
  }

  String _textFromOffset(int offset) {
    if (!_isChapterMode) {
      return (widget.initialText ?? '').trim();
    }
    final safeOffset = offset.clamp(0, _safeChapterLength - 1);
    return _chapterText.substring(safeOffset).trim();
  }

  Future<void> _startSpeaking(String text) async {
    if (text.trim().isEmpty) {
      _showToast('当前没有可播放内容');
      return;
    }
    try {
      await ref.read(ttsProvider.notifier).speak(text);
      _startProgressTracking();
    } catch (_) {
      _showToast('播放失败，请重试');
    }
  }

  Future<void> _restartFromCurrentPosition() async {
    final text = _textFromOffset(_currentOffset);
    if (text.trim().isEmpty) {
      return;
    }
    await ref.read(ttsProvider.notifier).stop();
    await _startSpeaking(text);
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

    final text = _textFromOffset(_currentOffset);
    await _startSpeaking(text);
  }

  void _stopSpeaking() {
    ref.read(ttsProvider.notifier).stop();
    _progressTimer?.cancel();
  }

  Future<void> _seekChapterOffset(
    int targetOffset, {
    bool force = false,
  }) async {
    if (!_isChapterMode) {
      return;
    }
    final safeOffset = targetOffset.clamp(0, _safeChapterLength - 1);
    if (!force && safeOffset == _currentOffset) {
      return;
    }

    final ttsState = ref.read(ttsProvider);
    final shouldContinue = ttsState.isSpeaking || ttsState.isPaused;
    setState(() {
      _currentOffset = safeOffset;
    });

    if (shouldContinue) {
      await _restartFromCurrentPosition();
    }
  }

  Future<void> _seekByChars(int delta) async {
    if (!_isChapterMode) {
      return;
    }
    final nextOffset = (_currentOffset + delta).clamp(
      0,
      _safeChapterLength - 1,
    );
    await _seekChapterOffset(nextOffset);
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
    if (_pageBeforeDrag != null && _pageBeforeDrag == page) {
      _pageBeforeDrag = null;
      return;
    }
    _stopSpeaking();
    Navigator.pop(context, {'action': 'goto_page', 'page': page});
  }

  void _onChapterSliderChangeStart(double value) {
    _offsetBeforeDrag = _currentOffset;
  }

  void _onChapterSliderChangeEnd(double value) {
    final nextOffset = value.round().clamp(0, _safeChapterLength - 1);
    final before = _offsetBeforeDrag;
    _offsetBeforeDrag = null;
    if (before != null && before == nextOffset) {
      return;
    }
    _seekChapterOffset(nextOffset, force: true);
  }

  void _closeWithSync() {
    if (_isChapterMode && widget.chapterIndex != null) {
      Navigator.pop(context, {
        'action': 'goto_txt_location',
        'chapterIndex': widget.chapterIndex,
        'offset': _currentOffset,
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

  String _statusLabel(TtsAppState ttsState) {
    if (ttsState.isSpeaking) {
      return '正在朗读';
    }
    if (ttsState.isPaused) {
      return '已暂停';
    }
    return '准备播放';
  }

  double _safeSpeechRate(double speechRate) {
    return speechRate.clamp(0.5, 2.0);
  }

  String _displayTitle() {
    final chapter = widget.chapterTitle?.trim() ?? '';
    if (chapter.isNotEmpty) {
      return chapter;
    }
    return '第 ${_currentPage + 1} 页';
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

  Future<void> _showSpeedControlSheet(double currentRate) async {
    var tempRate = currentRate;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF12171B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.24),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '语速 ${tempRate.toStringAsFixed(2)}x',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF4D89D8),
                        inactiveTrackColor: Colors.white.withOpacity(0.16),
                        thumbColor: Colors.white,
                        overlayColor: const Color(0xFF4D89D8).withOpacity(0.14),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
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

  @override
  Widget build(BuildContext context) {
    final ttsState = ref.watch(ttsProvider);
    final rate = _safeSpeechRate(ttsState.speechRate);
    final chapterTitle = _displayTitle();

    return Container(
      color: const Color(0xFF05070A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
          child: Column(
            children: [
              _buildTopBar(ttsState),
              const SizedBox(height: 18),
              _buildBookCover(),
              const SizedBox(height: 18),
              Text(
                chapterTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.95),
                  height: 1.05,
                ),
              ),
              const Spacer(),
              _buildMetaRow(rate),
              const SizedBox(height: 16),
              _buildProgressSection(),
              const SizedBox(height: 18),
              _buildBottomControls(ttsState),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(TtsAppState ttsState) {
    return Row(
      children: [
        _topIconButton(
          icon: Icons.keyboard_arrow_down_rounded,
          onTap: _closeWithSync,
        ),
        Expanded(
          child: Center(
            child: Container(
              height: 34,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeTag('AI 阅读', true),
                  _buildModeTag('延展收听', false),
                ],
              ),
            ),
          ),
        ),
        _topIconButton(
          icon: Icons.ios_share_outlined,
          onTap: () => _showToast('分享功能即将支持'),
        ),
        const SizedBox(width: 4),
        _topIconButton(
          icon: Icons.more_vert,
          onTap: () => _showToast(_statusLabel(ttsState)),
        ),
      ],
    );
  }

  Widget _topIconButton({required IconData icon, required VoidCallback onTap}) {
    return SizedBox(
      width: 34,
      height: 34,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: Icon(icon, size: 22, color: Colors.white.withOpacity(0.88)),
        ),
      ),
    );
  }

  Widget _buildModeTag(String text, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Colors.white.withOpacity(0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(active ? 0.92 : 0.64),
        ),
      ),
    );
  }

  Widget _buildBookCover() {
    final coverWidth = (MediaQuery.of(context).size.width * 0.5).clamp(
      180.0,
      230.0,
    );
    final coverHeight = coverWidth * 1.5;
    final coverPath = widget.book.coverPath;
    final coverFile = coverPath != null && coverPath.isNotEmpty
        ? File(coverPath)
        : null;
    final hasCover = coverFile != null && coverFile.existsSync();

    return Container(
      width: coverWidth.toDouble(),
      height: coverHeight.toDouble(),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: hasCover
            ? Image.file(
                coverFile,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildCoverPlaceholder(),
              )
            : _buildCoverPlaceholder(),
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A3955), Color(0xFF121A2A)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 52,
          color: Colors.white.withOpacity(0.76),
        ),
      ),
    );
  }

  Widget _buildMetaRow(double rate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _metaAction(
          icon: Icons.timer_outlined,
          label: '定时关闭',
          onTap: () => _showToast('定时关闭即将支持'),
        ),
        _metaAction(
          icon: Icons.record_voice_over_outlined,
          label: 'AI男声 2025A',
          onTap: () => _showToast('音色切换即将支持'),
        ),
        _metaAction(
          icon: Icons.speed_rounded,
          label: '语速 ${rate.toStringAsFixed(1)}x',
          onTap: () => _showSpeedControlSheet(rate),
        ),
        _metaAction(
          icon: Icons.playlist_add_check_rounded,
          label: '已加入',
          onTap: () => _showToast('已加入播放列表'),
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
        height: 56,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 21, color: Colors.white.withOpacity(0.78)),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.72),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final sliderMin = 0.0;
    final sliderMax = _isChapterMode
        ? (_safeChapterLength - 1).toDouble()
        : _maxPageIndex.toDouble();
    final sliderValue = _isChapterMode
        ? _currentOffset.toDouble()
        : _currentPage.toDouble();
    final totalSeconds = _estimatedDurationSeconds();
    final ratio = sliderMax <= 0
        ? 0.0
        : (sliderValue / sliderMax).clamp(0.0, 1.0);
    final currentSeconds = (totalSeconds * ratio).round();

    return Row(
      children: [
        _stepButton(
          icon: CupertinoIcons.gobackward_15,
          onTap: _isChapterMode ? () => _seekByChars(-480) : _goToPreviousPage,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_formatDuration(currentSeconds)} / ${_formatDuration(totalSeconds)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.white.withOpacity(0.34),
                  inactiveTrackColor: Colors.white.withOpacity(0.15),
                  thumbColor: Colors.white,
                  overlayColor: Colors.white.withOpacity(0.12),
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                ),
                child: Slider(
                  value: sliderValue.clamp(sliderMin, sliderMax),
                  min: sliderMin,
                  max: sliderMax,
                  onChangeStart: _isChapterMode
                      ? _onChapterSliderChangeStart
                      : _onPageSliderChangeStart,
                  onChanged: (value) {
                    setState(() {
                      if (_isChapterMode) {
                        _currentOffset = value.round().clamp(
                          0,
                          _safeChapterLength - 1,
                        );
                      } else {
                        _currentPage = value.round().clamp(0, _maxPageIndex);
                      }
                    });
                  },
                  onChangeEnd: _isChapterMode
                      ? _onChapterSliderChangeEnd
                      : _onPageSliderChangeEnd,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _stepButton(
          icon: CupertinoIcons.goforward_15,
          onTap: _isChapterMode ? () => _seekByChars(480) : _goToNextPage,
        ),
      ],
    );
  }

  Widget _stepButton({required IconData icon, required VoidCallback onTap}) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: onTap,
          child: Icon(icon, size: 24, color: Colors.white.withOpacity(0.76)),
        ),
      ),
    );
  }

  Widget _buildBottomControls(TtsAppState ttsState) {
    final canPlay = _isChapterMode
        ? _chapterText.trim().isNotEmpty
        : (ttsState.currentText?.trim().isNotEmpty == true) ||
              (widget.initialText?.trim().isNotEmpty == true);
    final isPlaying = ttsState.isSpeaking && !ttsState.isPaused;

    return Row(
      children: [
        _bottomAction(
          icon: Icons.import_contacts_outlined,
          label: '原文',
          onTap: _closeWithSync,
        ),
        const SizedBox(width: 8),
        _centerPlayerButton(
          icon: Icons.fast_rewind_rounded,
          onTap: _isChapterMode ? () => _seekByChars(-480) : _goToPreviousPage,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          height: 84,
          child: Material(
            color: canPlay
                ? const Color(0xFF2E7FD6)
                : const Color(0xFF2E7FD6).withOpacity(0.45),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: canPlay ? () => _togglePlayback(ttsState) : null,
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 42,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _centerPlayerButton(
          icon: Icons.fast_forward_rounded,
          onTap: _isChapterMode ? () => _seekByChars(480) : _goToNextPage,
        ),
        const SizedBox(width: 8),
        _bottomAction(
          icon: Icons.menu_rounded,
          label: '$_safeTotalPages 集',
          onTap: () => _showToast('目录即将支持'),
        ),
      ],
    );
  }

  Widget _centerPlayerButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 52,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onTap,
            child: Icon(icon, size: 34, color: Colors.white.withOpacity(0.84)),
          ),
        ),
      ),
    );
  }

  Widget _bottomAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 56,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: Colors.white.withOpacity(0.82)),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.76),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
