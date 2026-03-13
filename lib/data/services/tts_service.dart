import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:myreader/core/constants/app_constants.dart';

enum TtsState { playing, stopped, paused }

enum _TtsEngine { none, cloud, local }

class TtsVoice {
  final String value;
  final String label;
  final String locale;
  final String gender;
  final String? nameZh;
  final String? nameEn;
  final List<String> traitsZh;
  final List<String> traitsEn;
  final List<String> categoriesZh;
  final List<String> categoriesEn;

  const TtsVoice({
    required this.value,
    required this.label,
    required this.locale,
    required this.gender,
    this.nameZh,
    this.nameEn,
    this.traitsZh = const <String>[],
    this.traitsEn = const <String>[],
    this.categoriesZh = const <String>[],
    this.categoriesEn = const <String>[],
  });

  factory TtsVoice.fromJson(Map<String, dynamic> json) {
    final names = (json['names'] is Map)
        ? Map<String, dynamic>.from(json['names'] as Map)
        : const <String, dynamic>{};
    final characteristics = (json['characteristics'] is Map)
        ? Map<String, dynamic>.from(json['characteristics'] as Map)
        : const <String, dynamic>{};
    final personalities = (characteristics['personalities'] is Map)
        ? Map<String, dynamic>.from(characteristics['personalities'] as Map)
        : const <String, dynamic>{};
    final categories = (characteristics['categories'] is Map)
        ? Map<String, dynamic>.from(characteristics['categories'] as Map)
        : const <String, dynamic>{};
    final traitsZh = (personalities['zh'] is List)
        ? List<String>.from(personalities['zh'] as List)
        : const <String>[];
    final traitsEn = (personalities['en'] is List)
        ? List<String>.from(personalities['en'] as List)
        : const <String>[];
    final categoriesZh = (categories['zh'] is List)
        ? List<String>.from(categories['zh'] as List)
        : const <String>[];
    final categoriesEn = (categories['en'] is List)
        ? List<String>.from(categories['en'] as List)
        : const <String>[];

    return TtsVoice(
      value: (json['value'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      locale: (json['locale'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      nameZh: names['zh']?.toString(),
      nameEn: names['en']?.toString(),
      traitsZh: traitsZh,
      traitsEn: traitsEn,
      categoriesZh: categoriesZh,
      categoriesEn: categoriesEn,
    );
  }

  List<String> localizedTraits(String languageCode) {
    final isZh = languageCode.toLowerCase().startsWith('zh');
    final values = isZh
        ? <String>[...traitsZh, ...categoriesZh]
        : <String>[...traitsEn, ...categoriesEn];
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  String localizedName(String languageCode) {
    final isZh = languageCode.toLowerCase().startsWith('zh');
    if (isZh && nameZh != null && nameZh!.trim().isNotEmpty) {
      return nameZh!.trim();
    }
    if (!isZh && nameEn != null && nameEn!.trim().isNotEmpty) {
      return nameEn!.trim();
    }
    return label.trim().isNotEmpty ? label.trim() : value.trim();
  }
}

class TtsService {
  static const MethodChannel _channel = MethodChannel('myreader/tts');

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  void Function(TtsState state)? _stateCallback;

  TtsState _state = TtsState.stopped;
  _TtsEngine _activeEngine = _TtsEngine.none;
  String? _currentText;
  double _speechRate = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;
  String _selectedVoice = AppConstants.ttsVoice;
  DateTime? _cloudRetryAfter;

  TtsService() {
    _log(
      'init: baseUrl="${AppConstants.ttsBaseUrl}", '
      'voice="${AppConstants.ttsVoice}", '
      'tokenConfigured=${AppConstants.ttsToken.trim().isNotEmpty}',
    );
    _playerStateSubscription = _player.playerStateStream.listen(
      _handlePlayerState,
    );
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        _log('cloud player error: $error');
        developer.log(
          'TtsService playbackEventStream error',
          name: 'TtsService',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  TtsState get state => _state;
  String? get currentText => _currentText;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  double get volume => _volume;
  String get selectedVoice => _selectedVoice;

  Future<void> speak(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw ArgumentError('TTS text cannot be empty.');
    }

    _currentText = trimmedText;
    await _stopActive(notifyStopped: false);

    final shouldTryCloud = _shouldTryCloud;
    _log(
      'speak: textLength=${trimmedText.length}, '
      'shouldTryCloud=$shouldTryCloud, '
      'cloudRetryAfter=$_cloudRetryAfter',
    );

    if (shouldTryCloud) {
      final cloudStopwatch = Stopwatch()..start();
      try {
        _log(
          'cloud: attempting synthesis... timeout=${_cloudTimeout.inMilliseconds}ms',
        );
        await _speakWithCloud(trimmedText).timeout(_cloudTimeout);
        cloudStopwatch.stop();
        _markCloudHealthy();
        _log(
          'cloud: playback started. elapsedMs=${cloudStopwatch.elapsedMilliseconds}',
        );
        return;
      } catch (e, st) {
        cloudStopwatch.stop();
        _log(
          'cloud: failed, fallback to local. elapsedMs=${cloudStopwatch.elapsedMilliseconds}, error=$e',
        );
        developer.log(
          'TtsService cloud failure stack',
          name: 'TtsService',
          error: e,
          stackTrace: st,
        );
        _markCloudUnavailable();
      }
    } else {
      _log('cloud: skipped.');
    }

    try {
      _log('local: attempting native TTS...');
      await _speakWithLocal(trimmedText);
      _log('local: playback started.');
    } catch (e) {
      _currentText = null;
      _activeEngine = _TtsEngine.none;
      _setState(TtsState.stopped);
      _log('local: failed. error=$e');
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      await _stopActive(notifyStopped: false);
      _currentText = null;
      _activeEngine = _TtsEngine.none;
      _setState(TtsState.stopped);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      switch (_activeEngine) {
        case _TtsEngine.cloud:
          await _player.pause();
          break;
        case _TtsEngine.local:
          await _channel.invokeMethod('pause');
          break;
        case _TtsEngine.none:
          break;
      }
      _setState(TtsState.paused);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resume() async {
    try {
      if (_currentText == null || _currentText!.trim().isEmpty) {
        return;
      }
      switch (_activeEngine) {
        case _TtsEngine.cloud:
          unawaited(_player.play());
          break;
        case _TtsEngine.local:
          await _channel.invokeMethod('resume');
          break;
        case _TtsEngine.none:
          await speak(_currentText!);
          return;
      }
      _setState(TtsState.playing);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 2.0);
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  Future<void> setVoice(String voice) async {
    final trimmed = voice.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _selectedVoice = trimmed;
    _log('voice set: $_selectedVoice');
  }

  Future<List<TtsVoice>> fetchVoices({String? locale}) async {
    final configuredBaseUrl = AppConstants.ttsBaseUrl.trim();
    if (configuredBaseUrl.isEmpty) {
      _log('fetchVoices skipped: TTS_BASE_URL is empty.');
      return const <TtsVoice>[];
    }

    final normalizedBaseUrl = configuredBaseUrl.endsWith('/')
        ? configuredBaseUrl
        : '$configuredBaseUrl/';
    final baseUri = Uri.parse(normalizedBaseUrl);
    final requestUri = baseUri
        .resolve('api/voices')
        .replace(
          queryParameters: locale == null || locale.trim().isEmpty
              ? null
              : <String, String>{'locale': locale.trim()},
        );
    _log('fetchVoices: requestUri=$requestUri');

    final client = HttpClient();
    try {
      final request = await client.getUrl(requestUri);
      final headers = _requestHeaders();
      if (headers != null) {
        headers.forEach(request.headers.set);
      }
      final response = await request.close().timeout(_cloudTimeout);
      final body = await utf8.decodeStream(response);
      if (response.statusCode != HttpStatus.ok) {
        _log('fetchVoices failed: status=${response.statusCode}, body=$body');
        return const <TtsVoice>[];
      }

      final parsed = jsonDecode(body);
      if (parsed is! List) {
        _log('fetchVoices failed: response is not a list.');
        return const <TtsVoice>[];
      }

      final voices = parsed
          .whereType<Map>()
          .map((raw) => TtsVoice.fromJson(Map<String, dynamic>.from(raw)))
          .where((voice) => voice.value.trim().isNotEmpty)
          .toList(growable: false);
      _log('fetchVoices success: count=${voices.length}');
      return voices;
    } catch (e, st) {
      _log('fetchVoices error: $e');
      developer.log(
        'TtsService fetchVoices error',
        name: 'TtsService',
        error: e,
        stackTrace: st,
      );
      return const <TtsVoice>[];
    } finally {
      client.close(force: true);
    }
  }

  void setStateCallback(void Function(TtsState state) callback) {
    _stateCallback = callback;
  }

  Future<void> dispose() async {
    await _playerStateSubscription?.cancel();
    await _player.dispose();
  }

  void _handlePlayerState(PlayerState playerState) {
    if (_activeEngine != _TtsEngine.cloud) {
      return;
    }

    if (playerState.processingState == ProcessingState.completed) {
      _currentText = null;
      _activeEngine = _TtsEngine.none;
      _setState(TtsState.stopped);
      return;
    }

    if (playerState.playing) {
      _setState(TtsState.playing);
      return;
    }

    if (_state == TtsState.paused && !playerState.playing) {
      _stateCallback?.call(TtsState.paused);
      return;
    }

    if (playerState.processingState == ProcessingState.idle &&
        _currentText == null) {
      _activeEngine = _TtsEngine.none;
      _setState(TtsState.stopped);
    }
  }

  Future<void> _handleNativeCallback(MethodCall call) async {
    if (_activeEngine != _TtsEngine.local || call.method != 'onStateChange') {
      return;
    }

    final nativeState = call.arguments as String?;
    switch (nativeState) {
      case 'playing':
        _setState(TtsState.playing);
        break;
      case 'paused':
        _setState(TtsState.paused);
        break;
      case 'stopped':
        _currentText = null;
        _activeEngine = _TtsEngine.none;
        _setState(TtsState.stopped);
        break;
    }
  }

  void _setState(TtsState nextState) {
    _state = nextState;
    _stateCallback?.call(_state);
  }

  Future<void> _speakWithCloud(String text) async {
    final chunks = _chunkTextForCloud(text);
    _log(
      'cloud: chunked request count=${chunks.length}, '
      'chunkLengths=${chunks.map((e) => e.length).join(",")}',
    );

    _log('cloud: stopping native engine...');
    await _channel.invokeMethod('stop');
    _log('cloud: stopping audio player...');
    await _player.stop();
    _log('cloud: setting volume=${_volume.toStringAsFixed(2)}');
    await _player.setVolume(_volume);

    final headers = _requestHeaders();
    final children = <AudioSource>[];
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final uri = _buildRequestUri(chunk);
      _log(
        'cloud: chunk ${i + 1}/${chunks.length}, textLength=${chunk.length}, '
        'urlLength=${uri.toString().length}',
      );
      _log('cloud: chunkText="${chunk.replaceAll('"', r'\"')}"');
      children.add(AudioSource.uri(uri, headers: headers));
    }

    _log('cloud: setting remote audio source...');
    if (children.length == 1) {
      await _player.setAudioSource(children.first);
    } else {
      await _player.setAudioSources(children);
    }
    _log('cloud: audio source set, start playback...');
    _activeEngine = _TtsEngine.cloud;
    _setState(TtsState.playing);
    unawaited(_player.play());
  }

  Future<void> _speakWithLocal(String text) async {
    await _player.stop();
    await _channel.invokeMethod('speak', {
      'text': text,
      'rate': _speechRate,
      'pitch': _pitch,
      'volume': _volume,
    });
    _activeEngine = _TtsEngine.local;
    _setState(TtsState.playing);
  }

  Future<void> _stopActive({required bool notifyStopped}) async {
    switch (_activeEngine) {
      case _TtsEngine.cloud:
        await _player.stop();
        break;
      case _TtsEngine.local:
        await _channel.invokeMethod('stop');
        break;
      case _TtsEngine.none:
        break;
    }

    if (notifyStopped) {
      _setState(TtsState.stopped);
    }
  }

  bool get _shouldTryCloud {
    if (AppConstants.ttsBaseUrl.trim().isEmpty) {
      _log('cloud disabled: TTS_BASE_URL is empty.');
      return false;
    }
    final retryAfter = _cloudRetryAfter;
    return retryAfter == null || DateTime.now().isAfter(retryAfter);
  }

  Duration get _cloudTimeout =>
      Duration(milliseconds: _resolveCloudTimeoutMs());

  Duration get _cloudRetryCooldown =>
      Duration(milliseconds: AppConstants.ttsCloudRetryCooldownMs);

  int _resolveCloudTimeoutMs() {
    final baseMs = AppConstants.ttsCloudTimeoutMs;
    final textLength = _currentText?.length ?? 0;
    const maxCharsPerChunk = 220;
    // For multi-chunk cloud playback, source preparation time scales roughly
    // with chunk count. Use chunk-based timeout to avoid false local fallback.
    final chunkCountEstimate = math.max(
      1,
      (textLength / maxCharsPerChunk).ceil(),
    );
    final extraMs = chunkCountEstimate * 10000; // 10s per estimated chunk
    final totalMs = baseMs + extraMs;
    return totalMs.clamp(baseMs, 180000);
  }

  void _markCloudUnavailable() {
    _cloudRetryAfter = DateTime.now().add(_cloudRetryCooldown);
    _log('cloud marked unavailable until $_cloudRetryAfter');
    _activeEngine = _TtsEngine.none;
  }

  void _markCloudHealthy() {
    if (_cloudRetryAfter != null) {
      _log('cloud recovered.');
    }
    _cloudRetryAfter = null;
  }

  Uri _buildRequestUri(String text) {
    final configuredBaseUrl = AppConstants.ttsBaseUrl.trim();
    if (configuredBaseUrl.isEmpty) {
      throw StateError('Missing TTS_BASE_URL dart-define.');
    }

    final normalizedBaseUrl = configuredBaseUrl.endsWith('/')
        ? configuredBaseUrl
        : '$configuredBaseUrl/';
    final baseUri = Uri.parse(normalizedBaseUrl);
    final requestUri = baseUri.resolve('api/text-to-speech');

    final sanitizedText = _sanitizeCloudText(text);
    return requestUri.replace(
      queryParameters: <String, String>{
        'voice': _selectedVoice,
        'text': sanitizedText,
        'rate': _scalePercent(_speechRate).toString(),
        'pitch': _scalePercent(_pitch).toString(),
        'volume': _scalePercent(_volume).toString(),
      },
    );
  }

  Map<String, String>? _requestHeaders() {
    final token = AppConstants.ttsToken.trim();
    if (token.isEmpty) {
      _log('cloud request: no auth token.');
      return null;
    }
    _log('cloud request: using bearer token.');
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  int _scalePercent(double value) {
    final scaled = ((value - 1.0) * 100).round();
    return scaled.clamp(-100, 100);
  }

  List<String> _chunkTextForCloud(String text) {
    const firstChunkMaxChars = 80;
    const firstChunkFallbackChars = 60;
    const normalChunkMaxChars = 180;
    const normalChunkMinSplitSearchStart = 70;
    final normalized = _sanitizeCloudText(text);
    if (normalized.length <= firstChunkMaxChars) {
      return <String>[normalized];
    }

    final chunks = <String>[];
    var remaining = normalized;
    var isFirstChunk = true;
    while (true) {
      final maxChars = isFirstChunk ? firstChunkMaxChars : normalChunkMaxChars;
      if (remaining.length <= maxChars) {
        break;
      }

      final window = remaining.substring(0, maxChars);
      final splitAt = isFirstChunk
          ? _findFirstChunkSplit(window, firstChunkFallbackChars)
          : _findChunkSplit(window, normalChunkMinSplitSearchStart);
      final chunk = remaining.substring(0, splitAt).trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }
      remaining = remaining.substring(splitAt).trimLeft();
      isFirstChunk = false;
    }

    if (remaining.isNotEmpty) {
      chunks.add(remaining);
    }
    return chunks;
  }

  int _findFirstChunkSplit(String window, int fallbackChars) {
    // First chunk: prioritize first sentence end to start playback ASAP,
    // even when it's very short.
    const strongSentenceEndings = <String>['。', '！', '？', '.', '!', '?'];
    for (var i = 0; i < window.length; i++) {
      final ch = window[i];
      if (strongSentenceEndings.contains(ch)) {
        return i + 1;
      }
    }

    // If no sentence ending, try a weaker pause boundary.
    const softBoundaries = <String>['；', ';', '，', '、', ',', '\n'];
    for (var i = 0; i < window.length; i++) {
      final ch = window[i];
      if (softBoundaries.contains(ch) && i + 1 >= 10) {
        return i + 1;
      }
    }

    // Fallback: a short chunk for fast first audio.
    return fallbackChars.clamp(20, window.length);
  }

  int _findChunkSplit(String window, int minIndex) {
    const separators = <String>[
      '。',
      '！',
      '？',
      '；',
      '.',
      '!',
      '?',
      ';',
      '，',
      '、',
      ',',
      '\n',
    ];

    var splitAt = -1;
    for (final sep in separators) {
      final idx = window.lastIndexOf(sep);
      if (idx >= minIndex && idx + 1 > splitAt) {
        splitAt = idx + 1;
      }
    }

    if (splitAt <= 0) {
      return window.length;
    }
    return splitAt;
  }

  String _sanitizeCloudText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _log(String message) {
    debugPrint('[TtsService] $message');
    developer.log(message, name: 'TtsService');
  }
}
