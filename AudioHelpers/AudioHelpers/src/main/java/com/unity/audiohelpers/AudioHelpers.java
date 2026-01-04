package com.unity.audiohelpers;

import android.content.Context;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;

public class AudioHelpers
{
    static AudioManager audioManager;

    public AudioHelpers(Context context)
    {
        audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
    }

    public boolean _IsHeadphonesOn()
    {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M)
        {
            AudioDeviceInfo[] audioDeviceInfos = audioManager.getDevices(AudioManager.GET_DEVICES_INPUTS);
            for (AudioDeviceInfo audioDeviceInfo : audioDeviceInfos) {
                if (audioDeviceInfo.getType() == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                        audioDeviceInfo.getType() == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                        audioDeviceInfo.getType() == AudioDeviceInfo.TYPE_WIRED_HEADPHONES)
                    return true;
            }
        }
        else
        {
            return audioManager.isWiredHeadsetOn() || audioManager.isBluetoothA2dpOn();
        }

        return false;
    }

    public float _GetSystemVolume()
    {
        int deviceVolume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);

        return (float) (deviceVolume / (float) _GetDeviceMaxVolume());
    }

    public void _SetSystemVolume(float volumeValue)
    {
        int volumeScaled = (int) (volumeValue * (float) _GetDeviceMaxVolume());
        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, volumeScaled, 1);
    }

    public int _GetDeviceMaxVolume()
    {
        return audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
    }

    public String _GetAudioOutputType()
    {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M)
        {
            AudioDeviceInfo[] devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS);
            for (AudioDeviceInfo device : devices)
            {
                int type = device.getType();
                if (type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP)
                    return "bluetoothA2DP";
                if (type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO)
                    return "bluetoothSCO";
                if (type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES)
                    return "wiredHeadphones";
                if (type == AudioDeviceInfo.TYPE_WIRED_HEADSET)
                    return "wiredHeadset";
                if (type == AudioDeviceInfo.TYPE_USB_HEADSET)
                    return "usbHeadset";
                if (type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
                    return "builtInSpeaker";
            }
        }
        return "unknown";
    }

    public String _GetAudioOutputName()
    {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M)
        {
            AudioDeviceInfo[] devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS);
            for (AudioDeviceInfo device : devices)
            {
                int type = device.getType();
                if (type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                    type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                    type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                    type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                    type == AudioDeviceInfo.TYPE_USB_HEADSET)
                {
                    CharSequence name = device.getProductName();
                    return name != null ? name.toString() : "";
                }
            }
        }
        return "";
    }
}

