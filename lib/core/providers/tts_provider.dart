import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/core/constants/app_constants.dart';
import 'package:myreader/data/services/tts_service.dart';
import 'package:myreader/domain/entities/book.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsAppState {
  final bool isSpeaking;
  final bool isPaused;
  final String? currentText;
  final int? currentStartOffset;
  final double playbackProgress;
  final double speechRate;
  final double pitch;
  final double volume;
  final String selectedVoice;
  final List<TtsVoice> availableVoices;
  final bool isLoadingVoices;
  final bool isLoadingAudio;

  const TtsAppState({
    this.isSpeaking = false,
    this.isPaused = false,
    this.currentText,
    this.currentStartOffset,
    this.playbackProgress = 0.0,
    this.speechRate = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
    this.selectedVoice = AppConstants.ttsVoice,
    this.availableVoices = const <TtsVoice>[],
    this.isLoadingVoices = false,
    this.isLoadingAudio = false,
  });

  TtsAppState copyWith({
    bool? isSpeaking,
    bool? isPaused,
    String? currentText,
    bool clearCurrentText = false,
    int? currentStartOffset,
    bool clearCurrentStartOffset = false,
    double? playbackProgress,
    double? speechRate,
    double? pitch,
    double? volume,
    String? selectedVoice,
    List<TtsVoice>? availableVoices,
    bool? isLoadingVoices,
    bool? isLoadingAudio,
  }) {
    return TtsAppState(
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isPaused: isPaused ?? this.isPaused,
      currentText: clearCurrentText ? null : (currentText ?? this.currentText),
      currentStartOffset: clearCurrentStartOffset
          ? null
          : (currentStartOffset ?? this.currentStartOffset),
      playbackProgress: playbackProgress ?? this.playbackProgress,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
      selectedVoice: selectedVoice ?? this.selectedVoice,
      availableVoices: availableVoices ?? this.availableVoices,
      isLoadingVoices: isLoadingVoices ?? this.isLoadingVoices,
      isLoadingAudio: isLoadingAudio ?? this.isLoadingAudio,
    );
  }
}

class TtsNotifier extends StateNotifier<TtsAppState> {
  final TtsService _ttsService;
  final Map<String, List<TtsVoice>> _localeVoicesCache =
      <String, List<TtsVoice>>{};
  final Map<String, String> _bookVoiceAssignments = <String, String>{};
  Future<void>? _initializeFuture;

  TtsNotifier() : _ttsService = TtsService(), super(const TtsAppState()) {
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
          state = state.copyWith(
            isSpeaking: false,
            isPaused: false,
            clearCurrentText: true,
            clearCurrentStartOffset: true,
            playbackProgress: 0.0,
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
    _ttsService.setProgressCallback((progress) {
      state = state.copyWith(playbackProgress: progress.clamp(0.0, 1.0));
    });
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    _initializeFuture ??= _initializeInternal();
    return _initializeFuture!;
  }

  Future<void> _initializeInternal() async {
    final prefs = await SharedPreferences.getInstance();
    final persistedVoice = prefs.getString(AppConstants.keyTtsSelectedVoice);
    final initialVoice =
        (persistedVoice == null || persistedVoice.trim().isEmpty)
        ? AppConstants.ttsVoice
        : persistedVoice.trim();

    await _ttsService.setVoice(initialVoice);
    state = state.copyWith(selectedVoice: initialVoice);
    _loadPersistedBookVoiceMap(prefs);
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

  Future<void> speak(String text, {int? startOffset}) async {
    _trace('speak: textLength=${text.length}, selectedVoice=${state.selectedVoice}');
    state = state.copyWith(
      isSpeaking: false,
      isPaused: false,
      isLoadingAudio: true,
      playbackProgress: 0.0,
      currentText: text,
      currentStartOffset: startOffset,
    );
    try {
      await _ttsService.setVoice(state.selectedVoice);
      await _ttsService.speak(text);
      state = state.copyWith(
        isSpeaking: true,
        currentText: text,
        currentStartOffset: startOffset,
        playbackProgress: 0.0,
        isPaused: false,
        isLoadingAudio: false,
      );
    } catch (e) {
      state = state.copyWith(isSpeaking: false, isLoadingAudio: false);
    }
  }

  Future<void> stop() async {
    try {
      _trace('stop');
      await _ttsService.stop();
      state = state.copyWith(
        isSpeaking: false,
        isPaused: false,
        clearCurrentText: true,
        clearCurrentStartOffset: true,
        playbackProgress: 0.0,
        isLoadingAudio: false,
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyTtsSelectedVoice, trimmed);
    await _saveBookVoiceMap(prefs);
    state = state.copyWith(selectedVoice: trimmed);
  }

  Future<void> warmUpVoicesForBooks(List<Book> books) async {
    await _ensureInitialized();
    final locales = books
        .map((book) => inferLocaleForBook(book))
        .toSet()
        .toList(growable: false);
    if (locales.isEmpty) {
      locales.add('zh-CN');
    }

    for (final locale in locales) {
      await _getVoicesForLocale(locale);
    }
    _assignVoicesForBooks(books);
    final prefs = await SharedPreferences.getInstance();
    await _saveBookVoiceMap(prefs);
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
    _ttsService.dispose();
    super.dispose();
  }
}

final ttsProvider = StateNotifierProvider<TtsNotifier, TtsAppState>((ref) {
  return TtsNotifier();
});
