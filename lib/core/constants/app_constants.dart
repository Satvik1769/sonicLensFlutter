class AppConstants {
  // Platform channel names — must match MainActivity.kt
  static const methodChannel = 'com.sonicLens/audio';
  static const eventChannel = 'com.sonicLens/audio_events';

  // SharedPreferences keys
  static const prefServerUrl = 'server_url';
  static const prefRecognizePath = 'recognize_path';
  static const prefSongsPath = 'songs_path';

  static const defaultServerUrl = 'http://136.115.126.210:8082';
  static const defaultRecognizePath = '/recognize';
  static const defaultSongsPath = '/songs';

  // Audio
  static const chunkDurationSeconds = 20;
}