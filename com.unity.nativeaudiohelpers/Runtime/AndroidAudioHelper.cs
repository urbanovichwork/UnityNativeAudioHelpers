#if UNITY_ANDROID
using System;
using System.Diagnostics.CodeAnalysis;
using JetBrains.Annotations;
using R3;
using UnityEngine;
using UnityEngine.Scripting;

namespace NativeAudioHelper
{
    [UsedImplicitly(ImplicitUseKindFlags.InstantiatedNoFixedConstructorSignature)]
    public sealed class AndroidAudioHelper : IAudioHelper
    {
        private const string UnityPlayerClassName = "com.unity3d.player.UnityPlayer";
        private const string CurrentActivityName = "currentActivity";
        private const string PluginClassName = "com.unity.audiohelpers.AudioHelpers";
        private const string CallbackInterfaceName = "com.unity.audiohelpers.AudioHelpers$Callback";

        private readonly Subject<AudioOutputInfo> _outputChanged = new();
        private readonly Subject<float> _volumeChanged = new();

        private AndroidJavaObject _plugin;
        private CallbackProxy _proxy;

        [Preserve]
        public AndroidAudioHelper()
        {
            using var unityPlayer = new AndroidJavaClass(UnityPlayerClassName);
            using AndroidJavaObject activity = unityPlayer.GetStatic<AndroidJavaObject>(CurrentActivityName);
            _plugin = new AndroidJavaObject(PluginClassName, activity);

            _proxy = new CallbackProxy(this);
            _plugin.Call("register", _proxy);
        }

        public AudioOutputInfo CurrentOutput => ReadCurrentOutput();
        public float Volume => _plugin?.Call<float>("getVolume") ?? 0f;
        public float VolumeStepSize => _plugin?.Call<float>("getVolumeStepSize") ?? 0.05f;
        public bool SupportsProgrammaticVolume => true;

        public Observable<AudioOutputInfo> OnOutputChanged => _outputChanged;
        public Observable<float> OnVolumeChanged => _volumeChanged;

        public void SetVolume(float normalised, bool showSystemUi = false) =>
            _plugin?.Call("setVolume", Math.Clamp(normalised, 0f, 1f), showSystemUi);

        public void Dispose()
        {
            try
            {
                _plugin?.Call("dispose");
            }
            catch
            {
                /* idempotent */
            }

            _plugin?.Dispose();
            _plugin = null;
            _proxy = null;
            _outputChanged.Dispose();
            _volumeChanged.Dispose();
        }

        private AudioOutputInfo ReadCurrentOutput()
        {
            if (_plugin == null) return AudioOutputInfo.Unknown;
            int typeOrdinal = _plugin.Call<int>("getOutputType");
            string name = _plugin.Call<string>("getOutputName") ?? string.Empty;
            int channels = _plugin.Call<int>("getOutputChannels");
            double latency = _plugin.Call<double>("getOutputLatencySeconds");
            return new AudioOutputInfo((AudioOutputType)typeOrdinal, name, channels, latency);
        }

        private void HandleRouteChanged()
        {
            try
            {
                _outputChanged.OnNext(ReadCurrentOutput());
            }
            catch (Exception e)
            {
                Debug.LogException(e);
            }
        }

        private void HandleVolumeChanged(float volume)
        {
            try
            {
                _volumeChanged.OnNext(volume);
            }
            catch (Exception e)
            {
                Debug.LogException(e);
            }
        }

        private sealed class CallbackProxy : AndroidJavaProxy
        {
            private readonly AndroidAudioHelper _owner;

            public CallbackProxy(AndroidAudioHelper owner) : base(CallbackInterfaceName) =>
                _owner = owner;

            [UsedImplicitly]
            [SuppressMessage("ReSharper", "InconsistentNaming")]
            public void onRouteChanged() => _owner?.HandleRouteChanged();

            [UsedImplicitly]
            [SuppressMessage("ReSharper", "InconsistentNaming")]
            public void onVolumeChanged(float volume) => _owner?.HandleVolumeChanged(volume);
        }
    }
}
#endif