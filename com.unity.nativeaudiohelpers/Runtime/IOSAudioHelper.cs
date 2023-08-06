#if UNITY_IOS
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using JetBrains.Annotations;

namespace NativeAudioHelper
{
    [UsedImplicitly(ImplicitUseKindFlags.InstantiatedNoFixedConstructorSignature)]
    internal class IOSAudioHelper : IAudioHelper
    {
        private const string ClipName = "NativeAudioHelpers_Mute.caf";
        
        [DllImport("__Internal")]
        private static extern bool _IsHeadphonesOn();

        [DllImport("__Internal")]
        private static extern void _InitIsMutedCheck(string clipName, IsMutedCallbackType callback);

        delegate void IsMutedCallbackType(bool isMuted);

        [DllImport("__Internal")]
        private static extern float _GetSystemVolume();

        [DllImport("__Internal")]
        private static extern void _SetSystemVolume(float volume);

        [DllImport("__Internal")]
        private static extern float _GetDeviceMaxVolume();

        private static TaskCompletionSource<bool> _taskCompletionSource;

        public void Dispose()
        {
        }

        public bool IsHeadphonesConnected() => _IsHeadphonesOn();

        public async Task<bool> IsDeviceMuted()
        {
            if (_taskCompletionSource == null)
            {
                _taskCompletionSource = new TaskCompletionSource<bool>();
                _InitIsMutedCheck(ClipName, IsMutedCallback);
                await _taskCompletionSource.Task;
            }

            return await _taskCompletionSource.Task;
        }

        [AOT.MonoPInvokeCallback(typeof(IsMutedCallbackType))]
        static void IsMutedCallback(bool isMuted)
        {
            _taskCompletionSource.SetResult(isMuted);
        }

        public float GetDeviceVolume() => _GetSystemVolume();
        public void SetDeviceVolume(float volume) => _SetSystemVolume(volume);
        public float GetDeviceMaxVolume() => _GetDeviceMaxVolume();
    }
}
#endif