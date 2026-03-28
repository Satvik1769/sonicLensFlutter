class AppConstants {
  // Platform channel names — must match MainActivity.kt
  static const methodChannel = 'com.sonicLens/audio';
  static const eventChannel = 'com.sonicLens/audio_events';

  // SharedPreferences keys
  static const prefServerUrl = 'server_url';
  static const prefRecognizePath = 'recognize_path';
  static const prefSongsPath = 'songs_path';

  // Defaults — user configures their own server in Settings
  static const defaultServerUrl = 'http://192.168.1.100:8000';
  static const defaultRecognizePath = '/recognize';
  static const defaultSongsPath = '/songs';

  // Audio
  static const chunkDurationSeconds = 20;
}