import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/song.dart';
import '../services/audio_capture_service.dart';
import '../services/upload_service.dart';

enum CaptureState { idle, starting, listening, error }

class AppProvider extends ChangeNotifier {
  final AudioCaptureService _captureService;

  CaptureState _captureState = CaptureState.idle;
  CaptureState get captureState => _captureState;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final List<RecognizedSong> _history = [];
  List<RecognizedSong> get history => List.unmodifiable(_history);

  RecognizedSong? _latestRecognition;
  RecognizedSong? get latestRecognition => _latestRecognition;

  List<Song> _songs = [];
  List<Song> get songs => List.unmodifiable(_songs);

  // Playback state
  Song? _currentSong;
  Song? get currentSong => _currentSong;

  // Server settings
  String _serverUrl = AppConstants.defaultServerUrl;
  String _recognizePath = AppConstants.defaultRecognizePath;
  String _songsPath = AppConstants.defaultSongsPath;

  String get serverUrl => _serverUrl;
  String get recognizePath => _recognizePath;
  String get songsPath => _songsPath;

  UploadService? _uploadService;

  StreamSubscription? _chunkSub;
  StreamSubscription? _errorSub;

  bool _shizukuAvailable = false;
  bool get shizukuAvailable => _shizukuAvailable;

  AppProvider(this._captureService) {
    _init();
  }

  Future<void> _init() async {
    await _loadSettings();
    _shizukuAvailable = await _captureService.isShizukuAvailable();
    _uploadService = UploadService(
      serverUrl: _serverUrl,
      recognizePath: _recognizePath,
    );

    _chunkSub = _captureService.chunkStream.listen(_onChunk);
    _errorSub = _captureService.errorStream.listen(_onError);

    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(AppConstants.prefServerUrl) ?? AppConstants.defaultServerUrl;
    _recognizePath = prefs.getString(AppConstants.prefRecognizePath) ?? AppConstants.defaultRecognizePath;
    _songsPath = prefs.getString(AppConstants.prefSongsPath) ?? AppConstants.defaultSongsPath;
  }

  Future<void> saveSettings({
    required String serverUrl,
    required String recognizePath,
    required String songsPath,
  }) async {
    _serverUrl = serverUrl;
    _recognizePath = recognizePath;
    _songsPath = songsPath;
    _uploadService = UploadService(serverUrl: serverUrl, recognizePath: recognizePath);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefServerUrl, serverUrl);
    await prefs.setString(AppConstants.prefRecognizePath, recognizePath);
    await prefs.setString(AppConstants.prefSongsPath, songsPath);
    notifyListeners();
  }

  Future<void> toggleCapture() async {
    if (_captureState == CaptureState.listening) {
      await stopCapture();
    } else {
      await startCapture();
    }
  }

  Future<void> startCapture() async {
    _captureState = CaptureState.starting;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check Shizuku is available and permitted
      if (!await _captureService.isShizukuAvailable()) {
        _setError('Shizuku is not running. Please install and start the Shizuku app.');
        return;
      }
      if (!await _captureService.isShizukuPermissionGranted()) {
        await _captureService.requestShizukuPermission();
        // Permission result comes via stream — show a message
        _setError('Please grant SonicLens permission in Shizuku, then try again.');
        return;
      }

      await _captureService.startCapture();
      _captureState = CaptureState.listening;
    } catch (e) {
      _setError(e.toString());
    }
    notifyListeners();
  }

  Future<void> stopCapture() async {
    await _captureService.stopCapture();
    _captureState = CaptureState.idle;
    notifyListeners();
  }

  Future<void> _onChunk(Uint8List wavData) async {
    // Fire and forget recognition — don't await to avoid blocking stream
    _recognize(wavData);
  }

  Future<void> _recognize(Uint8List wavData) async {
    try {
      final song = await _uploadService?.recognizeChunk(wavData);
      if (song != null) {
        _latestRecognition = song;
        _history.insert(0, song);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Recognition error: $e');
    }
  }

  void _onError(String message) {
    _setError(message);
  }

  void _setError(String message) {
    _errorMessage = message;
    _captureState = CaptureState.error;
    notifyListeners();
  }

  Future<void> loadSongs() async {
    try {
      _songs = await (_uploadService?.fetchSongs(_songsPath) ?? Future.value([]));
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading songs: $e');
    }
  }

  void setCurrentSong(Song? song) {
    _currentSong = song;
    notifyListeners();
  }

  @override
  void dispose() {
    _chunkSub?.cancel();
    _errorSub?.cancel();
    _captureService.dispose();
    super.dispose();
  }
}