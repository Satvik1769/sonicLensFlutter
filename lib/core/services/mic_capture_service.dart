import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Microphone-based audio capture for iOS (and Android without Shizuku).
/// Records 20-second WAV chunks via the device microphone.
///
/// On iOS this is how Shazam itself works — hold the phone near the source.
/// On Android this is the fallback if Shizuku isn't available.
class MicCaptureService {
  static const _chunkSeconds = 20;

  final _recorder = AudioRecorder();
  final _chunkController = StreamController<Uint8List>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<Uint8List> get chunkStream => _chunkController.stream;
  Stream<String> get errorStream => _errorController.stream;

  bool _running = false;
  bool get isRunning => _running;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    if (_running) return;
    if (!await _recorder.hasPermission()) {
      _errorController.add('Microphone permission denied.');
      return;
    }
    _running = true;
    _loop();
  }

  Future<void> stop() async {
    _running = false;
    try {
      await _recorder.stop();
    } catch (_) {}
  }

  Future<void> _loop() async {
    while (_running) {
      try {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/sonic_chunk_${DateTime.now().millisecondsSinceEpoch}.wav';

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 44100,
            numChannels: 1, // mono is enough for recognition
            bitRate: 128000,
          ),
          path: path,
        );

        // Record for 20 seconds
        await Future.delayed(const Duration(seconds: _chunkSeconds));

        if (!_running) {
          await _recorder.stop();
          _cleanupFile(path);
          break;
        }

        await _recorder.stop();

        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          debugPrint('🎤 Mic chunk ready: ${bytes.lengthInBytes} bytes');
          _chunkController.add(bytes);
          _cleanupFile(path);
        } else {
          debugPrint('⚠️ Mic chunk file not found: $path');
        }
      } catch (e) {
        debugPrint('MicCaptureService error: $e');
        _errorController.add('Microphone capture error: $e');
        await Future.delayed(const Duration(seconds: 2)); // brief pause before retry
      }
    }
  }

  void _cleanupFile(String path) {
    File(path).delete().catchError((_) => File(path));
  }

  void dispose() {
    _running = false;
    _recorder.dispose();
    _chunkController.close();
    _errorController.close();
  }
}