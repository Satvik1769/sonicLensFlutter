import 'dart:async';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

/// Wraps the native MethodChannel + EventChannel for audio capture.
/// Communicates with MainActivity.kt → AudioForegroundService → Shizuku UserService.
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

  AudioCaptureService() {
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
    try {
      return await _method.invokeMethod<bool>('isShizukuAvailable') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isShizukuPermissionGranted() async {
    try {
      return await _method.invokeMethod<bool>('isShizukuPermissionGranted') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestShizukuPermission() async {
    await _method.invokeMethod('requestShizukuPermission');
  }

  Future<void> startCapture() async {
    await _method.invokeMethod('startCapture');
    _isListening = true;
  }

  Future<void> stopCapture() async {
    await _method.invokeMethod('stopCapture');
    _isListening = false;
  }

  void dispose() {
    _subscription?.cancel();
    _chunkController.close();
    _errorController.close();
    _shizukuPermissionController.close();
  }
}