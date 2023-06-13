#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MPVolumeView.h>

extern "C" {
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
