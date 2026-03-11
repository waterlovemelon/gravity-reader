import 'package:flutter/services.dart';

enum TtsState { playing, stopped, paused }

class TtsService {
  static const MethodChannel _channel = MethodChannel('myreader/tts');

  TtsState _state = TtsState.stopped;
  String? _currentText;
  double _speechRate = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;

  TtsState get state => _state;
  String? get currentText => _currentText;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  double get volume => _volume;

  Future<void> speak(String text) async {
    try {
      _currentText = text;
      _state = TtsState.playing;
      await _channel.invokeMethod('speak', {
        'text': text,
        'rate': _speechRate,
        'pitch': _pitch,
        'volume': _volume,
      });
    } catch (e) {
      _state = TtsState.stopped;
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
      _state = TtsState.stopped;
      _currentText = null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
      _state = TtsState.paused;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resume() async {
    try {
      await _channel.invokeMethod('resume');
      _state = TtsState.playing;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 2.0);
    try {
      await _channel.invokeMethod('setSpeechRate', {'rate': _speechRate});
    } catch (e) {
      // Silently fail for rate setting
    }
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    try {
      await _channel.invokeMethod('setPitch', {'pitch': _pitch});
    } catch (e) {
      // Silently fail for pitch setting
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    try {
      await _channel.invokeMethod('setVolume', {'volume': _volume});
    } catch (e) {
      // Silently fail for volume setting
    }
  }

  void setStateCallback(void Function(TtsState state) callback) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onStateChange') {
        final state = call.arguments as String;
        switch (state) {
          case 'playing':
            _state = TtsState.playing;
            break;
          case 'stopped':
            _state = TtsState.stopped;
            _currentText = null;
            break;
          case 'paused':
            _state = TtsState.paused;
            break;
        }
        callback(_state);
      }
    });
  }
}
