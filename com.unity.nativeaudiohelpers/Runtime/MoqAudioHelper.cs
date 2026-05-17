using System;
using JetBrains.Annotations;
using R3;
using UnityEngine.Scripting;

namespace NativeAudioHelper
{
    [UsedImplicitly(ImplicitUseKindFlags.InstantiatedNoFixedConstructorSignature)]
    public sealed class MoqAudioHelper : IAudioHelper
    {
        private readonly Subject<AudioOutputInfo> _outputChanged = new();
        private readonly Subject<float> _volumeChanged = new();
        private float _volume = 0.75f;

        [Preserve]
        public MoqAudioHelper() { }

        public AudioOutputInfo CurrentOutput { get; } =
            new(AudioOutputType.WiredHeadphones, "Mock Headphones", 2, 0);

        public float Volume => _volume;
        public float VolumeStepSize => 1f / 20f;
        public bool SupportsProgrammaticVolume => true;

        public Observable<AudioOutputInfo> OnOutputChanged => _outputChanged;
        public Observable<float> OnVolumeChanged => _volumeChanged;

        public void SetVolume(float normalised, bool showSystemUi = false)
        {
            _volume = Math.Clamp(normalised, 0f, 1f);
            _volumeChanged.OnNext(_volume);
        }

        public void Dispose()
        {
            _outputChanged.Dispose();
            _volumeChanged.Dispose();
        }
    }
}
