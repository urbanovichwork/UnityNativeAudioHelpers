using System.Threading.Tasks;

namespace NativeAudioHelper
{
    public interface IAudioHelper
    {
        public bool IsHeadphonesConnected();
        public Task<bool> IsDeviceMuted();
        public float GetDeviceVolume();
        public void SetDeviceVolume(float delta);
        public float GetDeviceMaxVolume();
        public void Dispose();
    }
}