import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myreader/data/services/tts_service.dart';

class TtsAppState {
  final bool isSpeaking;
  final bool isPaused;
  final String? currentText;
  final double speechRate;
  final double pitch;
  final double volume;

  const TtsAppState({
    this.isSpeaking = false,
    this.isPaused = false,
    this.currentText,
    this.speechRate = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
  });

  TtsAppState copyWith({
    bool? isSpeaking,
    bool? isPaused,
    String? currentText,
    double? speechRate,
    double? pitch,
    double? volume,
  }) {
    return TtsAppState(
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isPaused: isPaused ?? this.isPaused,
      currentText: currentText ?? this.currentText,
      speechRate: speechRate ?? this.speechRate,
      pitch: pitch ?? this.pitch,
      volume: volume ?? this.volume,
    );
  }
}

class TtsNotifier extends StateNotifier<TtsAppState> {
  final TtsService _ttsService;

  TtsNotifier() : _ttsService = TtsService(), super(const TtsAppState()) {
    _ttsService.setStateCallback((ttsState) {
      switch (ttsState) {
        case TtsState.playing:
          state = state.copyWith(isSpeaking: true, isPaused: false);
          break;
        case TtsState.paused:
          state = state.copyWith(isSpeaking: false, isPaused: true);
          break;
        case TtsState.stopped:
          state = state.copyWith(
            isSpeaking: false,
            isPaused: false,
            currentText: null,
          );
          break;
      }
    });
  }

  Future<void> speak(String text) async {
    try {
      await _ttsService.speak(text);
      state = state.copyWith(
        isSpeaking: true,
        currentText: text,
        isPaused: false,
      );
    } catch (e) {
      state = state.copyWith(isSpeaking: false);
    }
  }

  Future<void> stop() async {
    try {
      await _ttsService.stop();
      state = state.copyWith(
        isSpeaking: false,
        isPaused: false,
        currentText: null,
      );
    } catch (e) {
      // Handle error
    }
  }

  Future<void> pause() async {
    try {
      await _ttsService.pause();
      state = state.copyWith(isSpeaking: false, isPaused: true);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> resume() async {
    try {
      await _ttsService.resume();
      state = state.copyWith(isSpeaking: true, isPaused: false);
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
}

final ttsProvider = StateNotifierProvider<TtsNotifier, TtsAppState>((ref) {
  return TtsNotifier();
});
