import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/song.dart';
import '../services/audio_capture_service.dart';
import '../services/mic_capture_service.dart';
import '../services/upload_service.dart';

enum CaptureState { idle, starting, listening, error }

/// Which capture backend is currently active.
enum CaptureBackend { shizuku, microphone }

class AppProvider extends ChangeNotifier {
  final AudioCaptureService _shizukuService;
  final MicCaptureService _micService = MicCaptureService();

  CaptureState _captureState = CaptureState.idle;
  CaptureState get captureState => _captureState;

  CaptureBackend _backend = CaptureBackend.shizuku;
  /// Which backend is active (or will be used on next start).
  CaptureBackend get backend => _backend;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final List<RecognizedSong> _history = [];
  List<RecognizedSong> get history => List.unmodifiable(_history);

  RecognizedSong? _latestRecognition;
  RecognizedSong? get latestRecognition => _latestRecognition;

  List<Song> _songs = [];
  List<Song> get songs => List.unmodifiable(_songs);

  Song? _currentSong;
  Song? get currentSong => _currentSong;

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

  AppProvider(this._shizukuService) {
    _init();
  }

  Future<void> _init() async {
    await _loadSettings();
    _uploadService = UploadService(
      serverUrl: _serverUrl,
      recognizePath: _recognizePath,
    );

    if (AudioCaptureService.isSupported) {
      _shizukuAvailable = await _shizukuService.isShizukuAvailable();
      // Default to Shizuku on Android if available, else mic
      _backend = _shizukuAvailable
          ? CaptureBackend.shizuku
          : CaptureBackend.microphone;

      _chunkSub = _shizukuService.chunkStream.listen(_onChunk);
      _errorSub = _shizukuService.errorStream.listen(_onError);
    } else {
      // iOS — always use microphone
      _backend = CaptureBackend.microphone;
    }

    // Wire mic service streams regardless of platform
    _chunkSub ??= _micService.chunkStream.listen(_onChunk);
    _errorSub ??= _micService.errorStream.listen(_onError);

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

  /// On Android, lets the user switch between Shizuku and mic backends.
  void switchBackend(CaptureBackend b) {
    if (_captureState == CaptureState.listening) return; // can't switch while running
    _backend = b;
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
      if (_backend == CaptureBackend.microphone) {
        await _startMicCapture();
      } else {
        await _startShizukuCapture();
      }
    } catch (e) {
      _setError(e.toString());
    }
    notifyListeners();
  }

  Future<void> _startMicCapture() async {
    if (!await _micService.hasPermission()) {
      _setError('Microphone permission denied. Please allow access in Settings.');
      return;
    }
    await _micService.start();
    _captureState = CaptureState.listening;
  }

  Future<void> _startShizukuCapture() async {
    if (!await _shizukuService.isShizukuAvailable()) {
      _setError('Shizuku is not running. Please install and start the Shizuku app.');
      return;
    }
    if (!await _shizukuService.isShizukuPermissionGranted()) {
      await _shizukuService.requestShizukuPermission();
      _setError('Please grant SonicLens permission in Shizuku, then try again.');
      return;
    }
    await _shizukuService.startCapture();
    _captureState = CaptureState.listening;
  }

  Future<void> stopCapture() async {
    if (_backend == CaptureBackend.microphone) {
      await _micService.stop();
    } else {
      await _shizukuService.stopCapture();
    }
    _captureState = CaptureState.idle;
    notifyListeners();
  }

  void _onChunk(Uint8List wavData) {
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

  void _onError(String message) => _setError(message);

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
    _shizukuService.dispose();
    _micService.dispose();
    super.dispose();
  }
}