namespace NativeAudioHelper
{
    public readonly struct AudioOutputInfo
    {
        public string PortType { get; }
        public string PortName { get; }
        public bool IsHeadphones { get; }

        public AudioOutputInfo(string portType, string portName, bool isHeadphones)
        {
            PortType = portType ?? "unknown";
            PortName = portName ?? "";
            IsHeadphones = isHeadphones;
        }

        public static AudioOutputInfo Unknown => new("unknown", "", false);
        public static AudioOutputInfo Speaker => new("speaker", "Speaker", false);
    }
}
