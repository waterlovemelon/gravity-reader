import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/providers/tts_provider.dart';
import 'package:myreader/domain/entities/book.dart';

/// 听书界面改进设计方案
///
/// 设计理念：
/// 1. 清晰的功能分区，减少视觉混乱
/// 2. 现代化的播放控件，更大的触控区域
/// 3. 移除冗余的控制元素（重复的跳过按钮）
/// 4. 简化次要功能展示，突出核心播放控制
///
/// 布局结构（从上到下）：
/// - 顶部导航栏：收起、分享、更多
/// - 唱片封面（居中，大小适中）
/// - 书名/章节标题
/// - [新增] 当前状态指示（播放中/已暂停/加载中）
/// - 次要功能：定时关闭、音色、语速、章节列表（精简为图标+弹出）
/// - 进度条区域：时间显示 + 进度条
/// - 主要播放控件：快退 - 播放/暂停 - 快进
///
class AudiobookPageRedesign extends ConsumerStatefulWidget {
  final Book book;
  final String? initialText;
  final int initialPage;
  final int totalPages;
  final String? chapterTitle;
  final String? chapterText;
  final int? chapterIndex;
  final int initialOffset;

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
  });

  @override
  ConsumerState<AudiobookPageRedesign> createState() =>
      _AudiobookPageRedesignState();
}

class _AudiobookPageRedesignState extends ConsumerState<AudiobookPageRedesign>
    with SingleTickerProviderStateMixin {
  static const Color _bgTop = Color(0xFF0A101B);
  static const Color _bgBottom = Color(0xFF05070A);
  static const Color _primaryBlue = Color(0xFF3B82F6);
  static const Color _primaryBlueSoft = Color(0x663B82F6);
  static const Color _accentGlow = Color(0xFF38BDF8);

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

  Future<void> _startSpeaking(String text) async {
    // Implementation same as original
  }

  void _startProgressTracking() {
    // Implementation same as original
  }

  Future<void> _togglePlayback(TtsAppState ttsState) async {
    // Implementation same as original
  }

  void _stopSpeaking() {
    ref.read(ttsProvider.notifier).stop();
    _progressTimer?.cancel();
  }

  Future<void> _seekByChars(int delta) async {
    // Implementation same as original
  }

  void _goToPreviousPage() {
    // Implementation same as original
  }

  void _goToNextPage() {
    // Implementation same as original
  }

  void _showToast(String message) {
    // Implementation same as original
  }

  @override
  Widget build(BuildContext context) {
    final systemPadding = MediaQueryData.fromView(View.of(context)).padding;
    final topInset = systemPadding.top;
    final bottomInset = systemPadding.bottom;
    final ttsState = ref.watch(ttsProvider);
    final rate = ttsState.speechRate.clamp(0.5, 2.0);
    final title = widget.chapterTitle?.trim().isNotEmpty == true
        ? widget.chapterTitle!
        : '第 ${_currentPage + 1} 页';
    final canPlay = _isChapterMode
        ? _chapterText.trim().isNotEmpty
        : (ttsState.currentText?.trim().isNotEmpty == true) ||
              (widget.initialText?.trim().isNotEmpty == true);

    _syncDiscAnimation(ttsState);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              _buildAmbientGlow(),

              // 主内容区
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  topInset + 12,
                  20,
                  bottomInset + 16,
                ),
                child: Column(
                  children: [
                    // 顶部导航栏
                    _buildTopBar(),
                    const SizedBox(height: 32),

                    // 唱片封面
                    _buildBookCover(),
                    const SizedBox(height: 24),

                    // 书名/章节标题
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),

                    // [NEW] 播放状态指示
                    const SizedBox(height: 8),
                    _buildStatusIndicator(ttsState, canPlay),
                    const SizedBox(height: 32),

                    const Spacer(),

                    // [改进] 次要功能 - 横向4个图标按钮
                    _buildSecondaryControls(ttsState, rate),
                    const SizedBox(height: 32),

                    // [改进] 进度条区域
                    _buildProgressSection(),
                    const SizedBox(height: 40),

                    // [改进] 主要播放控件 - 快退、播放、快进
                    _buildPrimaryControls(ttsState, canPlay),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部导航栏
  Widget _buildTopBar() {
    return Row(
      children: [
        _iconButton(
          icon: Icons.keyboard_arrow_down_rounded,
          onTap: () => Navigator.pop(context),
          size: 28,
        ),
        const Spacer(),
        _iconButton(
          icon: Icons.share_outlined,
          onTap: () => _showToast('分享功能即将支持'),
          size: 24,
        ),
        _iconButton(
          icon: Icons.more_vert_rounded,
          onTap: () => _showToast('更多功能即将支持'),
          size: 24,
        ),
      ],
    );
  }

  /// 图标按钮（统一样式）
  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Icon(
            icon,
            size: size,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }

  /// 唱片封面（带旋转动画）
  Widget _buildBookCover() {
    final discSize = MediaQuery.of(context).size.width * 0.52;
    final discSizeClamped = discSize.clamp(200.0, 280.0);
    final coverPath = widget.book.coverPath;
    final coverFile = coverPath != null && coverPath.isNotEmpty
        ? File(coverPath)
        : null;
    final hasCover = coverFile != null && coverFile.existsSync();

    return SizedBox(
      width: discSizeClamped,
      height: discSizeClamped,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外圈光晕
          Container(
            width: discSizeClamped,
            height: discSizeClamped,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _accentGlow.withValues(alpha: 0.3),
                  _accentGlow.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // 唱片本体
          Container(
            width: discSizeClamped - 8,
            height: discSizeClamped - 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipOval(
              child: RotationTransition(
                turns: _discController,
                child: hasCover
                    ? Image.file(
                        coverFile!,
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

  /// 封面占位符
  Widget _buildCoverPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF273B62), const Color(0xFF111C2F)],
        ),
      ),
      child: const Icon(
        Icons.menu_book_rounded,
        size: 64,
        color: Colors.white54,
      ),
    );
  }

  /// [NEW] 播放状态指示器
  Widget _buildStatusIndicator(TtsAppState ttsState, bool canPlay) {
    if (!canPlay) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '当前页没有可播放文本',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (ttsState.isLoadingAudio) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_accentGlow),
            ),
          ),
          SizedBox(width: 8),
          Text(
            '正在加载音频...',
            style: TextStyle(
              color: _accentGlow,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (ttsState.isSpeaking && !ttsState.isPaused) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _primaryBlue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _primaryBlue.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: _accentGlow,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '播放中',
              style: TextStyle(
                color: _accentGlow,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (ttsState.isPaused) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 4),
            Text(
              '已暂停',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// [改进] 次要功能控制 - 4个图标按钮横向排列
  Widget _buildSecondaryControls(TtsAppState ttsState, double rate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _secondaryActionButton(
          icon: Icons.timer_outlined,
          label: '定时',
          onTap: () => _showToast('定时关闭即将支持'),
        ),
        _secondaryActionButton(
          icon: Icons.record_voice_over_outlined,
          label: '音色',
          onTap: () => _showVoicePickerSheet(ttsState),
        ),
        _secondaryActionButton(
          icon: Icons.speed_rounded,
          label: '${rate.toStringAsFixed(1)}x',
          onTap: () => _showSpeedControlSheet(rate),
        ),
        _secondaryActionButton(
          icon: Icons.list_rounded,
          label: '章节',
          onTap: () => _showToast('章节列表即将支持'),
        ),
      ],
    );
  }

  /// 次要功能按钮
  Widget _secondaryActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 22,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// [改进] 进度条区域
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

    return Column(
      children: [
        // 时间显示
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isChapterMode
                    ? '章节 ${(ratio * 100).toStringAsFixed(0)}%'
                    : '第 ${_currentPage + 1} / ${_safeTotalPages} 页',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${_formatDuration(currentSeconds)} / ${_formatDuration(totalSeconds)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // 进度条
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _accentGlow,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
            thumbColor: Colors.white,
            overlayColor: _accentGlow.withValues(alpha: 0.12),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: sliderValue.clamp(sliderMin, sliderMax),
            min: sliderMin,
            max: sliderMax,
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
            onChangeEnd: (value) {
              // Handle seek completion
            },
          ),
        ),
      ],
    );
  }

  /// [改进] 主要播放控件 - 快退、播放、快进
  Widget _buildPrimaryControls(TtsAppState ttsState, bool canPlay) {
    final isPlaying = ttsState.isSpeaking && !ttsState.isPaused;
    final isLoadingAudio =
        ttsState.isLoadingAudio && !ttsState.isSpeaking && !ttsState.isPaused;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 快退按钮（15秒）
        _primaryControlButton(
          icon: Icons.replay_10_rounded,
          label: '15s',
          onTap: _isChapterMode ? () => _seekByChars(-480) : _goToPreviousPage,
          enabled: !_isAtStart() && canPlay,
        ),
        const SizedBox(width: 40),

        // 播放/暂停按钮（大尺寸圆形）
        _buildPlayPauseButton(canPlay, isPlaying, isLoadingAudio, ttsState),

        const SizedBox(width: 40),

        // 快进按钮（15秒）
        _primaryControlButton(
          icon: Icons.forward_10_rounded,
          label: '15s',
          onTap: _isChapterMode ? () => _seekByChars(480) : _goToNextPage,
          enabled: !_isAtEnd() && canPlay,
        ),
      ],
    );
  }

  /// 主控按钮（快退/快进）
  Widget _primaryControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: enabled ? 0.08 : 0.03),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: enabled ? onTap : null,
              child: Icon(
                icon,
                size: 28,
                color: Colors.white.withValues(alpha: enabled ? 0.9 : 0.3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: enabled ? 0.5 : 0.2),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 播放/暂停按钮（中心大号圆形按钮）
  Widget _buildPlayPauseButton(
    bool canPlay,
    bool isPlaying,
    bool isLoadingAudio,
    TtsAppState ttsState,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 按钮光晕效果
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                canPlay
                    ? _primaryBlue.withValues(alpha: 0.4)
                    : _primaryBlue.withValues(alpha: 0.15),
                canPlay
                    ? _primaryBlue.withValues(alpha: 0.0)
                    : _primaryBlue.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
        // 主按钮
        GestureDetector(
          onTap: canPlay && !isLoadingAudio
              ? () => _togglePlayback(ttsState)
              : null,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: canPlay
                    ? [const Color(0xFF4A9EFF), _primaryBlue]
                    : [
                        _primaryBlue.withValues(alpha: 0.3),
                        _primaryBlue.withValues(alpha: 0.2),
                      ],
              ),
              boxShadow: canPlay
                  ? [
                      BoxShadow(
                        color: _primaryBlue.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: isLoadingAudio
                ? const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
          ),
        ),
      ],
    );
  }

  /// 环境背景光效
  Widget _buildAmbientGlow() {
    return IgnorePointer(
      child: Stack(
        children: [
          // 右上角蓝光
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _primaryBlue.withValues(alpha: 0.25),
                    _primaryBlue.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // 左下角蓝光
          Positioned(
            left: -100,
            bottom: 80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentGlow.withValues(alpha: 0.2),
                    _accentGlow.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== 辅助方法 ==========

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
    // Implementation same as original
  }

  Future<void> _showVoicePickerSheet(TtsAppState ttsState) async {
    // Implementation same as original
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
