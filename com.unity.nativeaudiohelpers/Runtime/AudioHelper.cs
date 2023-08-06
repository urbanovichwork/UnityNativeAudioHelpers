using System;
using System.Threading.Tasks;
using JetBrains.Annotations;

namespace NativeAudioHelper
{
    [UsedImplicitly(ImplicitUseKindFlags.InstantiatedNoFixedConstructorSignature)]
    public class AudioHelper : IAudioHelper, IDisposable
    {
        private readonly IAudioHelper _nativeAudioHelper;

        public AudioHelper() => _nativeAudioHelper = CreateAudioHelperImplementation();
        public void Dispose() => _nativeAudioHelper.Dispose();
        public bool IsHeadphonesConnected() => _nativeAudioHelper.IsHeadphonesConnected();
        public Task<bool> IsDeviceMuted() => _nativeAudioHelper.IsDeviceMuted();
        public float GetDeviceVolume() => _nativeAudioHelper.GetDeviceVolume();
        public void SetDeviceVolume(float delta) => _nativeAudioHelper.SetDeviceVolume(delta);
        public float GetDeviceMaxVolume() => _nativeAudioHelper.GetDeviceMaxVolume();

        private IAudioHelper CreateAudioHelperImplementation()
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            return new AndroidAudioHelper();
#elif UNITY_IOS && !UNITY_EDITOR
            return new IOSAudioHelper();
#endif
            return new MoqAudioHelper();
        }
    }
}