namespace NativeAudioHelper
{
    public readonly struct AudioOutputInfo
    {
        public AudioOutputType Type { get; }
        public string Name { get; }
        public int Channels { get; }
        public double LatencySeconds { get; }

        public bool IsHeadphones =>
            Type is AudioOutputType.WiredHeadphones
                or AudioOutputType.WiredHeadset
                or AudioOutputType.UsbHeadset
                or AudioOutputType.BluetoothA2dp
                or AudioOutputType.BluetoothHfp
                or AudioOutputType.BluetoothLe
                or AudioOutputType.HearingAid;

        public AudioOutputInfo(AudioOutputType type, string name, int channels, double latencySeconds)
        {
            Type = type;
            Name = name ?? string.Empty;
            Channels = channels < 0 ? 0 : channels;
            LatencySeconds = latencySeconds < 0 ? 0 : latencySeconds;
        }

        public static readonly AudioOutputInfo Unknown =
            new(AudioOutputType.Unknown, string.Empty, 0, 0);
    }

    public static class AudioOutputTypeExtensions
    {
        public static string ToAnalyticsString(this AudioOutputType type) => type switch
        {
            AudioOutputType.BuiltInSpeaker   => "builtInSpeaker",
            AudioOutputType.BuiltInReceiver  => "builtInReceiver",
            AudioOutputType.WiredHeadphones  => "wiredHeadphones",
            AudioOutputType.WiredHeadset     => "wiredHeadset",
            AudioOutputType.UsbHeadset       => "usbHeadset",
            AudioOutputType.BluetoothA2dp    => "bluetoothA2DP",
            AudioOutputType.BluetoothHfp     => "bluetoothSCO",
            AudioOutputType.BluetoothLe      => "bluetoothLE",
            AudioOutputType.HearingAid       => "hearingAid",
            AudioOutputType.Hdmi             => "hdmi",
            AudioOutputType.CarAudio         => "carAudio",
            AudioOutputType.AirPlay          => "airPlay",
            _                                => "unknown",
        };
    }
}
