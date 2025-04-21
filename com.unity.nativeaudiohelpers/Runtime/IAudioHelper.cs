using System.Threading;
using System.Threading.Tasks;

namespace NativeAudioHelper
{
    public interface IAudioHelper
    {
        public bool IsHeadphonesConnected();
        public Task<bool> IsDeviceMuted(CancellationToken cancellationToken);
        public float GetDeviceVolume();
        public void SetDeviceVolume(float delta);
        public float GetDeviceMaxVolume();
        public void Dispose();
    }
}