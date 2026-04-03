class AppConstants {
  // Platform channel names — must match MainActivity.kt
  static const methodChannel = 'com.sonicLens/audio';
  static const eventChannel = 'com.sonicLens/audio_events';

  static const prefAuthToken = 'auth_token';
  static const baseUrl = 'http://136.115.126.210:8082';

  // Audio
  static const chunkDurationSeconds = 20;

  // Spotify — fill in your Spotify Developer Dashboard credentials
  static const spotifyClientId = 'ae08ae07d3b14832badc11cc9925fe38';
  static const spotifyRedirectUrl = 'http://34.60.181.59:8082/callback';
}