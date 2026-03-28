// IAudioCaptureCallback.aidl
// Called by ShizukuAudioUserService to deliver PCM audio chunks to the main app
package com.example.sonic_lens_flutter;

interface IAudioCaptureCallback {
    // Called every 20 seconds with a raw PCM chunk
    // data: raw PCM bytes (44100Hz, stereo, 16-bit)
    // sampleRate: sample rate in Hz
    // channels: number of channels
    void onAudioChunk(in byte[] data, int sampleRate, int channels);

    // Called when an error occurs in the Shizuku process
    void onError(String message);
}