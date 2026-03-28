package com.example.sonic_lens_flutter

import android.app.*
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import rikka.shizuku.Shizuku

/**
 * Android Foreground Service that keeps audio capture alive even when
 * the app is in the background. Shows a persistent notification.
 *
 * Binds to ShizukuAudioUserService for privileged audio capture.
 */
class AudioForegroundService : Service() {

    companion object {
        private const val TAG = "AudioForegroundSvc"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "sonic_lens_capture"

        const val ACTION_START = "com.example.sonic_lens_flutter.START_CAPTURE"
        const val ACTION_STOP = "com.example.sonic_lens_flutter.STOP_CAPTURE"

        // Shared between service and MainActivity for delivering chunks to Flutter
        var onAudioChunk: ((ByteArray, Int, Int) -> Unit)? = null
        var onError: ((String) -> Unit)? = null
    }

    private var audioCaptureService: IAudioCaptureService? = null
    private var userServiceBound = false

    private val userServiceArgs by lazy {
        Shizuku.UserServiceArgs(
            ComponentName(packageName, ShizukuAudioUserService::class.java.name)
        )
            .daemon(false)
            .processNameSuffix("audio_capture")
            .debuggable(false)
            .version(1)
    }

    private val userServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            Log.d(TAG, "Shizuku UserService connected")
            audioCaptureService = IAudioCaptureService.Stub.asInterface(binder)
            userServiceBound = true

            audioCaptureService?.setCallback(object : IAudioCaptureCallback.Stub() {
                override fun onAudioChunk(data: ByteArray, sampleRate: Int, channels: Int) {
                    // Encode PCM → WAV and forward to Flutter
                    val wavData = WavEncoder.encode(data, sampleRate, channels)
                    onAudioChunk?.invoke(wavData, sampleRate, channels)
                }

                override fun onError(message: String) {
                    Log.e(TAG, "Capture error: $message")
                    onError?.invoke(message)
                }
            })

            audioCaptureService?.startCapture()
        }

        override fun onServiceDisconnected(name: android.content.ComponentName?) {
            Log.d(TAG, "Shizuku UserService disconnected")
            userServiceBound = false
            audioCaptureService = null
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startCapture()
            ACTION_STOP -> stopCapture()
        }
        return START_STICKY
    }

    private fun startCapture() {
        startForeground(NOTIFICATION_ID, buildNotification("Listening for music..."))

        if (!Shizuku.pingBinder()) {
            onError?.invoke("Shizuku is not running. Please start Shizuku first.")
            stopSelf()
            return
        }

        try {
            Shizuku.bindUserService(userServiceArgs, userServiceConnection)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to bind Shizuku UserService", e)
            onError?.invoke("Shizuku bind failed: ${e.message}")
            stopSelf()
        }
    }

    private fun stopCapture() {
        audioCaptureService?.stopCapture()
        if (userServiceBound) {
            try {
                Shizuku.unbindUserService(userServiceArgs, userServiceConnection, true)
            } catch (e: Exception) {
                Log.w(TAG, "Error unbinding UserService", e)
            }
            userServiceBound = false
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopCapture()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "SonicLens Audio Capture",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Active while SonicLens is listening for songs"
            setShowBadge(false)
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(text: String): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SonicLens")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}