package com.example.sonic_lens_flutter

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import rikka.shizuku.Shizuku
import rikka.shizuku.ShizukuProvider

/**
 * Main activity. Sets up Flutter ↔ native platform channels:
 *
 * MethodChannel "com.sonicLens/audio":
 *   - startCapture()  → starts foreground service + Shizuku capture
 *   - stopCapture()   → stops everything
 *   - isShizukuAvailable() → checks Shizuku status
 *   - requestShizukuPermission() → asks user to grant permission
 *
 * EventChannel "com.sonicLens/audio_events":
 *   - Streams Map<String, dynamic> with keys:
 *     - "type": "chunk" | "error"
 *     - "data": Uint8List (WAV bytes) for chunks
 *     - "message": String for errors
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val TAG = "SonicLensMain"
        private const val METHOD_CHANNEL = "com.sonicLens/audio"
        private const val EVENT_CHANNEL = "com.sonicLens/audio_events"
        private const val SHIZUKU_PERMISSION_CODE = 42
        private const val RECORD_AUDIO_CODE = 43
    }

    private var eventSink: EventChannel.EventSink? = null

    private val shizukuPermissionListener = object : Shizuku.OnRequestPermissionResultListener {
        override fun onRequestPermissionResult(requestCode: Int, grantResult: Int) {
            if (requestCode == SHIZUKU_PERMISSION_CODE) {
                val granted = grantResult == PackageManager.PERMISSION_GRANTED
                eventSink?.success(mapOf("type" to "shizuku_permission", "granted" to granted))
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Shizuku.addRequestPermissionResultListener(shizukuPermissionListener)

        // Wire up service callbacks → EventChannel
        AudioForegroundService.onAudioChunk = { wavData, sampleRate, channels ->
            runOnUiThread {
                eventSink?.success(mapOf(
                    "type" to "chunk",
                    "data" to wavData,
                    "sampleRate" to sampleRate,
                    "channels" to channels
                ))
            }
        }
        AudioForegroundService.onError = { msg ->
            runOnUiThread {
                eventSink?.success(mapOf("type" to "error", "message" to msg))
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel — control commands from Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startCapture" -> {
                        requestAudioPermissionThenStart(result)
                    }
                    "stopCapture" -> {
                        stopForegroundService()
                        result.success(null)
                    }
                    "isShizukuAvailable" -> {
                        val available = try { Shizuku.pingBinder() } catch (e: Exception) { false }
                        result.success(available)
                    }
                    "isShizukuPermissionGranted" -> {
                        val granted = try {
                            if (Shizuku.isPreV11() || Shizuku.getVersion() < 11) {
                                checkSelfPermission(ShizukuProvider.PERMISSION) == PackageManager.PERMISSION_GRANTED
                            } else {
                                Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
                            }
                        } catch (e: Exception) { false }
                        result.success(granted)
                    }
                    "requestShizukuPermission" -> {
                        try {
                            Shizuku.requestPermission(SHIZUKU_PERMISSION_CODE)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SHIZUKU_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // EventChannel — audio chunks streamed to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun requestAudioPermissionThenStart(result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(android.Manifest.permission.RECORD_AUDIO),
                RECORD_AUDIO_CODE
            )
            // Will start after permission granted via onRequestPermissionsResult
            pendingMethodResult = result
        } else {
            startForegroundServiceCapture()
            result.success(null)
        }
    }

    private var pendingMethodResult: MethodChannel.Result? = null

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == RECORD_AUDIO_CODE) {
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
                startForegroundServiceCapture()
                pendingMethodResult?.success(null)
            } else {
                pendingMethodResult?.error("PERMISSION_DENIED", "RECORD_AUDIO permission denied", null)
            }
            pendingMethodResult = null
        }
    }

    private fun startForegroundServiceCapture() {
        val intent = Intent(this, AudioForegroundService::class.java).apply {
            action = AudioForegroundService.ACTION_START
        }
        ContextCompat.startForegroundService(this, intent)
    }

    private fun stopForegroundService() {
        val intent = Intent(this, AudioForegroundService::class.java).apply {
            action = AudioForegroundService.ACTION_STOP
        }
        startService(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        Shizuku.removeRequestPermissionResultListener(shizukuPermissionListener)
        AudioForegroundService.onAudioChunk = null
        AudioForegroundService.onError = null
    }
}