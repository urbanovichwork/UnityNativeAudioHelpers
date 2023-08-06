#if UNITY_ANDROID
using System.Threading.Tasks;
using JetBrains.Annotations;
using UnityEngine;

namespace NativeAudioHelper
{
    [UsedImplicitly(ImplicitUseKindFlags.InstantiatedNoFixedConstructorSignature)]
    internal class AndroidAudioHelper : IAudioHelper
    {
        private const string UnityPlayerClassName = "com.unity3d.player.UnityPlayer";
        private const string CurrentActivityName = "currentActivity";
        private const string PluginNamespace = "com.unity.audiohelpers.AudioHelpers";

        private const string IsHeadphonesOnMethodName = "_IsHeadphonesOn";
        private const string GetSystemVolumeMethodName = "_GetSystemVolume";
        private const string SetSystemVolumeMethodName = "_SetSystemVolume";
        private const string GetDeviceMaxVolumeMethodName = "_GetDeviceMaxVolume";

        private AndroidJavaObject _androidPlugin;

        public AndroidAudioHelper() => InitializePlugin();

        private void InitializePlugin()
        {
            using var javaUnityPlayer = new AndroidJavaClass(UnityPlayerClassName);
            using var currentActivity = javaUnityPlayer.GetStatic<AndroidJavaObject>(CurrentActivityName);
            _androidPlugin = new AndroidJavaObject(PluginNamespace, currentActivity);
        }

        public void Dispose() => _androidPlugin.Dispose();

        public bool IsHeadphonesConnected() => _androidPlugin.Call<bool>(IsHeadphonesOnMethodName);

        public Task<bool> IsDeviceMuted() => Task.FromResult(false);

        public float GetDeviceVolume() => _androidPlugin.Call<float>(GetSystemVolumeMethodName);

        public void SetDeviceVolume(float volume) => _androidPlugin.Call(SetSystemVolumeMethodName, volume);

        public float GetDeviceMaxVolume() => _androidPlugin.Call<float>(GetDeviceMaxVolumeMethodName);
    }
}
#endif