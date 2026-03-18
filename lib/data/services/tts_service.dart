import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:myreader/core/constants/app_constants.dart';
import 'package:myreader/core/models/tts_chapter_payload.dart';
import 'package:path_provider/path_provider.dart';

enum TtsState { playing, stopped, paused }

enum _TtsEngine { none, cloud, local }

class _CloudChunkPlan {
  final String text;
  final int chapterIndex;
  final int chapterLength;
  final int chapterOffsetStart;
  final int chapterOffsetEnd;

  const _CloudChunkPlan({
    required this.text,
    required this.chapterIndex,
    required this.chapterLength,
    required this.chapterOffsetStart,
    required this.chapterOffsetEnd,
  });
}

class TtsMediaContext {
  final String id;
  final String title;
  final String? author;
  final String? coverPath;
  final String? chapterTitle;

  const TtsMediaContext({
    required this.id,
    required this.title,
    this.author,
    this.coverPath,
    this.chapterTitle,
  });
}

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
  StreamSubscription<Duration>? _playerPositionSubscription;
  StreamSubscription<int?>? _playerIndexSubscription;
  Timer? _fallbackProgressTimer;
  final Stopwatch _playbackStopwatch = Stopwatch();
  void Function(TtsState state)? _stateCallback;
  void Function(double progress)? _progressCallback;
  void Function(int? start, int? end)? _segmentCallback;
  void Function(int chapterIndex, int chapterLength)? _chapterChangedCallback;
  bool Function()? _completionCallback;
  bool _ignoreNextNativeStop = false;
  bool _isAudioSessionActive = false;

  TtsState _state = TtsState.stopped;
  _TtsEngine _activeEngine = _TtsEngine.none;
  String? _currentText;
  double _speechRate = 1.0;
  double _pitch = 1.0;
  double _volume = 1.0;
  String _selectedVoice = AppConstants.ttsVoice;
  DateTime? _cloudRetryAfter;
  int _estimatedDurationMs = 0;
  double _lastProgressValue = 0.0;
  DateTime? _lastActualProgressAt;
  int _playbackGeneration = 0;
  final List<String> _cloudTempFilePaths = <String>[];
  final Map<String, String> _cloudPrefetchCache = <String, String>{};
  final List<String> _cloudPrefetchTempFilePaths = <String>[];
  List<_CloudChunkPlan> _cloudChunkPlans = const <_CloudChunkPlan>[];
  List<int> _cloudChunkLengths = const <int>[];
  int _cloudQueuedCount = 0;
  bool _cloudBufferWasLow = false;
  int _lastLoggedCloudPositionMs = -1;
  final Set<HttpClient> _activeCloudClients = <HttpClient>{};
  int? _lastReportedCloudChapterIndex;
  bool _isContinuousChapterQueue = false;
  TtsMediaContext? _mediaContext;
  Map<int, String> _chapterTitlesByIndex = const <int, String>{};

  TtsService() {
    _log(
      'init: baseUrl="${AppConstants.ttsBaseUrl}", '
      'voice="${AppConstants.ttsVoice}", '
      'tokenConfigured=${AppConstants.ttsToken.trim().isNotEmpty}',
    );
    unawaited(_configureAudioSession());
    _playerStateSubscription = _player.playerStateStream.listen(
      _handlePlayerState,
    );
    _playerPositionSubscription = _player.positionStream.listen(
      _handleCloudProgress,
    );
    _playerIndexSubscription = _player.currentIndexStream.listen((index) {
      _log(
        'cloud player index changed: index=$index, '
        'positionMs=${_player.position.inMilliseconds}, '
        'durationMs=${_player.duration?.inMilliseconds ?? -1}, '
        'processingState=${_player.processingState}, '
        'playing=${_player.playing}',
      );
      _reportCloudChapterForCurrentIndex(index);
      _reportCloudSegmentForCurrentIndex(index);
    });
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

  Future<void> _configureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      _log('audio session configured for speech playback.');
    } catch (e, st) {
      _log('audio session configure failed: $e');
      developer.log(
        'TtsService audio session configure error',
        name: 'TtsService',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _logAudioSessionDiagnostics(String context, Object error) async {
    try {
      final session = await AudioSession.instance;
      final config = session.configuration;
      final devices = await session.getDevices();
      _log(
        'audio session diagnostics: context=$context, error=$error, '
        'isConfigured=${session.isConfigured}, '
        'configuration=${config?.toJson()}, '
        'devices=${devices.map((d) => d.type).toList()}',
      );
    } catch (e) {
      _log('audio session diagnostics failed: context=$context, error=$e');
    }
  }

  Future<void> _activateAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
      _isAudioSessionActive = true;
      _log('audio session activated.');
    } catch (e, st) {
      _isAudioSessionActive = false;
      _log('audio session activation failed: $e');
      developer.log(
        'TtsService audio session activation error',
        name: 'TtsService',
        error: e,
        stackTrace: st,
      );
      await _logAudioSessionDiagnostics('activate_failed', e);
    }
  }

  Future<void> _deactivateAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
      _isAudioSessionActive = false;
      _log('audio session deactivated.');
    } catch (e, st) {
      _log('audio session deactivation failed: $e');
      developer.log(
        'TtsService audio session deactivation error',
        name: 'TtsService',
        error: e,
        stackTrace: st,
      );
    }
  }

  TtsState get state => _state;
  String? get currentText => _currentText;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  double get volume => _volume;
  String get selectedVoice => _selectedVoice;

  void setMediaContext(TtsMediaContext? context) {
    _mediaContext = context;
  }

  Future<void> speak(
    String text, {
    bool preserveAudioSession = false,
    List<TtsChapterPayload> chapterQueue = const <TtsChapterPayload>[],
    int? currentChapterIndex,
    int? currentChapterLength,
    bool continuousChapterQueue = false,
  }) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw ArgumentError('TTS text cannot be empty.');
    }

    final generation = ++_playbackGeneration;
    _currentText = trimmedText;
    final canReuseCompletedCloudSession =
        preserveAudioSession &&
        _activeEngine == _TtsEngine.cloud &&
        _player.processingState == ProcessingState.completed;
    if (canReuseCompletedCloudSession) {
      _log(
        'speak: reusing completed cloud session for next chapter, '
        'index=${_player.currentIndex}, '
        'positionMs=${_player.position.inMilliseconds}, '
        'durationMs=${_player.duration?.inMilliseconds ?? -1}',
      );
      _activeEngine = _TtsEngine.none;
      _segmentCallback?.call(null, null);
    } else {
      await _stopActive(
        notifyStopped: false,
        deactivateSession: !preserveAudioSession,
      );
    }
    await _activateAudioSession();
    _progressCallback?.call(0.0);
    _isContinuousChapterQueue = continuousChapterQueue;

    final shouldTryCloud = _shouldTryCloud;
    _log(
      'speak: textLength=${trimmedText.length}, '
      'shouldTryCloud=$shouldTryCloud, '
      'cloudRetryAfter=$_cloudRetryAfter',
    );

    if (shouldTryCloud) {
      final cloudStopwatch = Stopwatch()..start();
      try {
        _log('cloud: attempting synthesis...');
        await _speakWithCloud(
          trimmedText,
          generation: generation,
          chapterQueue: chapterQueue,
          currentChapterIndex: currentChapterIndex,
          currentChapterLength: currentChapterLength,
          continuousChapterQueue: continuousChapterQueue,
        );
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
      _stopProgressTracking(resetProgress: true);
      _setState(TtsState.stopped);
      unawaited(_stopActive(notifyStopped: false));
      _log('local: failed. error=$e');
      rethrow;
    }
  }

  Future<void> stop() async {
    try {
      _playbackGeneration++;
      _resetCloudQueueState();
      await _stopActive(notifyStopped: false);
      await _cleanupCloudTempFiles();
      _currentText = null;
      _activeEngine = _TtsEngine.none;
      _stopProgressTracking(resetProgress: true);
      _setState(TtsState.stopped);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> pause() async {
    try {
      switch (_activeEngine) {
        case _TtsEngine.cloud:
          _log(
            'cloud: pause requested. index=${_player.currentIndex}, '
            'positionMs=${_player.position.inMilliseconds}, '
            'durationMs=${_player.duration?.inMilliseconds ?? -1}, '
            'processingState=${_player.processingState}, '
            'playing=${_player.playing}',
          );
          await _player.pause();
          _log(
            'cloud: pause completed. index=${_player.currentIndex}, '
            'positionMs=${_player.position.inMilliseconds}, '
            'durationMs=${_player.duration?.inMilliseconds ?? -1}, '
            'processingState=${_player.processingState}, '
            'playing=${_player.playing}',
          );
          break;
        case _TtsEngine.local:
          await _channel.invokeMethod('pause');
          break;
        case _TtsEngine.none:
          break;
      }
      _pauseProgressTracking();
      _setState(TtsState.paused);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resume() async {
    try {
      _log(
        'resume entered: activeEngine=$_activeEngine, '
        'hasCurrentText=${_currentText != null && _currentText!.trim().isNotEmpty}, '
        'queuedCount=$_cloudQueuedCount, '
        'audioSourceCount=${_player.audioSources.length}, '
        'index=${_player.currentIndex}, '
        'positionMs=${_player.position.inMilliseconds}, '
        'durationMs=${_player.duration?.inMilliseconds ?? -1}, '
        'processingState=${_player.processingState}, '
        'playing=${_player.playing}',
      );
      switch (_activeEngine) {
        case _TtsEngine.cloud:
          if (_player.audioSources.isEmpty) {
            _log('cloud: resume aborted because playlist is empty.');
            if (_currentText == null || _currentText!.trim().isEmpty) {
              return;
            }
            await speak(_currentText!);
            return;
          }
          _log(
            'cloud: resume requested. index=${_player.currentIndex}, '
            'positionMs=${_player.position.inMilliseconds}, '
            'durationMs=${_player.duration?.inMilliseconds ?? -1}, '
            'processingState=${_player.processingState}, '
            'playing=${_player.playing}',
          );
          await _playCloudWithSession();
          _log(
            'cloud: resume completed. index=${_player.currentIndex}, '
            'positionMs=${_player.position.inMilliseconds}, '
            'durationMs=${_player.duration?.inMilliseconds ?? -1}, '
            'processingState=${_player.processingState}, '
            'playing=${_player.playing}',
          );
          break;
        case _TtsEngine.local:
          if (_currentText == null || _currentText!.trim().isEmpty) {
            _log('local: resume aborted because currentText is empty.');
            return;
          }
          await _channel.invokeMethod('resume');
          break;
        case _TtsEngine.none:
          if (_player.audioSources.isNotEmpty) {
            _log('resume recovering cloud playback from existing playlist.');
            _activeEngine = _TtsEngine.cloud;
            await _playCloudWithSession();
            break;
          }
          if (_currentText == null || _currentText!.trim().isEmpty) {
            _log(
              'resume aborted: no active engine, no playlist, no currentText.',
            );
            return;
          }
          await speak(_currentText!);
          return;
      }
      _resumeProgressTracking();
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

  Future<void> preloadUpcomingText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || AppConstants.ttsBaseUrl.trim().isEmpty) {
      return;
    }
    final chunks = _chunkTextForCloud(trimmed);
    if (chunks.isEmpty) {
      return;
    }
    final headers = _requestHeaders();
    final preloadCount = math.min(2, chunks.length);
    _log(
      'cloud preload: chunkCount=$preloadCount/${chunks.length}, '
      'textLength=${trimmed.length}',
    );
    for (var i = 0; i < preloadCount; i++) {
      final uri = _buildRequestUri(chunks[i]);
      final cacheKey = uri.toString();
      final cachedPath = _cloudPrefetchCache[cacheKey];
      if (cachedPath != null && await File(cachedPath).exists()) {
        _log('cloud preload: chunk ${i + 1} cache hit');
        continue;
      }
      final client = HttpClient();
      final stopwatch = Stopwatch()..start();
      try {
        final request = await client.getUrl(uri);
        if (headers != null) {
          headers.forEach(request.headers.set);
        }
        final response = await request.close().timeout(_cloudTimeout);
        final bytes = await consolidateHttpClientResponseBytes(response);
        stopwatch.stop();
        if (response.statusCode != HttpStatus.ok) {
          _log(
            'cloud preload failed: chunk=${i + 1}/${chunks.length}, '
            'status=${response.statusCode}, elapsedMs=${stopwatch.elapsedMilliseconds}',
          );
          continue;
        }
        final file = await _writeCloudPrefetchFile(bytes, chunkIndex: i);
        _cloudPrefetchCache[cacheKey] = file.path;
        _log(
          'cloud preload ready: chunk=${i + 1}/${chunks.length}, '
          'elapsedMs=${stopwatch.elapsedMilliseconds}, file="${file.path}"',
        );
      } catch (e) {
        stopwatch.stop();
        _log(
          'cloud preload error: chunk=${i + 1}/${chunks.length}, '
          'elapsedMs=${stopwatch.elapsedMilliseconds}, error=$e',
        );
      } finally {
        client.close(force: true);
      }
    }
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

  void setProgressCallback(void Function(double progress) callback) {
    _progressCallback = callback;
  }

  void setSegmentCallback(void Function(int? start, int? end) callback) {
    _segmentCallback = callback;
  }

  void setChapterChangedCallback(
    void Function(int chapterIndex, int chapterLength) callback,
  ) {
    _chapterChangedCallback = callback;
  }

  void setCompletionCallback(bool Function() callback) {
    _completionCallback = callback;
  }

  Future<void> dispose() async {
    _fallbackProgressTimer?.cancel();
    _cancelActiveCloudRequests();
    await _playerStateSubscription?.cancel();
    await _playerPositionSubscription?.cancel();
    await _playerIndexSubscription?.cancel();
    await _player.dispose();
    await _deactivateAudioSession();
    await _cleanupCloudTempFiles();
    await _cleanupCloudPrefetchTempFiles();
  }

  void _handlePlayerState(PlayerState playerState) {
    if (_activeEngine != _TtsEngine.cloud) {
      return;
    }

    _log(
      'cloud player state: playing=${playerState.playing}, '
      'processingState=${playerState.processingState}, '
      'index=${_player.currentIndex}, '
      'positionMs=${_player.position.inMilliseconds}, '
      'durationMs=${_player.duration?.inMilliseconds ?? -1}',
    );

    if (playerState.processingState == ProcessingState.completed) {
      final currentIndex = _player.currentIndex ?? 0;
      final hasFetchedAllChunks = _cloudQueuedCount >= _cloudChunkPlans.length;
      final isPlayingLastChunk = currentIndex >= _cloudChunkPlans.length - 1;

      _log(
        'cloud: completed reached, '
        'index=$currentIndex, '
        'positionMs=${_player.position.inMilliseconds}, '
        'durationMs=${_player.duration?.inMilliseconds ?? -1}, '
        'queuedCount=$_cloudQueuedCount, '
        'chunkCount=${_cloudChunkLengths.length}, '
        'hasFetchedAllChunks=$hasFetchedAllChunks, '
        'isPlayingLastChunk=$isPlayingLastChunk',
      );

      // Only stop if we've fetched all chunks AND playing the last chunk
      if (hasFetchedAllChunks && isPlayingLastChunk) {
        _log('cloud: all chunks played, dispatching stopped.');
        final keepSessionActive = _isContinuousChapterQueue
            ? false
            : _completionCallback?.call() == true;
        _setState(TtsState.stopped);
        _resetCloudQueueState();
        unawaited(_cleanupCloudTempFiles());
        _currentText = null;
        _stopProgressTracking(resetProgress: true);
        if (keepSessionActive) {
          _log(
            'cloud: completion handed off to next chapter, skipping immediate stopActive.',
          );
          return;
        }
        unawaited(_stopActive(notifyStopped: false));
        return;
      }

      // More chunks available - continue fetching and playing
      _log('cloud: more chunks available, continuing playback...');
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
      _setState(TtsState.stopped);
      unawaited(_stopActive(notifyStopped: false));
    }
  }

  Future<void> _handleNativeCallback(MethodCall call) async {
    if (_activeEngine != _TtsEngine.local) {
      _log(
        'native callback ignored: method=${call.method}, '
        'activeEngine=$_activeEngine, args=${call.arguments}',
      );
      return;
    }

    if (call.method == 'onProgress') {
      final args = call.arguments;
      if (args is Map) {
        final position = (args['position'] as num?)?.toDouble() ?? 0.0;
        final total = (args['total'] as num?)?.toDouble() ?? 0.0;
        if (total > 0) {
          _reportProgress((position / total).clamp(0.0, 1.0), isActual: true);
        }
      }
      return;
    }

    final nativeState = call.arguments as String?;
    switch (nativeState) {
      case 'playing':
        _setState(TtsState.playing);
        break;
      case 'paused':
        _pauseProgressTracking();
        _setState(TtsState.paused);
        break;
      case 'stopped':
        if (_ignoreNextNativeStop) {
          _ignoreNextNativeStop = false;
          return;
        }
        final keepSessionActive =
            _state == TtsState.playing && _completionCallback?.call() == true;
        _resetCloudQueueState();
        _segmentCallback?.call(null, null);
        unawaited(_cleanupCloudTempFiles());
        _currentText = null;
        _stopProgressTracking(resetProgress: true);
        _setState(TtsState.stopped);
        if (keepSessionActive) {
          _log(
            'local: completion handed off to next chapter, skipping immediate stopActive.',
          );
          break;
        }
        unawaited(_stopActive(notifyStopped: false));
        break;
    }
  }

  Future<bool> _playCloudWithSession() async {
    await _activateAudioSession();
    try {
      final playFuture = _player.play();
      unawaited(
        playFuture.catchError((Object error, StackTrace stackTrace) async {
          _log('cloud: play future failed. error=$error');
          await _logAudioSessionDiagnostics('play_future_failed', error);
        }),
      );
      return await _waitForCloudPlaybackStart();
    } catch (e) {
      _log('cloud: play failed, retrying after session activate. error=$e');
      await _logAudioSessionDiagnostics('play_failed', e);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _activateAudioSession();
      try {
        final playFuture = _player.play();
        unawaited(
          playFuture.catchError((Object error, StackTrace stackTrace) async {
            _log('cloud: play future retry failed. error=$error');
            await _logAudioSessionDiagnostics(
              'play_future_retry_failed',
              error,
            );
          }),
        );
        return await _waitForCloudPlaybackStart();
      } catch (retryError) {
        _log('cloud: play retry failed. error=$retryError');
        await _logAudioSessionDiagnostics('play_retry_failed', retryError);
        return false;
      }
    }
  }

  Future<bool> _waitForCloudPlaybackStart() async {
    if (_player.position.inMilliseconds > 0) {
      _log(
        'cloud: playback already advancing. '
        'positionMs=${_player.position.inMilliseconds}, '
        'processingState=${_player.processingState}, '
        'playing=${_player.playing}',
      );
      return true;
    }

    final completer = Completer<bool>();
    StreamSubscription<Duration>? positionSubscription;
    StreamSubscription<PlayerState>? stateSubscription;
    Timer? timeoutTimer;

    void complete(bool value, String reason) {
      if (completer.isCompleted) {
        return;
      }
      _log(
        'cloud: playback start wait completed. '
        'success=$value, reason=$reason, '
        'positionMs=${_player.position.inMilliseconds}, '
        'processingState=${_player.processingState}, '
        'playing=${_player.playing}',
      );
      completer.complete(value);
    }

    positionSubscription = _player.positionStream.listen((position) {
      if (position.inMilliseconds > 0) {
        complete(true, 'position_advanced');
      }
    });

    stateSubscription = _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        complete(false, 'completed_before_progress');
      }
    });

    timeoutTimer = Timer(const Duration(seconds: 8), () {
      complete(false, 'start_timeout');
    });

    final started = await completer.future;
    await positionSubscription.cancel();
    await stateSubscription.cancel();
    timeoutTimer.cancel();
    return started;
  }

  void _setState(TtsState nextState) {
    _log(
      'state transition: $_state -> $nextState, '
      'activeEngine=$_activeEngine, '
      'currentTextLength=${_currentText?.length ?? 0}, '
      'index=${_player.currentIndex}, '
      'positionMs=${_player.position.inMilliseconds}, '
      'durationMs=${_player.duration?.inMilliseconds ?? -1}',
    );
    _state = nextState;
    _stateCallback?.call(_state);
  }

  void _beginProgressTracking(String text) {
    _estimatedDurationMs = _estimateDurationMs(text);
    _lastProgressValue = 0.0;
    _lastActualProgressAt = null;
    _playbackStopwatch
      ..stop()
      ..reset()
      ..start();
    _progressCallback?.call(0.0);
    _fallbackProgressTimer?.cancel();
    _fallbackProgressTimer = Timer.periodic(const Duration(milliseconds: 250), (
      _,
    ) {
      if (_state != TtsState.playing || _estimatedDurationMs <= 0) {
        return;
      }
      final lastActualProgressAt = _lastActualProgressAt;
      if (lastActualProgressAt != null &&
          DateTime.now().difference(lastActualProgressAt) <
              const Duration(milliseconds: 900)) {
        return;
      }
      _reportProgress(
        (_playbackStopwatch.elapsedMilliseconds / _estimatedDurationMs).clamp(
          0.0,
          1.0,
        ),
        isActual: false,
      );
    });
  }

  void _pauseProgressTracking() {
    _playbackStopwatch.stop();
  }

  void _resumeProgressTracking() {
    if (!_playbackStopwatch.isRunning) {
      _playbackStopwatch.start();
    }
  }

  void _stopProgressTracking({required bool resetProgress}) {
    _fallbackProgressTimer?.cancel();
    _fallbackProgressTimer = null;
    _playbackStopwatch
      ..stop()
      ..reset();
    _lastActualProgressAt = null;
    _estimatedDurationMs = 0;
    _lastProgressValue = 0.0;
    if (resetProgress) {
      _progressCallback?.call(0.0);
    }
  }

  void _reportProgress(double progress, {required bool isActual}) {
    final safeProgress = progress.clamp(0.0, 1.0);
    if ((safeProgress - _lastProgressValue).abs() < 0.001 && !isActual) {
      return;
    }
    if (isActual) {
      _lastActualProgressAt = DateTime.now();
    }
    _lastProgressValue = safeProgress;
    _progressCallback?.call(safeProgress);
  }

  int _estimateDurationMs(String text) {
    final normalizedLength = math.max(1, text.trim().length);
    final charsPerSecond = 6.0 * _speechRate.clamp(0.5, 2.0);
    final seconds = (normalizedLength / charsPerSecond).clamp(8.0, 4 * 60 * 60);
    return (seconds * 1000).round();
  }

  void _handleCloudProgress(Duration position) {
    if (_activeEngine != _TtsEngine.cloud) {
      return;
    }
    if (!_player.playing) {
      return;
    }
    final positionMs = position.inMilliseconds;
    if (positionMs > 0 &&
        (_lastLoggedCloudPositionMs < 0 ||
            positionMs - _lastLoggedCloudPositionMs >= 3000)) {
      _lastLoggedCloudPositionMs = positionMs;
      _log(
        'cloud progress: positionMs=$positionMs, '
        'durationMs=${_player.duration?.inMilliseconds ?? -1}, '
        'index=${_player.currentIndex}, '
        'processingState=${_player.processingState}',
      );
    }
    _reportProgress(_cloudPlaybackProgress(position), isActual: true);
  }

  double _cloudPlaybackProgress(Duration position) {
    if (_cloudChunkLengths.isEmpty || _cloudQueuedCount <= 0) {
      final total = _player.duration;
      if (total == null || total.inMilliseconds <= 0) {
        return 0.0;
      }
      return (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    }

    final totalChars = _cloudChunkLengths.fold<int>(0, (sum, len) => sum + len);
    if (totalChars <= 0) {
      return 0.0;
    }

    final currentIndex = (_player.currentIndex ?? 0).clamp(
      0,
      _cloudChunkLengths.length - 1,
    );

    var progressedChars = 0.0;
    for (var i = 0; i < currentIndex; i++) {
      progressedChars += _cloudChunkLengths[i];
    }

    final currentChunkChars = _cloudChunkLengths[currentIndex];
    final currentDurationMs = _player.duration?.inMilliseconds ?? 0;
    if (currentDurationMs > 0) {
      final currentChunkProgress = (position.inMilliseconds / currentDurationMs)
          .clamp(0.0, 1.0);
      progressedChars += currentChunkChars * currentChunkProgress;
    }

    return (progressedChars / totalChars).clamp(0.0, 1.0);
  }

  Future<void> _speakWithCloud(
    String text, {
    required int generation,
    required List<TtsChapterPayload> chapterQueue,
    required int? currentChapterIndex,
    required int? currentChapterLength,
    required bool continuousChapterQueue,
  }) async {
    final requestStopwatch = Stopwatch()..start();
    final chunkPlans = _buildCloudChunkPlans(
      text,
      chapterQueue: chapterQueue,
      currentChapterIndex: currentChapterIndex,
      currentChapterLength: currentChapterLength,
      continuousChapterQueue: continuousChapterQueue,
    );
    _cloudChunkPlans = List<_CloudChunkPlan>.unmodifiable(chunkPlans);
    _cloudChunkLengths = List<int>.unmodifiable(
      chunkPlans.map((chunk) => chunk.text.length),
    );
    _chapterTitlesByIndex = <int, String>{
      if (currentChapterIndex != null)
        currentChapterIndex: _mediaContext?.chapterTitle?.trim() ?? '',
      for (final chapter in chapterQueue) chapter.index: chapter.title.trim(),
    };
    final chunks = chunkPlans.map((plan) => plan.text).toList(growable: false);
    _log(
      'cloud request: totalTextLength=${text.length}, '
      'chunkCount=${chunks.length}, '
      'chunkLengths=${chunks.map((e) => e.length).join(",")}, '
      'voice=$_selectedVoice, '
      'rate=${_scalePercent(_speechRate)}, '
      'pitch=${_scalePercent(_pitch)}, '
      'volume=${_scalePercent(_volume)}, '
      'text="${text.replaceAll('"', r'\"')}"',
    );

    _log('cloud: stopping native engine...');
    await _channel.invokeMethod('stop');
    _log('cloud: stopping audio player...');
    await _player.stop();
    _resetCloudQueueState();
    _log('cloud: setting volume=${_volume.toStringAsFixed(2)}');
    await _player.setVolume(_volume);

    final headers = _requestHeaders();
    final firstSource = await _fetchCloudChunkAudioSource(
      chunks.first,
      chunkIndex: 0,
      totalChunks: chunks.length,
      headers: headers,
      generation: generation,
    );

    _log('cloud: setting first remote audio source...');
    await _player.setAudioSources([firstSource]);
    if (!_isPlaybackGenerationActive(generation)) {
      throw StateError('Cloud playback superseded before start.');
    }
    _cloudQueuedCount = 1;
    _activeEngine = _TtsEngine.cloud;
    _progressCallback?.call(0.0);
    _reportCloudChapterForCurrentIndex(0);
    _reportCloudSegmentForCurrentIndex(0);
    await _primeCloudQueueBeforePlayback(
      headers: headers,
      generation: generation,
    );

    if (chunks.length > 1) {
      unawaited(_maintainCloudBuffer(headers: headers, generation: generation));
    }
    requestStopwatch.stop();
    _log(
      'cloud response: first audio source ready, '
      'elapsedMs=${requestStopwatch.elapsedMilliseconds}, '
      'chunkCount=${chunks.length}, '
      'durationMs=${_player.duration?.inMilliseconds ?? -1}',
    );
    _log('cloud: start playback...');
    _beginProgressTracking(text);
    _setState(TtsState.playing);
    final started = await _playCloudWithSession();
    if (!started) {
      throw TimeoutException('Cloud playback did not advance position.');
    }
  }

  Future<void> _primeCloudQueueBeforePlayback({
    required Map<String, String>? headers,
    required int generation,
  }) async {
    if (_cloudQueuedCount >= _cloudChunkPlans.length) {
      return;
    }

    const minQueuedCountBeforePlay = 2;
    const minBufferedCharsBeforePlay = 70;
    final targetQueuedCount = math.min(
      minQueuedCountBeforePlay,
      _cloudChunkPlans.length,
    );

    while (_isPlaybackGenerationActive(generation) &&
        _activeEngine == _TtsEngine.cloud &&
        (_cloudQueuedCount < targetQueuedCount ||
            _bufferedCloudChars() < minBufferedCharsBeforePlay)) {
      final chunkIndex = _cloudQueuedCount;
      if (chunkIndex >= _cloudChunkPlans.length) {
        return;
      }
      final totalChunks = _cloudChunkPlans.length;
      final chunk = _cloudChunkPlans[chunkIndex].text;
      _log(
        'cloud prime: fetch chunk ${chunkIndex + 1}/$totalChunks, '
        'bufferedCharsBefore=${_bufferedCloudChars()}, '
        'queuedBefore=$_cloudQueuedCount/$totalChunks',
      );
      try {
        final source = await _fetchCloudChunkAudioSource(
          chunk,
          chunkIndex: chunkIndex,
          totalChunks: totalChunks,
          headers: headers,
          generation: generation,
        );
        if (!_isPlaybackGenerationActive(generation) ||
            _activeEngine != _TtsEngine.cloud) {
          return;
        }
        final appendStopwatch = Stopwatch()..start();
        await _player.addAudioSource(source);
        appendStopwatch.stop();
        if (!_isPlaybackGenerationActive(generation) ||
            _activeEngine != _TtsEngine.cloud) {
          return;
        }
        _cloudQueuedCount++;
        _log(
          'cloud prime: appended chunk ${chunkIndex + 1}/$totalChunks, '
          'queueAppendElapsedMs=${appendStopwatch.elapsedMilliseconds}, '
          'bufferedCharsAfter=${_bufferedCloudChars()}',
        );
      } catch (e, st) {
        if (!_isPlaybackGenerationActive(generation)) {
          return;
        }
        _log(
          'cloud prime failed: chunk=${chunkIndex + 1}/$totalChunks, error=$e',
        );
        developer.log(
          'TtsService cloud prime failure',
          name: 'TtsService',
          error: e,
          stackTrace: st,
        );
        return;
      }
    }
  }

  Future<void> _maintainCloudBuffer({
    required Map<String, String>? headers,
    required int generation,
  }) async {
    const minQueuedCount = 2;
    const minBufferedChars = 70;
    const targetBufferedChars = 120;
    while (_isPlaybackGenerationActive(generation) &&
        _activeEngine == _TtsEngine.cloud) {
      final bufferedChars = _bufferedCloudChars();
      if (_cloudQueuedCount >= _cloudChunkPlans.length) {
        _log(
          'cloud buffer: queue complete, '
          'bufferedChars=$bufferedChars, '
          'queued=$_cloudQueuedCount/${_cloudChunkPlans.length}',
        );
        return;
      }
      if (_cloudQueuedCount >=
              math.min(minQueuedCount, _cloudChunkPlans.length) &&
          bufferedChars >= minBufferedChars) {
        _cloudBufferWasLow = false;
        await Future<void>.delayed(const Duration(milliseconds: 400));
        continue;
      }

      if (!_cloudBufferWasLow) {
        _log(
          'cloud buffer: low, bufferedChars=$bufferedChars, '
          'queued=$_cloudQueuedCount/${_cloudChunkPlans.length}, fetching more...',
        );
        _cloudBufferWasLow = true;
      }
      while (_isPlaybackGenerationActive(generation) &&
          _activeEngine == _TtsEngine.cloud &&
          _cloudQueuedCount < _cloudChunkPlans.length &&
          (_cloudQueuedCount <
                  math.min(minQueuedCount, _cloudChunkPlans.length) ||
              _bufferedCloudChars() < targetBufferedChars)) {
        final chunkIndex = _cloudQueuedCount;
        final totalChunks = _cloudChunkPlans.length;
        final chunk = _cloudChunkPlans[chunkIndex].text;
        _log(
          'cloud buffer: fetch chunk ${chunkIndex + 1}/$totalChunks, '
          'bufferedCharsBefore=${_bufferedCloudChars()}, '
          'queuedBefore=$_cloudQueuedCount/$totalChunks',
        );
        try {
          final source = await _fetchCloudChunkAudioSource(
            chunk,
            chunkIndex: chunkIndex,
            totalChunks: totalChunks,
            headers: headers,
            generation: generation,
          );
          if (!_isPlaybackGenerationActive(generation) ||
              _activeEngine != _TtsEngine.cloud) {
            return;
          }
          final appendStopwatch = Stopwatch()..start();
          await _player.addAudioSource(source);
          appendStopwatch.stop();
          if (!_isPlaybackGenerationActive(generation) ||
              _activeEngine != _TtsEngine.cloud) {
            return;
          }
          _cloudQueuedCount++;
          _log(
            'cloud response: appended chunk ${chunkIndex + 1}/$totalChunks, '
            'queueAppendElapsedMs=${appendStopwatch.elapsedMilliseconds}, '
            'bufferedCharsAfter=${_bufferedCloudChars()}',
          );
        } catch (e, st) {
          if (!_isPlaybackGenerationActive(generation)) {
            return;
          }
          _log(
            'cloud buffer failed: chunk=${chunkIndex + 1}/$totalChunks, error=$e',
          );
          developer.log(
            'TtsService cloud append failure',
            name: 'TtsService',
            error: e,
            stackTrace: st,
          );
          return;
        }
      }
    }
  }

  int _bufferedCloudChars() {
    if (_cloudQueuedCount <= 0 || _cloudChunkLengths.isEmpty) {
      return 0;
    }
    final currentIndex = (_player.currentIndex ?? 0).clamp(
      0,
      _cloudQueuedCount - 1,
    );
    var bufferedChars = 0.0;
    for (var i = currentIndex; i < _cloudQueuedCount; i++) {
      if (i == currentIndex) {
        final duration = _player.duration;
        final totalMs = duration?.inMilliseconds ?? 0;
        if (totalMs > 0) {
          final progress = (_player.position.inMilliseconds / totalMs).clamp(
            0.0,
            1.0,
          );
          bufferedChars += _cloudChunkLengths[i] * (1.0 - progress);
        } else {
          bufferedChars += _cloudChunkLengths[i];
        }
      } else {
        bufferedChars += _cloudChunkLengths[i];
      }
    }
    return bufferedChars.round();
  }

  void _resetCloudQueueState() {
    _cloudChunkPlans = const <_CloudChunkPlan>[];
    _cloudChunkLengths = const <int>[];
    _cloudQueuedCount = 0;
    _cloudBufferWasLow = false;
    _lastReportedCloudChapterIndex = null;
    _isContinuousChapterQueue = false;
    _chapterTitlesByIndex = const <int, String>{};
  }

  void _cancelActiveCloudRequests() {
    if (_activeCloudClients.isEmpty) {
      return;
    }
    _log('cloud: cancelling ${_activeCloudClients.length} active request(s).');
    for (final client in _activeCloudClients.toList()) {
      client.close(force: true);
    }
    _activeCloudClients.clear();
  }

  Future<AudioSource> _fetchCloudChunkAudioSource(
    String chunk, {
    required int chunkIndex,
    required int totalChunks,
    required Map<String, String>? headers,
    required int generation,
  }) async {
    final uri = _buildRequestUri(chunk);
    final cacheKey = uri.toString();
    final prefetchedPath = _cloudPrefetchCache[cacheKey];
    if (prefetchedPath != null && await File(prefetchedPath).exists()) {
      _log(
        'cloud response: chunk ${chunkIndex + 1}/$totalChunks served from preload, '
        'file="$prefetchedPath"',
      );
      return AudioSource.file(
        prefetchedPath,
        tag: _mediaItemForChunk(chunkIndex, totalChunks),
      );
    }
    final requestStopwatch = Stopwatch()..start();
    _log(
      'cloud request: chunk ${chunkIndex + 1}/$totalChunks, '
      'textLength=${chunk.length}, '
      'bufferedChars=${_bufferedCloudChars()}, '
      'text="${chunk.replaceAll('"', r'\"')}"',
    );

    final client = HttpClient();
    _activeCloudClients.add(client);
    try {
      final request = await client.getUrl(uri);
      if (headers != null) {
        headers.forEach(request.headers.set);
      }
      final response = await request.close().timeout(_cloudTimeout);
      final bytes = await consolidateHttpClientResponseBytes(response);
      requestStopwatch.stop();

      if (response.statusCode != HttpStatus.ok) {
        final body = _decodeResponseBody(bytes);
        _log(
          'cloud response: chunk ${chunkIndex + 1}/$totalChunks failed, '
          'status=${response.statusCode}, '
          'elapsedMs=${requestStopwatch.elapsedMilliseconds}, '
          'body="${body.replaceAll('"', r'\"')}"',
        );
        throw HttpException(
          'Cloud TTS request failed with status ${response.statusCode}',
          uri: uri,
        );
      }

      final file = await _writeCloudChunkToTempFile(
        bytes,
        generation: generation,
        chunkIndex: chunkIndex,
      );
      if (!_isPlaybackGenerationActive(generation)) {
        await _deleteTempFile(file.path);
        throw StateError('Cloud playback superseded during chunk fetch.');
      }

      _log(
        'cloud response: chunk ${chunkIndex + 1}/$totalChunks ready, '
        'status=${response.statusCode}, '
        'elapsedMs=${requestStopwatch.elapsedMilliseconds}, '
        'bytes=${bytes.length}, '
        'bufferedChars=${_bufferedCloudChars()}, '
        'file="${file.path}"',
      );
      return AudioSource.file(
        file.path,
        tag: _mediaItemForChunk(chunkIndex, totalChunks),
      );
    } on Object {
      rethrow;
    } finally {
      _activeCloudClients.remove(client);
      client.close(force: true);
    }
  }

  Future<void> _speakWithLocal(String text) async {
    _log('local: force stopping cloud player before native speak...');
    await _player.stop();
    _resetCloudQueueState();
    _segmentCallback?.call(null, null);
    await _cleanupCloudTempFiles();
    await _channel.invokeMethod('speak', {
      'text': text,
      'rate': _speechRate,
      'pitch': _pitch,
      'volume': _volume,
    });
    _activeEngine = _TtsEngine.local;
    _progressCallback?.call(0.0);
    _beginProgressTracking(text);
    _setState(TtsState.playing);
  }

  MediaItem _mediaItemForChunk(int chunkIndex, int totalChunks) {
    final context = _mediaContext;
    final title = context?.title.trim();
    final plan = (chunkIndex >= 0 && chunkIndex < _cloudChunkPlans.length)
        ? _cloudChunkPlans[chunkIndex]
        : null;
    final chapterTitle =
        _chapterTitlesByIndex[plan?.chapterIndex]?.trim() ??
        context?.chapterTitle?.trim();
    final author = context?.author?.trim();
    final artUri = _artUriFromCoverPath(context?.coverPath);
    final chunkLabel = totalChunks > 1 ? '片段 ${chunkIndex + 1}/$totalChunks' : null;
    final subtitleParts = <String>[
      if (chapterTitle != null && chapterTitle.isNotEmpty) chapterTitle,
      if (chunkLabel != null) chunkLabel,
    ];

    return MediaItem(
      id: '${context?.id ?? 'tts'}:$chunkIndex',
      title: (title != null && title.isNotEmpty) ? title : 'Gravity Reader',
      album: (author != null && author.isNotEmpty) ? author : null,
      artist: subtitleParts.isEmpty ? null : subtitleParts.join(' • '),
      artUri: artUri,
      displayTitle: (title != null && title.isNotEmpty) ? title : 'Gravity Reader',
      displaySubtitle: subtitleParts.isEmpty ? author : subtitleParts.join(' • '),
      displayDescription: (author != null && author.isNotEmpty) ? author : null,
    );
  }

  Uri? _artUriFromCoverPath(String? coverPath) {
    final trimmed = coverPath?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Uri.tryParse(trimmed);
    }
    return Uri.file(trimmed);
  }

  Future<void> _stopActive({
    required bool notifyStopped,
    bool deactivateSession = true,
  }) async {
    final previousEngine = _activeEngine;
    _log(
      'stopActive: activeEngine=$previousEngine, notifyStopped=$notifyStopped',
    );
    _activeEngine = _TtsEngine.none;
    _ignoreNextNativeStop = true;
    _cancelActiveCloudRequests();
    Object? stopError;
    try {
      await _player.stop();
    } catch (e, st) {
      stopError ??= e;
      _log('stopActive: cloud player stop failed: $e');
      developer.log(
        'TtsService stopActive player stop error',
        name: 'TtsService',
        error: e,
        stackTrace: st,
      );
    }
    try {
      await _channel.invokeMethod('stop');
    } catch (e, st) {
      stopError ??= e;
      _log('stopActive: native stop failed: $e');
      developer.log(
        'TtsService stopActive native stop error',
        name: 'TtsService',
        error: e,
        stackTrace: st,
      );
    }
    if (notifyStopped) {
      _setState(TtsState.stopped);
    }
    _segmentCallback?.call(null, null);
    if (deactivateSession) {
      await _deactivateAudioSession();
    }
    if (stopError != null) {
      throw stopError;
    }
  }

  void _reportCloudSegmentForCurrentIndex(int? index) {
    if (_activeEngine != _TtsEngine.cloud || _cloudChunkPlans.isEmpty) {
      _segmentCallback?.call(null, null);
      return;
    }

    final safeIndex = (index ?? 0).clamp(0, _cloudChunkPlans.length - 1);
    final chunkPlan = _cloudChunkPlans[safeIndex];
    _segmentCallback?.call(
      chunkPlan.chapterOffsetStart,
      chunkPlan.chapterOffsetEnd,
    );
  }

  void _reportCloudChapterForCurrentIndex(int? index) {
    if (_activeEngine != _TtsEngine.cloud || _cloudChunkPlans.isEmpty) {
      return;
    }

    final safeIndex = (index ?? 0).clamp(0, _cloudChunkPlans.length - 1);
    final chunkPlan = _cloudChunkPlans[safeIndex];
    if (_lastReportedCloudChapterIndex == chunkPlan.chapterIndex) {
      return;
    }
    _lastReportedCloudChapterIndex = chunkPlan.chapterIndex;
    _log(
      'cloud chapter changed: chapter=${chunkPlan.chapterIndex}, '
      'chunkIndex=$safeIndex, chapterLength=${chunkPlan.chapterLength}',
    );
    _chapterChangedCallback?.call(
      chunkPlan.chapterIndex,
      chunkPlan.chapterLength,
    );
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
    final normalized = _sanitizeCloudText(text);
    if (normalized.isEmpty) {
      return const <String>[];
    }
    final atomicChunks = _splitTextByPunctuation(normalized);
    if (atomicChunks.isEmpty) {
      return <String>[normalized];
    }
    return _groupAtomicChunksForCloud(atomicChunks);
  }

  List<_CloudChunkPlan> _buildCloudChunkPlans(
    String text, {
    required List<TtsChapterPayload> chapterQueue,
    required int? currentChapterIndex,
    required int? currentChapterLength,
    required bool continuousChapterQueue,
  }) {
    final plans = <_CloudChunkPlan>[];

    void appendChapter({
      required String chapterText,
      required int chapterIndex,
      required int chapterLength,
    }) {
      var offset = 0;
      for (final chunk in _chunkTextForCloud(chapterText)) {
        final start = offset;
        final end = start + chunk.length;
        plans.add(
          _CloudChunkPlan(
            text: chunk,
            chapterIndex: chapterIndex,
            chapterLength: chapterLength,
            chapterOffsetStart: start,
            chapterOffsetEnd: end,
          ),
        );
        offset = end;
      }
    }

    appendChapter(
      chapterText: text,
      chapterIndex: currentChapterIndex ?? -1,
      chapterLength: currentChapterLength ?? text.length,
    );

    if (!continuousChapterQueue || currentChapterIndex == null) {
      return plans;
    }

    final currentQueuePos = chapterQueue.indexWhere(
      (item) => item.index == currentChapterIndex,
    );
    if (currentQueuePos < 0) {
      return plans;
    }

    for (var i = currentQueuePos + 1; i < chapterQueue.length; i++) {
      final chapter = chapterQueue[i];
      if (chapter.text.trim().isEmpty) {
        continue;
      }
      appendChapter(
        chapterText: chapter.text,
        chapterIndex: chapter.index,
        chapterLength: chapter.text.length,
      );
    }

    return plans;
  }

  List<String> _splitTextByPunctuation(String text) {
    const separators = <String>[
      '。',
      '！',
      '？',
      '；',
      '，',
      '、',
      '：',
      '.',
      '!',
      '?',
      ';',
      ',',
      ':',
      '\n',
    ];

    final chunks = <String>[];
    final buffer = StringBuffer();
    for (final char in text.split('')) {
      buffer.write(char);
      if (separators.contains(char)) {
        final chunk = buffer.toString().trim();
        if (chunk.isNotEmpty) {
          chunks.add(chunk);
        }
        buffer.clear();
      }
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      chunks.add(tail);
    }
    return chunks;
  }

  List<String> _groupAtomicChunksForCloud(List<String> chunks) {
    if (chunks.isEmpty) {
      return const <String>[];
    }

    const minFirstChunkChars = 24;
    const targetFirstChunkChars = 48;
    const targetNormalChunkChars = 56;
    const maxNormalChunkChars = 72;

    final grouped = <String>[];
    final buffer = StringBuffer();
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final isFirstGroup = grouped.isEmpty;
      final targetChars = isFirstGroup
          ? targetFirstChunkChars
          : targetNormalChunkChars;
      final maxChars = isFirstGroup
          ? targetFirstChunkChars
          : maxNormalChunkChars;

      if (buffer.isEmpty) {
        buffer.write(chunk);
        continue;
      }

      final nextLength = buffer.length + chunk.length;
      final canKeepGrowing = nextLength <= maxChars;
      final shouldCloseCurrent =
          buffer.length >= targetChars || !canKeepGrowing;

      if (shouldCloseCurrent) {
        grouped.add(buffer.toString());
        buffer
          ..clear()
          ..write(chunk);
        continue;
      }

      buffer.write(chunk);
    }

    if (buffer.isNotEmpty) {
      if (grouped.isEmpty &&
          buffer.length < minFirstChunkChars &&
          chunks.length > 1) {
        grouped.add(buffer.toString());
      } else {
        grouped.add(buffer.toString());
      }
    }
    return grouped;
  }

  String _sanitizeCloudText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isPlaybackGenerationActive(int generation) {
    return generation == _playbackGeneration;
  }

  Future<File> _writeCloudChunkToTempFile(
    Uint8List bytes, {
    required int generation,
    required int chunkIndex,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/gravity_reader_tts');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File(
      '${dir.path}/tts_${generation}_${chunkIndex}_${DateTime.now().microsecondsSinceEpoch}.mp3',
    );
    await file.writeAsBytes(bytes, flush: true);
    _cloudTempFilePaths.add(file.path);
    return file;
  }

  Future<File> _writeCloudPrefetchFile(
    Uint8List bytes, {
    required int chunkIndex,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/gravity_reader_tts_prefetch');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File(
      '${dir.path}/prefetch_${chunkIndex}_${DateTime.now().microsecondsSinceEpoch}.mp3',
    );
    await file.writeAsBytes(bytes, flush: true);
    _cloudPrefetchTempFilePaths.add(file.path);
    return file;
  }

  Future<void> _cleanupCloudTempFiles() async {
    if (_cloudTempFilePaths.isEmpty) {
      return;
    }
    final paths = List<String>.from(_cloudTempFilePaths);
    _cloudTempFilePaths.clear();
    for (final path in paths) {
      await _deleteTempFile(path);
    }
  }

  Future<void> _cleanupCloudPrefetchTempFiles() async {
    if (_cloudPrefetchTempFilePaths.isEmpty) {
      return;
    }
    final paths = List<String>.from(_cloudPrefetchTempFilePaths);
    _cloudPrefetchTempFilePaths.clear();
    _cloudPrefetchCache.clear();
    for (final path in paths) {
      await _deleteTempFile(path);
    }
  }

  Future<void> _deleteTempFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  String _decodeResponseBody(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return '<binary:${bytes.length} bytes>';
    }
  }

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final formatted = '[$timestamp] [TtsService] $message';
    debugPrint(formatted);
    developer.log(formatted, name: 'TtsService');
  }
}
