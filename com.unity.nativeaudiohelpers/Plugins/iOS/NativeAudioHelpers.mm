#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MPVolumeView.h>
#import <MediaPlayer/MediaPlayer.h>
#import <UIKit/UIKit.h>

extern "C" {
	static CFTimeInterval startPlayTime;
	NSString* cachedClipName;
	SystemSoundID cachedSoundFileID;
	typedef void (*IsMutedCallbackType)(bool state);
	IsMutedCallbackType callback;

	static void PlaySoundCompletionBlock(SystemSoundID SSID, void *clientData) {
		AudioServicesRemoveSystemSoundCompletion(SSID);
		CFTimeInterval playTime = CACurrentMediaTime() - startPlayTime;
		callback(playTime < 0.1);
	}

	static NSString* CreateNSString(const char* string)
    {
        if (string != NULL)
            return [NSString stringWithUTF8String:string];
        else
            return [NSString stringWithUTF8String:""];
    }

 	void _InitIsMutedCheck(const char* clipNameRaw, IsMutedCallbackType callbackRaw) {
        NSString* clipName = CreateNSString(clipNameRaw);
		if (clipName != cachedClipName){
			cachedClipName = clipName;
			NSString* bundlePath = [[NSBundle mainBundle] bundlePath];
			NSString* streamingAssetsPath = [NSString stringWithFormat:@"%@/Data/Raw/", bundlePath];
			NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", streamingAssetsPath, cachedClipName]];
			AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &cachedSoundFileID);
		}
		callback = callbackRaw;
    	startPlayTime = CACurrentMediaTime();
		AudioServicesAddSystemSoundCompletion(cachedSoundFileID, NULL, NULL, PlaySoundCompletionBlock, NULL);
		AudioServicesPlaySystemSound(cachedSoundFileID);
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
	
	void _SetSystemVolume(float volume)
	{
		MPVolumeView *volumeView = [[MPVolumeView alloc] init];
		UISlider *volumeSlider = nil;
		
		for( UIView *view in [volumeView subviews] )
		{
			if( [NSStringFromClass(view.class) isEqualToString:@"MPVolumeSlider"] )
			{
				volumeSlider = (UISlider *)view;
				break;
			}
		}
		
		dispatch_after( dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			volumeSlider.value = volume;
		});
	// 	MPVolumeView *volumeView = [[MPVolumeView alloc] init];
	// 	UISlider *volumeViewSlider = nil;
		
	// 	for (UIView *view in volumeView.subviews) {
	// 		if ([view isKindOfClass:[UISlider class]]) {
	// 			volumeViewSlider = (UISlider *)view;
	// 			break;
	// 		}
	// 	}
		
	// 	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.0001 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
	// 		volumeViewSlider.value = _vol;
	// 	});
    }
    
    float _GetDeviceMaxVolume()
    {
        return 1;
    }
}
