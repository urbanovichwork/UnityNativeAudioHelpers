#if UNITY_IOS
using System;
using System.Runtime.InteropServices;
using JetBrains.Annotations;
using R3;
using UnityEngine;
using UnityEngine.Scripting;

namespace NativeAudioHelper
{
    [UsedImplicitly(ImplicitUseKindFlags.InstantiatedNoFixedConstructorSignature)]
    public sealed class IOSAudioHelper : IAudioHelper
    {
        private delegate void RouteChangedCallback();

        private delegate void VolumeChangedCallback(float volume);

        [DllImport("__Internal")]
        private static extern void NAH_Start(RouteChangedCallback routeCb, VolumeChangedCallback volumeCb);

        [DllImport("__Internal")]
        private static extern void NAH_Stop();

        [DllImport("__Internal")]
        private static extern int NAH_GetOutputType();

        [DllImport("__Internal")]
        private static extern IntPtr NAH_GetOutputName();

        [DllImport("__Internal")]
        private static extern int NAH_GetOutputChannels();

        [DllImport("__Internal")]
        private static extern double NAH_GetOutputLatencySeconds();

        [DllImport("__Internal")]
        private static extern float NAH_GetVolume();

        [DllImport("__Internal")]
        private static extern void NAH_SetVolume(float volume);

        private static readonly RouteChangedCallback SRouteCb = OnRouteChangedFromNative;
        private static readonly VolumeChangedCallback SVolumeCb = OnVolumeChangedFromNative;
        private static IOSAudioHelper _sInstance;

        private readonly Subject<AudioOutputInfo> _outputChanged = new();
        private readonly Subject<float> _volumeChanged = new();

        [Preserve]
        public IOSAudioHelper()
        {
            _sInstance = this;
            NAH_Start(SRouteCb, SVolumeCb);
        }

        public AudioOutputInfo CurrentOutput => ReadCurrentOutput();
        public float Volume => NAH_GetVolume();
        // iOS doesn't expose the route's step granularity publicly. 1/16 matches the
        // common headphone/AirPods/built-in-receiver step; finer routes will round up
        // and coarser ones (rare) just get a slightly tighter tolerance than ideal.
        public float VolumeStepSize => 1f / 16f;
        public bool SupportsProgrammaticVolume => true;

        public Observable<AudioOutputInfo> OnOutputChanged => _outputChanged;
        public Observable<float> OnVolumeChanged => _volumeChanged;

        // Routes through MPVolumeView's private MPVolumeSlider subview. The applied
        // value is quantised by the system; the actual result arrives via the
        // outputVolume KVO observer and propagates through OnVolumeChanged.
        // showSystemUi is ignored on iOS (the OS owns volume-HUD presentation).
        public void SetVolume(float normalised, bool showSystemUi = false) =>
            NAH_SetVolume(Math.Clamp(normalised, 0f, 1f));

        public void Dispose()
        {
            NAH_Stop();
            if (_sInstance == this) _sInstance = null;
            _outputChanged.Dispose();
            _volumeChanged.Dispose();
        }

        private static AudioOutputInfo ReadCurrentOutput()
        {
            var type = (AudioOutputType)NAH_GetOutputType();
            string name = Marshal.PtrToStringUTF8(NAH_GetOutputName()) ?? string.Empty;
            int channels = NAH_GetOutputChannels();
            double latency = NAH_GetOutputLatencySeconds();
            return new AudioOutputInfo(type, name, channels, latency);
        }

        [AOT.MonoPInvokeCallback(typeof(RouteChangedCallback))]
        private static void OnRouteChangedFromNative()
        {
            IOSAudioHelper helper = _sInstance;
            if (helper == null) return;
            try
            {
                helper._outputChanged.OnNext(ReadCurrentOutput());
            }
            catch (Exception e)
            {
                Debug.LogException(e);
            }
        }

        [AOT.MonoPInvokeCallback(typeof(VolumeChangedCallback))]
        private static void OnVolumeChangedFromNative(float volume)
        {
            IOSAudioHelper helper = _sInstance;
            if (helper == null) return;
            try
            {
                helper._volumeChanged.OnNext(volume);
            }
            catch (Exception e)
            {
                Debug.LogException(e);
            }
        }
    }
}
#endif