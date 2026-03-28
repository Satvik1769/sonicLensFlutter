// IAudioCaptureService.aidl
// Interface exposed by ShizukuAudioUserService running in Shizuku process
package com.example.sonic_lens_flutter;

import com.example.sonic_lens_flutter.IAudioCaptureCallback;

interface IAudioCaptureService {
    void startCapture();
    void stopCapture();
    boolean isCapturing();
    void setCallback(IAudioCaptureCallback callback);
}