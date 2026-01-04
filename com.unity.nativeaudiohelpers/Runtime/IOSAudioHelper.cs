#if UNITY_IOS
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using JetBrains.Annotations;

namespace NativeAudioHelper
{
    [UsedImplicitly(ImplicitUseKindFlags.InstantiatedNoFixedConstructorSignature)]
    internal class IOSAudioHelper : IAudioHelper
    {
        private const string ClipName = "NativeAudioHelpers_Mute.caf";
        private static readonly object Lock = new();
        private static TaskCompletionSource<bool> _tcs;

        private delegate void IsMutedCallbackType(bool isMuted);

        [DllImport("__Internal")]
        private static extern bool _IsHeadphonesOn();

        [DllImport("__Internal")]
        private static extern void _InitIsMutedCheck(string clipName, IsMutedCallbackType callback);

        [DllImport("__Internal")]
        private static extern float _GetSystemVolume();

        [DllImport("__Internal")]
        private static extern void _SetSystemVolume(float volume);

        [DllImport("__Internal")]
        private static extern float _GetDeviceMaxVolume();

        [DllImport("__Internal")]
        private static extern string _GetAudioOutputType();

        [DllImport("__Internal")]
        private static extern string _GetAudioOutputName();

        public void Dispose()
        {
        }

        public bool IsHeadphonesConnected() => _IsHeadphonesOn();

        public async Task<bool> IsDeviceMuted(CancellationToken cancellationToken)
        {
            TaskCompletionSource<bool> localTcs;
            bool isNew;
            lock (Lock)
            {
                isNew = _tcs == null;
                localTcs = _tcs ??= new TaskCompletionSource<bool>();
            }

            using var reg = cancellationToken.Register(() =>
            {
                lock (Lock)
                {
                    localTcs.TrySetCanceled();
                    if (_tcs == localTcs) _tcs = null;
                }
            });

            if (isNew)
                _InitIsMutedCheck(ClipName, IsMutedCallback);

            return await localTcs.Task;
        }

        [AOT.MonoPInvokeCallback(typeof(IsMutedCallbackType))]
        private static void IsMutedCallback(bool isMuted)
        {
            lock (Lock)
            {
                _tcs?.TrySetResult(isMuted);
                _tcs = null;
            }
        }

        public float GetDeviceVolume() => _GetSystemVolume();
        public void SetDeviceVolume(float volume) => _SetSystemVolume(volume);
        public float GetDeviceMaxVolume() => _GetDeviceMaxVolume();

        public AudioOutputInfo GetAudioOutputInfo()
        {
            string portType = _GetAudioOutputType();
            string portName = _GetAudioOutputName();
            bool isHeadphones = IsHeadphonesConnected();
            return new AudioOutputInfo(portType, portName, isHeadphones);
        }
    }
}
#endif