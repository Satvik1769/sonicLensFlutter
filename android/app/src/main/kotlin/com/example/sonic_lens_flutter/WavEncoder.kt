package com.example.sonic_lens_flutter

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Wraps raw PCM data with a WAV header.
 * Output is a complete .wav file ready to upload to the server.
 * The server can convert to mp3 via: ffmpeg -i input.wav output.mp3
 */
object WavEncoder {

    fun encode(pcmData: ByteArray, sampleRate: Int, channels: Int, bitsPerSample: Int = 16): ByteArray {
        val dataSize = pcmData.size
        val totalSize = 44 + dataSize

        val buffer = ByteBuffer.allocate(totalSize).order(ByteOrder.LITTLE_ENDIAN)

        // RIFF header
        buffer.put("RIFF".toByteArray())
        buffer.putInt(totalSize - 8)   // file size minus RIFF + size field
        buffer.put("WAVE".toByteArray())

        // fmt chunk
        buffer.put("fmt ".toByteArray())
        buffer.putInt(16)              // chunk size for PCM
        buffer.putShort(1)             // PCM format
        buffer.putShort(channels.toShort())
        buffer.putInt(sampleRate)
        buffer.putInt(sampleRate * channels * bitsPerSample / 8) // byte rate
        buffer.putShort((channels * bitsPerSample / 8).toShort()) // block align
        buffer.putShort(bitsPerSample.toShort())

        // data chunk
        buffer.put("data".toByteArray())
        buffer.putInt(dataSize)
        buffer.put(pcmData)

        return buffer.array()
    }
}