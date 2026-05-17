namespace NativeAudioHelper
{
    // Ordinals must stay in sync with the iOS NAHOutputType enum and the Android
    // AudioHelpers.TYPE_* companion constants.
    public enum AudioOutputType : byte
    {
        Unknown          = 0,
        BuiltInSpeaker   = 1,
        BuiltInReceiver  = 2,
        WiredHeadphones  = 3,
        WiredHeadset     = 4,
        UsbHeadset       = 5,
        BluetoothA2dp    = 6,
        BluetoothHfp     = 7,
        BluetoothLe      = 8,
        HearingAid       = 9,
        Hdmi             = 10,
        CarAudio         = 11,
        AirPlay          = 12,
    }
}
