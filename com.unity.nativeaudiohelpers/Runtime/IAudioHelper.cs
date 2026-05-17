using System;
using R3;

namespace NativeAudioHelper
{
    public interface IAudioHelper : IDisposable
    {
        AudioOutputInfo CurrentOutput { get; }
        float Volume { get; }
        // Normalised size of a single hardware volume step on the active route.
        // Use this to derive a "snap" tolerance instead of hardcoding one — Android
        // is integer-stepped and may not be able to land on arbitrary targets.
        float VolumeStepSize { get; }
        bool SupportsProgrammaticVolume { get; }

        Observable<AudioOutputInfo> OnOutputChanged { get; }
        Observable<float> OnVolumeChanged { get; }

        void SetVolume(float normalised, bool showSystemUi = false);
    }
}