#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MPVolumeView.h>
#import <MediaPlayer/MediaPlayer.h>
#import <UIKit/UIKit.h>

extern "C" {
	static CFTimeInterval startPlayTime;
	static NSString* cachedClipName;
	static SystemSoundID cachedSoundFileID = 0;
	typedef void (*IsMutedCallbackType)(bool state);
	static IsMutedCallbackType currentCallback = NULL;
	static BOOL callbackFired = NO;

	static void FireCallback(bool isMuted) {
		if (!callbackFired && currentCallback) {
			callbackFired = YES;
			IsMutedCallbackType cb = currentCallback;
			currentCallback = NULL;
			cb(isMuted);
		}
	}

	static void PlaySoundCompletionBlock(SystemSoundID SSID, void *clientData) {
		AudioServicesRemoveSystemSoundCompletion(SSID);
		CFTimeInterval playTime = CACurrentMediaTime() - startPlayTime;
		FireCallback(playTime < 0.1);
	}

	void _InitIsMutedCheck(const char* clipNameRaw, IsMutedCallbackType callbackRaw) {
		if (!callbackRaw) return;

		currentCallback = callbackRaw;
		callbackFired = NO;

		NSString* clipName = clipNameRaw ? [NSString stringWithUTF8String:clipNameRaw] : @"";

		if (![clipName isEqualToString:cachedClipName]) {
			if (cachedSoundFileID != 0) {
				AudioServicesDisposeSystemSoundID(cachedSoundFileID);
				cachedSoundFileID = 0;
			}
			cachedClipName = clipName;
			NSString* bundlePath = [[NSBundle mainBundle] bundlePath];
			NSString* path = [NSString stringWithFormat:@"%@/Data/Raw/%@", bundlePath, cachedClipName];
			NSURL* url = [NSURL fileURLWithPath:path];
			OSStatus status = AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &cachedSoundFileID);
			if (status != kAudioServicesNoError) {
				cachedSoundFileID = 0;
			}
		}

		if (cachedSoundFileID == 0) {
			FireCallback(false);
			return;
		}

		startPlayTime = CACurrentMediaTime();
		AudioServicesAddSystemSoundCompletion(cachedSoundFileID, NULL, NULL, PlaySoundCompletionBlock, NULL);
		AudioServicesPlaySystemSound(cachedSoundFileID);

		// Timeout fallback - if callback doesn't fire within 1s, assume not muted
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			FireCallback(false);
		});
	}

	bool _IsHeadphonesOn() {
        AVAudioSessionRouteDescription* route = [[AVAudioSession sharedInstance] currentRoute];
        
        for (AVAudioSessionPortDescription* desc in [route outputs]) {
            if ([[desc portType] isEqualToString:AVAudioSessionPortHeadphones])
                return true;
            if ([[desc portType] isEqualToString:AVAudioSessionPortBluetoothHFP])
                return true;
            if ([[desc portType] isEqualToString:AVAudioSessionPortBluetoothA2DP])
                return true;
        }
        
        return false;
	}

	float _GetSystemVolume() {
	    float volume = [[AVAudioSession sharedInstance] outputVolume];
	    return volume;
	}
	
	void _SetSystemVolume(float volume) {
		MPVolumeView *volumeView = [[MPVolumeView alloc] init];
		UISlider *volumeSlider = nil;
		for (UIView *view in [volumeView subviews]) {
			if ([NSStringFromClass(view.class) isEqualToString:@"MPVolumeSlider"]) {
				volumeSlider = (UISlider *)view;
				break;
			}
		}
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			volumeSlider.value = volume;
		});
	}

	float _GetDeviceMaxVolume() {
		return 1;
	}

	const char* _GetAudioOutputType() {
		AVAudioSessionRouteDescription* route = [[AVAudioSession sharedInstance] currentRoute];
		AVAudioSessionPortDescription* output = [[route outputs] firstObject];
		if (output) {
			NSString* portType = [output portType];
			const char* cStr = [portType UTF8String];
			char* result = (char*)malloc(strlen(cStr) + 1);
			strcpy(result, cStr);
			return result;
		}
		return strdup("unknown");
	}

	const char* _GetAudioOutputName() {
		AVAudioSessionRouteDescription* route = [[AVAudioSession sharedInstance] currentRoute];
		AVAudioSessionPortDescription* output = [[route outputs] firstObject];
		if (output) {
			NSString* portName = [output portName];
			const char* cStr = [portName UTF8String];
			char* result = (char*)malloc(strlen(cStr) + 1);
			strcpy(result, cStr);
			return result;
		}
		return strdup("");
	}
}
