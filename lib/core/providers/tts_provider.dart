import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/constants/app_constants.dart';
import 'package:myreader/core/models/tts_chapter_payload.dart';
import 'package:myreader/core/providers/shared_preferences_provider.dart';
import 'package:myreader/data/services/tts_service.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsAppState {
  final bool isSpeaking;
  final bool isPaused;
  final bool isAudiobookUiVisible;
  final String? currentText;
  final Book? currentBook;
  final int? currentStartOffset;
  final int? currentChapterIndex;
  final int? currentChapterLength;
  final int? currentPlaybackOffset;
  final int? currentSegmentStartOffset;
  final int? currentSegmentEndOffset;
  final double playbackProgress;
  final double speechRate;
  final double pitch;
  final double volume;
  final String selectedVoice;
  final List<TtsVoice> availableVoices;
  final bool isLoadingVoices;
  final bool isLoadingAudio;
  final List<TtsChapterPayload> chapterQueue;
  final DateTime? sleepTimerEndsAt;
  final Duration? sleepTimerRemaining;

  const TtsAppState({
    this.isSpeaking = false,
    this.isPaused = false,
    this.isAudiobookUiVisible = false,
    this.currentText,
    this.currentBook,
    this.currentStartOffset,
    this.currentChapterIndex,
    this.currentChapterLength,
    this.currentPlaybackOffset,
    this.currentSegmentStartOffset,
    this.currentSegmentEndOffset,
    this.playbackProgress = 0.0,
    this.speechRate = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.selectedVoice = AppConstants.ttsVoice,
    this.availableVoices = const <TtsVoice>[],
    this.isLoadingVoices = false,
    this.isLoadingAudio = false,
    this.chapterQueue = const <TtsChapterPayload>[],
    this.sleepTimerEndsAt,
    this.sleepTimerRemaining,
  });

  TtsAppState copyWith({
    bool? isSpeaking,
    bool? isPaused,
    bool? isAudiobookUiVisible,
    String? currentText,
    bool clearCurrentText = false,
    Book? currentBook,
    bool clearCurrentBook = false,
    int? currentStartOffset,
    bool clearCurrentStartOffset = false,
    int? currentChapterIndex,
    bool clearCurrentChapterIndex = false,
    int? currentChapterLength,
    bool clearCurrentChapterLength = false,
    int? currentPlaybackOffset,
    bool clearCurrentPlaybackOffset = false,
    int? currentSegmentStartOffset,
    int? currentSegmentEndOffset,
    bool clearCurrentSegmentOffsets = false,
    double? playbackProgress,
    double? speechRate,
    double? pitch,
    double? volume,
    String? selectedVoice,
    List<TtsVoice>? availableVoices,
    bool? isLoadingVoices,
    bool? isLoadingAudio,
    List<TtsChapterPayload>? chapterQueue,
    bool clearChapterQueue = false,
    DateTime? sleepTimerEndsAt,
    bool clearSleepTimerEndsAt = false,
    Duration? sleepTimerRemaining,
    bool clearSleepTimerRemaining = false,
  }) {
    return TtsAppState(
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isPaused: isPaused ?? this.isPaused,
      isAudiobookUiVisible: isAudiobookUiVisible ?? this.isAudiobookUiVisible,
      currentText: clearCurrentText ? null : (currentText ?? this.currentText),
      currentBook: clearCurrentBook ? null : (currentBook ?? this.currentBook),
      currentStartOffset: clearCurrentStartOffset
          ? null
          : (currentStartOffset ?? this.currentStartOffset),
      currentChapterIndex: clearCurrentChapterIndex
          ? null
          : (currentChapterIndex ?? this.currentChapterIndex),
      currentChapterLength: clearCurrentChapterLength
          ? null
          : (currentChapterLength ?? this.currentChapterLength),
      currentPlaybackOffset: clearCurrentPlaybackOffset
          ? null
          : (currentPlaybackOffset ?? this.currentPlaybackOffset),
      currentSegmentStartOffset: clearCurrentSegmentOffsets
          ? null
          : (currentSegmentStartOffset ?? this.currentSegmentStartOffset),
      currentSegmentEndOffset: clearCurrentSegmentOffsets
          ? null
          : (currentSegmentEndOffset ?? this.currentSegmentEndOffset),
      playbackProgress: playbackProgress ?? this.playbackProgress,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      selectedVoice: selectedVoice ?? this.selectedVoice,
      availableVoices: availableVoices ?? this.availableVoices,
      isLoadingVoices: isLoadingVoices ?? this.isLoadingVoices,
      isLoadingAudio: isLoadingAudio ?? this.isLoadingAudio,
      chapterQueue: clearChapterQueue
          ? const <TtsChapterPayload>[]
          : (chapterQueue ?? this.chapterQueue),
      sleepTimerEndsAt: clearSleepTimerEndsAt
          ? null
          : (sleepTimerEndsAt ?? this.sleepTimerEndsAt),
      sleepTimerRemaining: clearSleepTimerRemaining
          ? null
          : (sleepTimerRemaining ?? this.sleepTimerRemaining),
    );
  }
}

class TtsNotifier extends StateNotifier<TtsAppState> {
  final TtsService _ttsService;
  final SharedPreferences _prefs;
  final Map<String, List<TtsVoice>> _localeVoicesCache =
      <String, List<TtsVoice>>{};
  final Map<String, String> _bookVoiceAssignments = <String, String>{};
  Future<void>? _initializeFuture;
  bool _suppressAutoAdvanceOnce = false;
  bool _autoAdvanceInProgress = false;
  bool _uiHandlesChapterAdvance = false;
  bool _serviceHandlesChapterQueue = false;
  Timer? _sleepTimer;
  Timer? _sleepTimerTicker;

  TtsNotifier(this._prefs)
    : _ttsService = TtsService(),
      super(const TtsAppState()) {
    _ttsService.setStateCallback((ttsState) {
      _trace(
        'service state callback: ttsState=$ttsState, '
        'before isSpeaking=${state.isSpeaking}, '
        'isPaused=${state.isPaused}, '
        'playbackProgress=${state.playbackProgress}, '
        'currentTextLength=${state.currentText?.length ?? 0}',
      );
      switch (ttsState) {
        case TtsState.playing:
          state = state.copyWith(
            isSpeaking: true,
            isPaused: false,
            isLoadingAudio: false,
          );
          break;
        case TtsState.paused:
          state = state.copyWith(
            isSpeaking: false,
            isPaused: true,
            isLoadingAudio: false,
          );
          break;
        case TtsState.stopped:
          _serviceHandlesChapterQueue = false;
          state = state.copyWith(
            isSpeaking: false,
            isPaused: false,
            isLoadingAudio: false,
          );
          break;
      }
      _trace(
        'service state applied: ttsState=$ttsState, '
        'after isSpeaking=${state.isSpeaking}, '
        'isPaused=${state.isPaused}, '
        'playbackProgress=${state.playbackProgress}, '
        'currentTextLength=${state.currentText?.length ?? 0}',
      );
    });
    _ttsService.setCompletionCallback(() => _handlePlaybackCompletion());
    _ttsService.setProgressCallback((progress) {
      state = state.copyWith(playbackProgress: progress.clamp(0.0, 1.0));
    });
    _ttsService.setPlaybackOffsetCallback((offset) {
      final baseOffset = state.currentStartOffset ?? 0;
      state = state.copyWith(
        currentPlaybackOffset: offset == null ? null : baseOffset + offset,
      );
    });
    _ttsService.setChapterChangedCallback((chapterIndex, chapterLength) {
      final currentIndex = state.currentChapterIndex;
      final didChapterChange =
          currentIndex != null && currentIndex != chapterIndex;
      final nextText = didChapterChange
          ? _chapterTextFromQueue(chapterIndex)
          : state.currentText;
      state = state.copyWith(
        currentChapterIndex: chapterIndex,
        currentChapterLength: chapterLength,
        currentStartOffset: didChapterChange ? 0 : state.currentStartOffset,
        currentText: nextText,
        currentPlaybackOffset: didChapterChange
            ? 0
            : state.currentPlaybackOffset,
        clearCurrentSegmentOffsets: didChapterChange,
        playbackProgress: didChapterChange ? 0.0 : state.playbackProgress,
      );
    });
    _ttsService.setSegmentCallback((start, end) {
      final baseOffset = state.currentStartOffset;
      if (baseOffset == null || start == null || end == null) {
        state = state.copyWith(clearCurrentSegmentOffsets: true);
        return;
      }
      state = state.copyWith(
        currentSegmentStartOffset: baseOffset + start,
        currentSegmentEndOffset: baseOffset + end,
      );
    });
    unawaited(_initialize());
  }

  bool _handlePlaybackCompletion() {
    if (_autoAdvanceInProgress) {
      return false;
    }
    if (_suppressAutoAdvanceOnce) {
      _suppressAutoAdvanceOnce = false;
      _trace('auto advance suppressed by manual stop');
      return false;
    }
    if (_uiHandlesChapterAdvance) {
      return false;
    }
    if (_serviceHandlesChapterQueue) {
      return false;
    }
    final wasActive = state.isSpeaking || state.isPaused;
    if (!wasActive) {
      return false;
    }
    final queue = state.chapterQueue;
    if (queue.isEmpty) {
      return false;
    }
    final currentIndex = state.currentChapterIndex;
    if (currentIndex == null) {
      return false;
    }
    final currentPos = queue.indexWhere((item) => item.index == currentIndex);
    if (currentPos < 0 || currentPos + 1 >= queue.length) {
      return false;
    }
    final next = queue[currentPos + 1];
    _trace(
      'auto advance: current=$currentIndex -> next=${next.index}, '
      'queuePos=$currentPos, queueSize=${queue.length}',
    );
    unawaited(_autoAdvanceToNextChapter(next, state));
    return true;
  }

  Future<void> _autoAdvanceToNextChapter(
    TtsChapterPayload next,
    TtsAppState previousState,
  ) async {
    _autoAdvanceInProgress = true;
    try {
      state = state.copyWith(
        isSpeaking: false,
        isPaused: false,
        isLoadingAudio: true,
        playbackProgress: 0.0,
      );
      await speak(
        next.text,
        book: previousState.currentBook,
        chapterTitle: next.title,
        startOffset: 0,
        chapterIndex: next.index,
        chapterLength: next.text.length,
        chapterQueue: previousState.chapterQueue,
        preserveAudioSession: true,
      );
    } finally {
      _autoAdvanceInProgress = false;
    }
  }

  Future<void> _initialize() async {
    _initializeFuture ??= _initializeInternal();
    return _initializeFuture!;
  }

  Future<void> _initializeInternal() async {
    final persistedVoice = _prefs.getString(AppConstants.keyTtsSelectedVoice);
    final initialVoice =
        (persistedVoice == null || persistedVoice.trim().isEmpty)
        ? AppConstants.ttsVoice
        : persistedVoice.trim();

    await _ttsService.setVoice(initialVoice);
    state = state.copyWith(selectedVoice: initialVoice);
    _loadPersistedBookVoiceMap(_prefs);
    _log(
      'initialized: selectedVoice=$initialVoice, '
      'bookVoiceMapCount=${_bookVoiceAssignments.length}',
    );
  }

  void _trace(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final formatted = '[$timestamp] [TtsNotifier] $message';
    debugPrint(formatted);
    developer.log(formatted, name: 'TtsNotifier');
  }

  Future<void> _ensureInitialized() async {
    await _initialize();
  }

  Future<void> speak(
    String text, {
    Book? book,
    String? chapterTitle,
    int? startOffset,
    int? chapterIndex,
    int? chapterLength,
    List<TtsChapterPayload>? chapterQueue,
    bool preserveAudioSession = false,
    bool continuousChapterQueue = false,
  }) async {
    _trace(
      'speak: textLength=${text.length}, selectedVoice=${state.selectedVoice}',
    );
    _suppressAutoAdvanceOnce = false;
    _serviceHandlesChapterQueue = continuousChapterQueue;
    state = state.copyWith(
      isSpeaking: false,
      isPaused: false,
      isLoadingAudio: true,
      playbackProgress: 0.0,
      currentText: text,
      currentBook: book,
      currentStartOffset: startOffset,
      currentChapterIndex: chapterIndex,
      currentChapterLength: chapterLength,
      currentPlaybackOffset: startOffset,
      clearCurrentSegmentOffsets: true,
      chapterQueue: chapterQueue,
    );
    try {
      _ttsService.setMediaContext(
        book == null
            ? null
            : TtsMediaContext(
                id: book.id,
                title: book.title,
                author: book.author,
                coverPath: book.coverPath,
                chapterTitle: chapterTitle,
              ),
      );
      await _ttsService.setVoice(state.selectedVoice);
      await _ttsService.speak(
        text,
        preserveAudioSession: preserveAudioSession,
        chapterQueue: chapterQueue ?? const <TtsChapterPayload>[],
        currentChapterIndex: chapterIndex,
        currentChapterLength: chapterLength,
        continuousChapterQueue: continuousChapterQueue,
      );
      state = state.copyWith(
        isSpeaking: true,
        currentText: text,
        currentBook: book,
        currentStartOffset: startOffset,
        currentChapterIndex: chapterIndex,
        currentChapterLength: chapterLength,
        currentPlaybackOffset: startOffset,
        clearCurrentSegmentOffsets: true,
        playbackProgress: 0.0,
        isPaused: false,
        isLoadingAudio: false,
        chapterQueue: chapterQueue,
      );
    } catch (e) {
      _serviceHandlesChapterQueue = false;
      _ttsService.setMediaContext(null);
      state = state.copyWith(
        isSpeaking: false,
        isLoadingAudio: false,
        clearCurrentBook: true,
        clearCurrentSegmentOffsets: true,
      );
    }
  }

  Future<void> stop() async {
    try {
      _trace('stop');
      clearSleepTimer();
      _suppressAutoAdvanceOnce = true;
      _serviceHandlesChapterQueue = false;
      await _ttsService.stop();
      _ttsService.setMediaContext(null);
      state = state.copyWith(
        isSpeaking: false,
        isPaused: false,
        clearCurrentText: true,
        clearCurrentBook: true,
        clearCurrentStartOffset: true,
        clearCurrentChapterIndex: true,
        clearCurrentChapterLength: true,
        clearCurrentPlaybackOffset: true,
        clearCurrentSegmentOffsets: true,
        playbackProgress: 0.0,
        isLoadingAudio: false,
        clearChapterQueue: true,
      );
    } catch (e) {
      // Handle error
    }
  }

  Future<void> pause() async {
    try {
      _trace(
        'pause: isSpeaking=${state.isSpeaking}, '
        'isPaused=${state.isPaused}, playbackProgress=${state.playbackProgress}',
      );
      await _ttsService.pause();
      state = state.copyWith(
        isSpeaking: false,
        isPaused: true,
        isLoadingAudio: false,
      );
    } catch (e) {
      // Handle error
    }
  }

  Future<void> resume() async {
    try {
      _trace(
        'resume: isSpeaking=${state.isSpeaking}, '
        'isPaused=${state.isPaused}, playbackProgress=${state.playbackProgress}',
      );
      await _ttsService.resume();
      state = state.copyWith(
        isSpeaking: true,
        isPaused: false,
        isLoadingAudio: false,
      );
    } catch (e) {
      // Handle error
    }
  }

  String? _chapterTextFromQueue(int chapterIndex) {
    for (final chapter in state.chapterQueue) {
      if (chapter.index == chapterIndex) {
        return chapter.text;
      }
    }
    return null;
  }

  void setAudiobookUiVisible(bool isVisible) {
    state = state.copyWith(isAudiobookUiVisible: isVisible);
  }

  void setUiHandlesChapterAdvance(bool enabled) {
    _uiHandlesChapterAdvance = enabled;
  }

  Future<void> setSpeechRate(double rate) async {
    await _ttsService.setSpeechRate(rate);
    state = state.copyWith(speechRate: rate);
  }

  Future<void> setPitch(double pitch) async {
    await _ttsService.setPitch(pitch);
    state = state.copyWith(pitch: pitch);
  }

  Future<void> setVolume(double volume) async {
    await _ttsService.setVolume(volume);
    state = state.copyWith(volume: volume);
  }

  Future<void> preloadUpcomingText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _trace('preloadUpcomingText: textLength=${trimmed.length}');
    await _ttsService.setVoice(state.selectedVoice);
    await _ttsService.preloadUpcomingText(trimmed);
  }

  void _updateSleepTimerState() {
    final endsAt = state.sleepTimerEndsAt;
    if (endsAt == null) {
      return;
    }
    final remaining = endsAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      clearSleepTimer();
      unawaited(stop());
      return;
    }
    state = state.copyWith(
      sleepTimerRemaining: Duration(seconds: remaining.inSeconds),
    );
  }

  void _startSleepTimerTicker() {
    _sleepTimerTicker?.cancel();
    _sleepTimerTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateSleepTimerState();
    });
  }

  void setSleepTimer(Duration duration) {
    final safeDuration = Duration(
      seconds: duration.inSeconds.clamp(1, 24 * 3600).toInt(),
    );
    final endsAt = DateTime.now().add(safeDuration);
    _sleepTimer?.cancel();
    _sleepTimerTicker?.cancel();
    _sleepTimer = Timer(safeDuration, () async {
      clearSleepTimer();
      await stop();
    });
    state = state.copyWith(
      sleepTimerEndsAt: endsAt,
      sleepTimerRemaining: safeDuration,
    );
    _startSleepTimerTicker();
  }

  void clearSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimerTicker?.cancel();
    _sleepTimer = null;
    _sleepTimerTicker = null;
    state = state.copyWith(
      clearSleepTimerEndsAt: true,
      clearSleepTimerRemaining: true,
    );
  }

  Future<void> loadVoices({String? locale}) async {
    await _ensureInitialized();
    if (state.isLoadingVoices) {
      return;
    }

    final normalizedLocale = _normalizeLocale(locale);
    state = state.copyWith(isLoadingVoices: true);
    try {
      final voices = await _getVoicesForLocale(normalizedLocale);
      var selected = state.selectedVoice;
      if (voices.isNotEmpty &&
          !voices.any((voice) => voice.value == selected)) {
        selected = voices.first.value;
        await setVoice(selected);
      }
      state = state.copyWith(
        availableVoices: voices,
        selectedVoice: selected,
        isLoadingVoices: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingVoices: false);
    }
  }

  Future<void> setVoice(String voice, {String? bookId}) async {
    await _ensureInitialized();
    final trimmed = voice.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _ttsService.setVoice(trimmed);
    if (bookId != null && bookId.trim().isNotEmpty) {
      _bookVoiceAssignments[bookId] = trimmed;
    }
    await _prefs.setString(AppConstants.keyTtsSelectedVoice, trimmed);
    await _saveBookVoiceMap(_prefs);
    state = state.copyWith(selectedVoice: trimmed);
  }

  Future<void> warmUpVoicesForBooks(List<Book> books) async {
    await _ensureInitialized();
    final locales = books
        .map((book) => inferLocaleForBook(book))
        .toSet()
        .toList();
    if (locales.isEmpty) {
      locales.add('zh-CN');
    }

    for (final locale in locales) {
      await _getVoicesForLocale(locale);
    }
    _assignVoicesForBooks(books);
    await _saveBookVoiceMap(_prefs);
  }

  Future<void> selectVoiceForBook(Book book, {String? sampleText}) async {
    await _ensureInitialized();
    final locale = inferLocaleForBook(book, sampleText: sampleText);
    final voices = await _getVoicesForLocale(locale);
    final assigned = _bookVoiceAssignments[book.id];
    if (assigned != null && voices.any((voice) => voice.value == assigned)) {
      _log(
        'selectVoiceForBook: using persisted book voice. bookId=${book.id}, voice=$assigned',
      );
      await setVoice(assigned);
      state = state.copyWith(availableVoices: voices);
      return;
    }

    if (voices.isNotEmpty) {
      final selected = _resolvePreferredVoice(book, voices);
      _log(
        'selectVoiceForBook: resolved voice. bookId=${book.id}, '
        'locale=$locale, voice=$selected',
      );
      _bookVoiceAssignments[book.id] = selected;
      await setVoice(selected);
      state = state.copyWith(availableVoices: voices);
    }
  }

  void refreshCurrentBook(Book book) {
    final currentBook = state.currentBook;
    if (currentBook == null || currentBook.id != book.id) {
      return;
    }

    state = state.copyWith(currentBook: book);
    final chapterTitle = state.chapterQueue
        .where((item) => item.index == state.currentChapterIndex)
        .map((item) => item.title.trim())
        .firstWhere((title) => title.isNotEmpty, orElse: () => '');
    _ttsService.setMediaContext(
      TtsMediaContext(
        id: book.id,
        title: book.title,
        author: book.author,
        coverPath: book.coverPath,
        chapterTitle: chapterTitle.isEmpty ? null : chapterTitle,
      ),
    );
  }

  String inferLocaleForBook(Book book, {String? sampleText}) {
    final raw = [sampleText ?? '', book.title, book.author ?? ''].join(' ');
    return _inferLocaleFromText(raw);
  }

  Future<List<TtsVoice>> _getVoicesForLocale(String? locale) async {
    final key = _normalizeLocale(locale);
    final cached = _localeVoicesCache[key];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    final voices = await _ttsService.fetchVoices(locale: key);
    _localeVoicesCache[key] = voices;
    return voices;
  }

  void _assignVoicesForBooks(List<Book> books) {
    for (final book in books) {
      final locale = inferLocaleForBook(book);
      final voices = _localeVoicesCache[locale];
      if (voices == null || voices.isEmpty) {
        continue;
      }
      final persisted = _bookVoiceAssignments[book.id];
      if (persisted != null &&
          voices.any((voice) => voice.value == persisted)) {
        continue;
      }
      _bookVoiceAssignments[book.id] = _resolvePreferredVoice(book, voices);
    }
  }

  String _pickVoiceForBook(Book book, List<TtsVoice> voices) {
    if (voices.length == 1) {
      return voices.first.value;
    }
    final idx = book.id.hashCode.abs() % voices.length;
    return voices[idx].value;
  }

  String _resolvePreferredVoice(Book book, List<TtsVoice> voices) {
    final current = state.selectedVoice.trim();
    if (current.isNotEmpty && voices.any((voice) => voice.value == current)) {
      return current;
    }
    return _pickVoiceForBook(book, voices);
  }

  String _normalizeLocale(String? locale) {
    final trimmed = locale?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'zh-CN';
    }
    return trimmed;
  }

  String _inferLocaleFromText(String text) {
    if (text.isEmpty) {
      return 'zh-CN';
    }
    final zhChars = RegExp(r'[\u4E00-\u9FFF]').allMatches(text).length;
    final jaChars = RegExp(r'[\u3040-\u30FF]').allMatches(text).length;
    final koChars = RegExp(r'[\uAC00-\uD7AF]').allMatches(text).length;
    final latinChars = RegExp(r'[A-Za-z]').allMatches(text).length;

    if (zhChars >= jaChars && zhChars >= koChars && zhChars > latinChars) {
      return 'zh-CN';
    }
    if (jaChars > zhChars && jaChars > koChars) {
      return 'ja-JP';
    }
    if (koChars > zhChars && koChars > jaChars) {
      return 'ko-KR';
    }
    if (latinChars > 0) {
      return 'en-US';
    }
    return 'zh-CN';
  }

  void _loadPersistedBookVoiceMap(SharedPreferences prefs) {
    final raw = prefs.getString(AppConstants.keyTtsBookVoiceMap);
    if (raw == null || raw.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      _bookVoiceAssignments
        ..clear()
        ..addEntries(
          decoded.entries
              .map(
                (entry) => MapEntry(
                  entry.key.toString(),
                  (entry.value ?? '').toString(),
                ),
              )
              .where(
                (entry) =>
                    entry.key.trim().isNotEmpty &&
                    entry.value.trim().isNotEmpty,
              ),
        );
    } catch (_) {
      // ignore malformed persisted map
    }
  }

  Future<void> _saveBookVoiceMap(SharedPreferences prefs) async {
    if (_bookVoiceAssignments.isEmpty) {
      await prefs.remove(AppConstants.keyTtsBookVoiceMap);
      return;
    }
    await prefs.setString(
      AppConstants.keyTtsBookVoiceMap,
      jsonEncode(_bookVoiceAssignments),
    );
    _log('book voice map persisted: count=${_bookVoiceAssignments.length}');
  }

  void _log(String message) {
    debugPrint('[TtsNotifier] $message');
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _sleepTimerTicker?.cancel();
    _ttsService.dispose();
    super.dispose();
  }
}

final ttsProvider = StateNotifierProvider<TtsNotifier, TtsAppState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return TtsNotifier(prefs);
});
