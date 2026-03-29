import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

/// Wraps the native MethodChannel + EventChannel for audio capture.
/// Android-only feature — all methods return safe no-op defaults on other platforms.
class AudioCaptureService {
  static final _method = MethodChannel(AppConstants.methodChannel);
  static final _events = EventChannel(AppConstants.eventChannel);

  StreamSubscription? _subscription;
  final _chunkController = StreamController<Uint8List>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _shizukuPermissionController = StreamController<bool>.broadcast();

  Stream<Uint8List> get chunkStream => _chunkController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<bool> get shizukuPermissionStream => _shizukuPermissionController.stream;

  bool _isListening = false;
  bool get isListening => _isListening;

  /// Whether audio capture is supported on the current platform.
  static bool get isSupported => defaultTargetPlatform == TargetPlatform.android;

  AudioCaptureService();

  /// Subscribe to the EventChannel. Called lazily on first capture so the
  /// native StreamHandler is guaranteed to be registered by then.
  void _ensureSubscribed() {
    if (_subscription != null || !isSupported) return;
    _subscription = _events.receiveBroadcastStream().listen(_onEvent);
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String?;
    switch (type) {
      case 'chunk':
        final data = event['data'];
        if (data is Uint8List) _chunkController.add(data);
      case 'error':
        final msg = event['message'] as String? ?? 'Unknown error';
        _errorController.add(msg);
      case 'shizuku_permission':
        final granted = event['granted'] as bool? ?? false;
        _shizukuPermissionController.add(granted);
    }
  }

  Future<bool> isShizukuAvailable() async {
    if (!isSupported) return false;
    try {
      return await _method.invokeMethod<bool>('isShizukuAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> isShizukuPermissionGranted() async {
    if (!isSupported) return false;
    try {
      return await _method.invokeMethod<bool>('isShizukuPermissionGranted') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> requestShizukuPermission() async {
    if (!isSupported) return;
    try {
      await _method.invokeMethod('requestShizukuPermission');
    } on MissingPluginException {
      // no-op on unsupported platforms
    }
  }

  Future<void> startCapture() async {
    if (!isSupported) return;
    _ensureSubscribed();
    try {
      await _method.invokeMethod('startCapture');
      _isListening = true;
    } on MissingPluginException {
      // no-op
    }
  }

  Future<void> stopCapture() async {
    if (!isSupported) return;
    try {
      await _method.invokeMethod('stopCapture');
    } on MissingPluginException {
      // no-op
    }
    _isListening = false;
  }

  void dispose() {
    _subscription?.cancel();
    _chunkController.close();
    _errorController.close();
    _shizukuPermissionController.close();
  }
}