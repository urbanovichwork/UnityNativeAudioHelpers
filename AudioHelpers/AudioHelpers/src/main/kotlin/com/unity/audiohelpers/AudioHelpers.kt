package com.unity.audiohelpers

import android.content.ContentResolver
import android.content.Context
import android.database.ContentObserver
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings

/**
 * Unity-facing audio helper. All public methods are safe to call from Unity's main thread.
 * Callbacks are dispatched on Android's main looper, which is the Unity main thread on the
 * standard `UnityPlayerActivity`.
 *
 * Output-type ordinals MUST stay in sync with the C# `AudioOutputType` enum and the iOS
 * native plugin's `NAHOutputType`.
 */
@Suppress("unused", "FunctionName")
class AudioHelpers(activityContext: Context) {

    interface Callback {
        fun onRouteChanged()
        fun onVolumeChanged(volume: Float)
    }

    private val ctx: Context = activityContext.applicationContext
    private val audio: AudioManager = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val resolver: ContentResolver = ctx.contentResolver
    private val mainHandler = Handler(Looper.getMainLooper())

    private var callback: Callback? = null
    private var registered: Boolean = false
    private var lastVolume: Float = -1f

    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
            mainHandler.post { callback?.onRouteChanged() }
        }
        override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
            mainHandler.post { callback?.onRouteChanged() }
        }
    }

    private val volumeObserver = object : ContentObserver(mainHandler) {
        override fun onChange(selfChange: Boolean) {
            val v = getVolume()
            if (v != lastVolume) {
                lastVolume = v
                callback?.onVolumeChanged(v)
            }
        }
    }

    fun register(cb: Callback) {
        if (registered) dispose()
        callback = cb
        lastVolume = getVolume()
        audio.registerAudioDeviceCallback(deviceCallback, mainHandler)
        resolver.registerContentObserver(Settings.System.CONTENT_URI, true, volumeObserver)
        registered = true
    }

    fun dispose() {
        if (!registered) return
        try { audio.unregisterAudioDeviceCallback(deviceCallback) } catch (_: Throwable) {}
        try { resolver.unregisterContentObserver(volumeObserver) } catch (_: Throwable) {}
        callback = null
        registered = false
    }

    fun getVolume(): Float {
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC).toFloat()
        return if (max > 0f) audio.getStreamVolume(AudioManager.STREAM_MUSIC) / max else 0f
    }

    /** Normalised size of a single hardware volume step on the active route. */
    fun getVolumeStepSize(): Float {
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC).toFloat()
        return if (max > 0f) 1f / max else 0.05f
    }

    fun setVolume(normalised: Float, showUi: Boolean) {
        val max = audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        val clamped = normalised.coerceIn(0f, 1f)
        val scaled = (clamped * max).toInt().coerceIn(0, max)
        val flags = if (showUi) AudioManager.FLAG_SHOW_UI else 0
        audio.setStreamVolume(AudioManager.STREAM_MUSIC, scaled, flags)
    }

    fun getOutputType(): Int {
        val device = pickPrimaryOutput() ?: return TYPE_UNKNOWN
        return mapDeviceType(device.type)
    }

    fun getOutputName(): String =
        pickPrimaryOutput()?.productName?.toString() ?: ""

    fun getOutputChannels(): Int {
        val counts = pickPrimaryOutput()?.channelCounts ?: return 0
        return if (counts.isNotEmpty()) counts.max() else 0
    }

    fun getOutputLatencySeconds(): Double {
        val frames = audio.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER)?.toIntOrNull() ?: return 0.0
        val rate = audio.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE)?.toIntOrNull() ?: return 0.0
        return if (rate > 0) frames.toDouble() / rate.toDouble() else 0.0
    }

    private fun pickPrimaryOutput(): AudioDeviceInfo? {
        val devices = audio.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        return devices.firstOrNull { isHeadphoneType(it.type) } ?: devices.firstOrNull()
    }

    private fun isHeadphoneType(type: Int): Boolean = when (type) {
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> true
        else -> {
            (Build.VERSION.SDK_INT >= 28 && type == AudioDeviceInfo.TYPE_HEARING_AID) ||
            (Build.VERSION.SDK_INT >= 31 && type == AudioDeviceInfo.TYPE_BLE_HEADSET) ||
            (Build.VERSION.SDK_INT >= 33 && type == AudioDeviceInfo.TYPE_BLE_BROADCAST)
        }
    }

    private fun mapDeviceType(type: Int): Int = when (type) {
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> TYPE_BUILTIN_SPEAKER
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> TYPE_BUILTIN_RECEIVER
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> TYPE_WIRED_HEADPHONES
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> TYPE_WIRED_HEADSET
        AudioDeviceInfo.TYPE_USB_HEADSET, AudioDeviceInfo.TYPE_USB_DEVICE -> TYPE_USB_HEADSET
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> TYPE_BLUETOOTH_A2DP
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> TYPE_BLUETOOTH_HFP
        AudioDeviceInfo.TYPE_HDMI, AudioDeviceInfo.TYPE_HDMI_ARC -> TYPE_HDMI
        else -> {
            if (Build.VERSION.SDK_INT >= 28 && type == AudioDeviceInfo.TYPE_HEARING_AID) TYPE_HEARING_AID
            else if (Build.VERSION.SDK_INT >= 31 && type == AudioDeviceInfo.TYPE_BLE_HEADSET) TYPE_BLUETOOTH_LE
            else if (Build.VERSION.SDK_INT >= 33 && type == AudioDeviceInfo.TYPE_BLE_BROADCAST) TYPE_BLUETOOTH_LE
            else TYPE_UNKNOWN
        }
    }

    companion object {
        const val TYPE_UNKNOWN          = 0
        const val TYPE_BUILTIN_SPEAKER  = 1
        const val TYPE_BUILTIN_RECEIVER = 2
        const val TYPE_WIRED_HEADPHONES = 3
        const val TYPE_WIRED_HEADSET    = 4
        const val TYPE_USB_HEADSET      = 5
        const val TYPE_BLUETOOTH_A2DP   = 6
        const val TYPE_BLUETOOTH_HFP    = 7
        const val TYPE_BLUETOOTH_LE     = 8
        const val TYPE_HEARING_AID      = 9
        const val TYPE_HDMI             = 10
        const val TYPE_CAR_AUDIO        = 11
        const val TYPE_AIRPLAY          = 12
    }
}
