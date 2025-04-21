using System.Threading;
using System.Threading.Tasks;
using JetBrains.Annotations;

namespace NativeAudioHelper
{
    [UsedImplicitly(ImplicitUseKindFlags.InstantiatedNoFixedConstructorSignature)]
    internal class MoqAudioHelper : IAudioHelper
    {
        private const float MaxVolume = 1f;
        private float _volume = 0.75f;

        public void Dispose()
        {
        }

        public bool IsHeadphonesConnected()
        {
            return true;
        }

        public Task<bool> IsDeviceMuted(CancellationToken cancellationToken)
        {
            return Task.FromResult(false);
        }

        public float GetDeviceVolume()
        {
            return _volume;
        }

        public void SetDeviceVolume(float delta)
        {
            _volume = delta;
        }

        public float GetDeviceMaxVolume()
        {
            return MaxVolume;
        }
    }
}