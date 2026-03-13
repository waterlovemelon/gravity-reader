import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

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

class _AudiobookPageState extends ConsumerState<AudiobookPage>
    with SingleTickerProviderStateMixin {
  static const Color _bgTop = Color(0xFF0A101B);
  static const Color _bgBottom = Color(0xFF05070A);
  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _primaryBlueSoft = Color(0x663B82F6);

  Timer? _progressTimer;
  late final AnimationController _discController;
  bool _isDiscSpinning = false;
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
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    _currentPage = widget.initialPage.clamp(0, _maxPageIndex);
    _currentOffset = widget.initialOffset.clamp(0, _safeChapterLength - 1);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(ttsProvider.notifier)
          .selectVoiceForBook(widget.book, sampleText: _initialPlaybackText());
      final currentTtsState = ref.read(ttsProvider);
      if (currentTtsState.isSpeaking || currentTtsState.isPaused) {
        if (currentTtsState.isSpeaking) {
          _startProgressTracking();
        }
        return;
      }
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
    _discController.dispose();
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
      backgroundColor: const Color(0xFF101722),
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
                        color: Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '语速 ${tempRate.toStringAsFixed(2)}x',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '建议区间 0.9x - 1.3x',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: _primaryBlue,
                        inactiveTrackColor: Colors.white.withValues(
                          alpha: 0.16,
                        ),
                        thumbColor: Colors.white,
                        overlayColor: _primaryBlue.withValues(alpha: 0.16),
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

  String _voiceDisplayLabel(TtsAppState ttsState) {
    final languageCode = _uiLanguageCode();
    final selected = ttsState.selectedVoice;
    final match = ttsState.availableVoices.where(
      (voice) => voice.value == selected,
    );
    if (match.isNotEmpty) {
      final voice = match.first;
      final name = voice.localizedName(languageCode);
      final localizedTraits = voice.localizedTraits(languageCode);
      final trait = localizedTraits.isNotEmpty ? localizedTraits.first : null;
      if (trait != null && trait.trim().isNotEmpty) {
        return '$name · $trait';
      }
      return name;
    }
    return selected.isNotEmpty ? selected : '选择音色';
  }

  String _uiLanguageCode() {
    if (!mounted) {
      return 'zh';
    }
    return Localizations.localeOf(context).languageCode;
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
      backgroundColor: const Color(0xFF101722),
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
                    color: Colors.white.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '选择音色',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
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
                      icon: Icon(
                        Icons.refresh,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
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
                            '未获取到音色列表，请检查 TTS 服务连接。',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
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
                                  ? _primaryBlue.withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.05),
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
                                  _showToast('已切换为 $name');
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
                                                color: Colors.white.withValues(
                                                  alpha: 0.95,
                                                ),
                                                fontSize: 14,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          if (selected)
                                            const Icon(
                                              Icons.check_circle,
                                              color: _primaryBlue,
                                              size: 18,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        traits.isNotEmpty
                                            ? traits.join(' / ')
                                            : (languageCode
                                                      .toLowerCase()
                                                      .startsWith('zh')
                                                  ? '默认'
                                                  : 'Default'),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.66,
                                          ),
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
      return _currentOffset <= 0;
    }
    return _currentPage <= 0;
  }

  bool _isAtEnd() {
    if (_isChapterMode) {
      return _currentOffset >= _safeChapterLength - 1;
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

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgBottom],
        ),
      ),
      child: Stack(
        children: [
          _buildAmbientGlow(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              topInset + 20,
              14,
              bottomInset + 12,
            ),
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 18),
                _buildBookCover(),
                const SizedBox(height: 14),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.96),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Spacer(),
                _buildMetaRow(rate, ttsState),
                const SizedBox(height: 12),
                _buildProgressSection(),
                const SizedBox(height: 12),
                _buildBottomControls(ttsState, canPlay),
                if (!canPlay) ...[
                  const SizedBox(height: 8),
                  Text(
                    '当前页没有可播放文本',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientGlow() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x5C3B82F6), Color(0x003B82F6)],
                ),
              ),
            ),
          ),
          Positioned(
            left: -80,
            bottom: 60,
            child: Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x4038BDF8), Color(0x0038BDF8)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _topIconButton(
          icon: Icons.keyboard_arrow_down_rounded,
          tooltip: '收起听书',
          onTap: _closeWithSync,
        ),
        const Spacer(),
        _topIconButton(
          icon: Icons.share_outlined,
          tooltip: '分享',
          onTap: () => _showToast('分享功能即将支持'),
        ),
        const SizedBox(width: 4),
        _topIconButton(
          icon: Icons.more_vert,
          tooltip: '更多',
          onTap: () => _showToast('更多功能即将支持'),
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
      width: 36,
      height: 36,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            focusColor: Colors.white.withValues(alpha: 0.14),
            child: Icon(
              icon,
              size: 22,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookCover() {
    final discSize = (MediaQuery.of(context).size.width * 0.58).clamp(
      220.0,
      300.0,
    );
    final coverPath = widget.book.coverPath;
    final coverFile = coverPath != null && coverPath.isNotEmpty
        ? File(coverPath)
        : null;
    final hasCover = coverFile != null && coverFile.existsSync();

    return Container(
      width: discSize.toDouble(),
      height: discSize.toDouble(),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.42),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF273040),
                  const Color(0xFF0E1118),
                  const Color(0xFF242B37),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
          ),
          RotationTransition(
            turns: _discController,
            child: Container(
              width: discSize * 0.84,
              height: discSize * 0.84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: hasCover
                    ? Image.file(
                        coverFile,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildCoverPlaceholder(),
                      )
                    : _buildCoverPlaceholder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF273B62), Color(0xFF111C2F)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 54,
          color: Colors.white.withValues(alpha: 0.76),
        ),
      ),
    );
  }

  Widget _buildMetaRow(double rate, TtsAppState ttsState) {
    final voiceLabel = _voiceDisplayLabel(ttsState);
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
          label: voiceLabel,
          onTap: () => _showVoicePickerSheet(ttsState),
        ),
        _metaAction(
          icon: Icons.speed_rounded,
          label: '${rate.toStringAsFixed(1)}x',
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
        height: 54,
        child: Material(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            focusColor: _primaryBlueSoft,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.72),
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
          icon: Icons.replay_10_rounded,
          onTap: _isChapterMode ? () => _seekByChars(-480) : _goToPreviousPage,
          enabled: !_isAtStart(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _isChapterMode
                        ? '章节进度 ${(ratio * 100).toStringAsFixed(0)}%'
                        : '页码 ${_currentPage + 1}/$_safeTotalPages',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_formatDuration(currentSeconds)} / ${_formatDuration(totalSeconds)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: _primaryBlue,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
                  thumbColor: Colors.white,
                  overlayColor: _primaryBlue.withValues(alpha: 0.14),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 7,
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
        const SizedBox(width: 8),
        _stepButton(
          icon: Icons.forward_10_rounded,
          onTap: _isChapterMode ? () => _seekByChars(480) : _goToNextPage,
          enabled: !_isAtEnd(),
        ),
      ],
    );
  }

  Widget _stepButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: Colors.white.withValues(alpha: enabled ? 0.06 : 0.02),
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: enabled ? onTap : null,
          focusColor: _primaryBlueSoft,
          child: Icon(
            icon,
            size: 24,
            color: Colors.white.withValues(alpha: enabled ? 0.82 : 0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(TtsAppState ttsState, bool canPlay) {
    final isPlaying = ttsState.isSpeaking && !ttsState.isPaused;
    final isLoadingAudio =
        ttsState.isLoadingAudio && !ttsState.isSpeaking && !ttsState.isPaused;

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
          enabled: !_isAtStart(),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Material(
                color: canPlay
                    ? _primaryBlue
                    : _primaryBlue.withValues(alpha: 0.42),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: canPlay && !isLoadingAudio
                      ? () => _togglePlayback(ttsState)
                      : null,
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isLoadingAudio)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.92),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _centerPlayerButton(
          icon: Icons.fast_forward_rounded,
          onTap: _isChapterMode ? () => _seekByChars(480) : _goToNextPage,
          enabled: !_isAtEnd(),
        ),
        const SizedBox(width: 8),
        _bottomAction(
          icon: Icons.menu_rounded,
          label: '目录',
          onTap: () => _showToast('目录即将支持'),
        ),
      ],
    );
  }

  Widget _centerPlayerButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return Expanded(
      child: SizedBox(
        height: 52,
        child: Material(
          color: Colors.white.withValues(alpha: enabled ? 0.06 : 0.02),
          borderRadius: BorderRadius.circular(26),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: enabled ? onTap : null,
            focusColor: _primaryBlueSoft,
            child: Icon(
              icon,
              size: 34,
              color: Colors.white.withValues(alpha: enabled ? 0.88 : 0.32),
            ),
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
          focusColor: _primaryBlueSoft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: Colors.white.withValues(alpha: 0.86)),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w600,
                ),
              ),
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
