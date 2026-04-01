import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/song.dart';
import '../services/audio_capture_service.dart';
import '../services/mic_capture_service.dart';
import '../services/api_service.dart';
import '../models/trending.dart';

enum CaptureState { idle, starting, listening, error }

enum CaptureBackend { shizuku, microphone }

class AppProvider extends ChangeNotifier {
  final AudioCaptureService _shizukuService;
  final MicCaptureService _micService = MicCaptureService();

  // ── Capture state ─────────────────────────────────────────────────────────
  CaptureState _captureState = CaptureState.idle;
  CaptureState get captureState => _captureState;

  CaptureBackend _backend = CaptureBackend.shizuku;
  CaptureBackend get backend => _backend;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _shizukuAvailable = false;
  bool get shizukuAvailable => _shizukuAvailable;

  // ── Recognition history ───────────────────────────────────────────────────
  final List<RecognizedSong> _history = [];
  List<RecognizedSong> get history => List.unmodifiable(_history);

  RecognizedSong? _latestRecognition;
  RecognizedSong? get latestRecognition => _latestRecognition;

  // ── Library / search ──────────────────────────────────────────────────────
  List<Song> _songs = [];
  List<Song> get songs => List.unmodifiable(_songs);

  List<Song> _searchResults = [];
  List<Song> get searchResults => List.unmodifiable(_searchResults);

  bool _searching = false;
  bool get searching => _searching;

  TrendingResponse? _trending;
  TrendingResponse? get trending => _trending;

  bool _loadingTrending = false;
  bool get loadingTrending => _loadingTrending;

  Song? _currentSong;
  Song? get currentSong => _currentSong;


  // ── Auth ──────────────────────────────────────────────────────────────────
  String? _authToken;
  String? get authToken => _authToken;
  bool get isLoggedIn => _authToken != null && _authToken!.isNotEmpty;

  // ── API ───────────────────────────────────────────────────────────────────
  ApiService get _api =>
      ApiService(baseUrl: AppConstants.baseUrl, authToken: _authToken);

  StreamSubscription? _shizukuChunkSub;
  StreamSubscription? _shizukuErrorSub;
  StreamSubscription? _micChunkSub;
  StreamSubscription? _micErrorSub;

  AppProvider(this._shizukuService) {
    _init();
  }

  Future<void> _init() async {
    await _loadSettings();

    if (AudioCaptureService.isSupported) {
      _shizukuAvailable = await _shizukuService.isShizukuAvailable();
      _backend = _shizukuAvailable
          ? CaptureBackend.shizuku
          : CaptureBackend.microphone;
      _shizukuChunkSub = _shizukuService.chunkStream.listen(_onChunk);
      _shizukuErrorSub = _shizukuService.errorStream.listen(_onError);
    } else {
      _backend = CaptureBackend.microphone;
    }

    // Always listen to mic — used when backend is microphone or Shizuku unavailable
    _micChunkSub = _micService.chunkStream.listen(_onChunk);
    _micErrorSub = _micService.errorStream.listen(_onError);

    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.prefAuthToken);
    if (token != null && _isTokenExpired(token)) {
      debugPrint('⚠️ Stored auth token expired — clearing');
      await prefs.remove(AppConstants.prefAuthToken);
      _authToken = null;
    } else {
      _authToken = token;
    }
  }

  /// Returns true if [token] is a JWT whose [exp] claim is in the past.
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = base64Url.normalize(parts[1]);
      final map = jsonDecode(utf8.decode(base64Url.decode(payload))) as Map<String, dynamic>;
      final exp = map['exp'] as int?;
      if (exp == null) return false;
      return DateTime.now().millisecondsSinceEpoch ~/ 1000 >= exp;
    } catch (_) {
      return true;
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<String?> login(String email, String password) async {
    final token = await _api.login(email, password);
    if (token != null) {
      _authToken = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefAuthToken, token);
      notifyListeners();
    }
    return token;
  }

  Future<bool> register(String username, String password, String email) =>
      _api.register(username, password, email);

  Future<void> logout() async {
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefAuthToken);
    notifyListeners();
  }

  // ── Capture ───────────────────────────────────────────────────────────────

  void switchBackend(CaptureBackend b) {
    if (_captureState == CaptureState.listening) return;
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
    debugPrint('🎵 onChunk: ${wavData.lengthInBytes} bytes — sending to API');
    _saveChunkForDebug(wavData);
    _recognize(wavData);
  }

  /// Saves the latest captured chunk to external storage for manual inspection.
  /// Overwrites the same file each time — check it with a file manager.
  Future<void> _saveChunkForDebug(Uint8List data) async {
    try {
      final dir = await getExternalStorageDirectory();
      final file = File('${dir!.path}/capture_latest.wav');
      await file.writeAsBytes(data);
      debugPrint('💾 Chunk saved to ${file.path}');
    } catch (e) {
      debugPrint('⚠️ Could not save chunk: $e');
    }
  }

  Future<void> _recognize(Uint8List wavData) async {
    if (_authToken == null || _isTokenExpired(_authToken!)) {
      debugPrint('⚠️ Token expired — please log in again');
      await logout();
      _setError('Session expired. Please log in again.');
      return;
    }
    try {
      final song = await _api.recognizeChunk(wavData);
      if (song != null) {
        debugPrint('✅ Recognized: ${song.title} by ${song.artist}');
        _latestRecognition = song;
        _history.insert(0, song);
        notifyListeners();
      } else {
        debugPrint('ℹ️ No match found for this chunk');
      }
    } catch (e) {
      debugPrint('❌ Recognition error: $e');
    }
  }

  // ── Library ───────────────────────────────────────────────────────────────

  Future<void> loadTrending() async {
    _loadingTrending = true;
    notifyListeners();
    _trending = await _api.fetchTrending();
    _loadingTrending = false;
    notifyListeners();
  }

  Future<void> loadSongs() async {
    _songs = await _api.fetchSongs();
    notifyListeners();
  }

  Future<void> searchSongs(String query) async {
    _searching = true;
    notifyListeners();
    _searchResults = await _api.searchSongs(query);
    _searching = false;
    notifyListeners();
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  Future<void> loadHistory() async {
    final serverHistory = await _api.fetchHistory();
    if (serverHistory.isNotEmpty) {
      _history
        ..clear()
        ..addAll(serverHistory);
      notifyListeners();
    }
  }

  void setCurrentSong(Song? song) {
    _currentSong = song;
    notifyListeners();
  }

  void _onError(String message) => _setError(message);

  void _setError(String message) {
    _errorMessage = message;
    _captureState = CaptureState.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _shizukuChunkSub?.cancel();
    _shizukuErrorSub?.cancel();
    _micChunkSub?.cancel();
    _micErrorSub?.cancel();
    _shizukuService.dispose();
    _micService.dispose();
    super.dispose();
  }
}