package com.example.sonic_lens_flutter

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import kotlinx.coroutines.*

/**
 * Runs inside the Shizuku privileged process.
 * Has CAPTURE_AUDIO_OUTPUT permission, allowing AudioRecord with REMOTE_SUBMIX
 * to capture all system audio output (music, media, etc).
 *
 * Communicates back to the main app via IAudioCaptureCallback AIDL interface.
 */
class ShizukuAudioUserService : IAudioCaptureService.Stub() {

    companion object {
        private const val TAG = "ShizukuAudioService"
        const val SAMPLE_RATE = 44100
        const val CHANNELS = AudioFormat.CHANNEL_IN_STEREO
        const val ENCODING = AudioFormat.ENCODING_PCM_16BIT
        const val CHUNK_DURATION_SEC = 20
    }

    private var audioRecord: AudioRecord? = null
    private var callback: IAudioCaptureCallback? = null
    private var captureJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    @Volatile
    private var capturing = false

    override fun startCapture() {
        if (capturing) return
        Log.d(TAG, "Starting audio capture via Shizuku")

        val minBuffer = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNELS, ENCODING)
        val bufferSize = maxOf(minBuffer * 4, 65536)

        try {
            // REMOTE_SUBMIX captures all system audio output.
            // This source requires CAPTURE_AUDIO_OUTPUT permission — provided by Shizuku.
            @Suppress("MissingPermission")
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.REMOTE_SUBMIX,
                SAMPLE_RATE,
                CHANNELS,
                ENCODING,
                bufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                callback?.onError("AudioRecord failed to initialize. Ensure Shizuku is running.")
                return
            }

            capturing = true
            audioRecord?.startRecording()
            startCaptureLoop(bufferSize)

        } catch (e: Exception) {
            Log.e(TAG, "Failed to start capture", e)
            callback?.onError("Capture error: ${e.message}")
        }
    }

    private fun startCaptureLoop(bufferSize: Int) {
        // Total bytes for one 20-second chunk (stereo, 16-bit)
        val chunkBytes = SAMPLE_RATE * 2 /* channels */ * 2 /* bytes per sample */ * CHUNK_DURATION_SEC
        val readBuffer = ByteArray(bufferSize)
        val accumulator = ByteArrayAccumulator(chunkBytes)

        captureJob = scope.launch {
            while (capturing && isActive) {
                val read = audioRecord?.read(readBuffer, 0, readBuffer.size) ?: -1
                if (read > 0) {
                    val chunks = accumulator.append(readBuffer, read)
                    for (chunk in chunks) {
                        Log.d(TAG, "Sending ${chunk.size} byte PCM chunk to Flutter")
                        try {
                            callback?.onAudioChunk(chunk, SAMPLE_RATE, 2)
                        } catch (e: Exception) {
                            Log.e(TAG, "Callback error", e)
                        }
                    }
                } else if (read < 0) {
                    Log.e(TAG, "AudioRecord read error: $read")
                    callback?.onError("AudioRecord read failed: $read")
                    break
                }
            }
        }
    }

    override fun stopCapture() {
        Log.d(TAG, "Stopping audio capture")
        capturing = false
        captureJob?.cancel()
        captureJob = null
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
    }

    override fun isCapturing(): Boolean = capturing

    override fun setCallback(cb: IAudioCaptureCallback?) {
        callback = cb
    }
}

/** Accumulates bytes and emits complete chunks of the target size. */
private class ByteArrayAccumulator(private val chunkSize: Int) {
    private val buffer = java.io.ByteArrayOutputStream(chunkSize)

    fun append(data: ByteArray, length: Int): List<ByteArray> {
        buffer.write(data, 0, length)
        val chunks = mutableListOf<ByteArray>()
        while (buffer.size() >= chunkSize) {
            val all = buffer.toByteArray()
            chunks.add(all.copyOf(chunkSize))
            buffer.reset()
            if (all.size > chunkSize) {
                buffer.write(all, chunkSize, all.size - chunkSize)
            }
        }
        return chunks
    }
}