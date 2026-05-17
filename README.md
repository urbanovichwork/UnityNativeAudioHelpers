UnityNativeAudioHelpers
=======================

Native audio helpers for iOS and Android, surfaced as a single `IAudioHelper` interface
to Unity:

- `CurrentOutput` — type, name, channels, output latency of the active output route
- `Volume` — normalised `[0, 1]` system media volume
- `OnOutputChanged` / `OnVolumeChanged` — push-based observables (no polling)
- `SetVolume(normalised, showSystemUi)` — Android only; throws on iOS
- `SupportsProgrammaticVolume` — guard your UI against the iOS no-op

### Layout

- `com.unity.nativeaudiohelpers/` — UPM package (C# runtime, iOS `.mm`, prebuilt Android `.aar`)
- `AudioHelpers/` — Android library source (Kotlin, Gradle). Build the AAR with:
  ```bash
  cd AudioHelpers && ./gradlew :AudioHelpers:assembleRelease
  ```
  Then copy `AudioHelpers/AudioHelpers/build/outputs/aar/AudioHelpers-release.aar` to
  `com.unity.nativeaudiohelpers/Plugins/Android/AudioHelpers.aar`.

### Permissions (Android)

- `MODIFY_AUDIO_SETTINGS` — required only if you call `SetVolume`.
  Add to your Unity Android manifest if used:
  `<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>`
- No Bluetooth permissions are required for route detection — `AudioManager.getDevices`
  works without them on API 23+.

### iOS

`AVFoundation` is auto-linked by Unity. No post-processor is required.
