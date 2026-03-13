class AppConstants {
  static const String appName = 'MyReader';
  static const String appVersion = '1.0.0';
  static const packageName = 'com.myreader.app';
  static const String databaseName = 'myreader.db';
  static const int databaseVersion = 1;
  static const String keySettings = 'app_settings';
  static const String keyTtsSelectedVoice = 'tts_selected_voice';
  static const String keyTtsBookVoiceMap = 'tts_book_voice_map_v1';
  static const int pageSizeDefault = 12;

  static const String ttsBaseUrl = String.fromEnvironment(
    'TTS_BASE_URL',
    defaultValue: 'http://192.168.2.40:3000',
  );
  static const String ttsVoice = String.fromEnvironment(
    'TTS_VOICE',
    defaultValue:
        'Microsoft Server Speech Text to Speech Voice (zh-CN, XiaoxiaoNeural)',
  );
  static const String ttsToken = String.fromEnvironment('TTS_TOKEN');
  static const int ttsCloudTimeoutMs = int.fromEnvironment(
    'TTS_CLOUD_TIMEOUT_MS',
    defaultValue: 8000,
  );
  static const int ttsCloudRetryCooldownMs = int.fromEnvironment(
    'TTS_CLOUD_RETRY_COOLDOWN_MS',
    defaultValue: 30000,
  );
}
