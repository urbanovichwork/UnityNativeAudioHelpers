#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <UIKit/UIKit.h>
#import <stdlib.h>
#import <string.h>

// Output type ordinals — must stay in sync with C# AudioOutputType.
typedef NS_ENUM(NSInteger, NAHOutputType) {
    NAHOutputTypeUnknown          = 0,
    NAHOutputTypeBuiltInSpeaker   = 1,
    NAHOutputTypeBuiltInReceiver  = 2,
    NAHOutputTypeWiredHeadphones  = 3,
    NAHOutputTypeWiredHeadset     = 4,
    NAHOutputTypeUsbHeadset       = 5,
    NAHOutputTypeBluetoothA2dp    = 6,
    NAHOutputTypeBluetoothHfp     = 7,
    NAHOutputTypeBluetoothLe      = 8,
    NAHOutputTypeHearingAid       = 9,
    NAHOutputTypeHdmi             = 10,
    NAHOutputTypeCarAudio         = 11,
    NAHOutputTypeAirPlay          = 12,
};

typedef void (*NAHRouteChangedCallback)(void);
typedef void (*NAHVolumeChangedCallback)(float volume);

static NAHOutputType NAHClassifyPort(NSString *portType, NSString *portName) {
    if (portType == nil) return NAHOutputTypeUnknown;
    if ([portType isEqualToString:AVAudioSessionPortBuiltInSpeaker])  return NAHOutputTypeBuiltInSpeaker;
    if ([portType isEqualToString:AVAudioSessionPortBuiltInReceiver]) return NAHOutputTypeBuiltInReceiver;
    if ([portType isEqualToString:AVAudioSessionPortHeadphones])      return NAHOutputTypeWiredHeadphones;
    if ([portType isEqualToString:AVAudioSessionPortHeadsetMic])      return NAHOutputTypeWiredHeadset;
    if ([portType isEqualToString:AVAudioSessionPortUSBAudio])        return NAHOutputTypeUsbHeadset;
    if ([portType isEqualToString:AVAudioSessionPortBluetoothA2DP])   return NAHOutputTypeBluetoothA2dp;
    if ([portType isEqualToString:AVAudioSessionPortBluetoothHFP])    return NAHOutputTypeBluetoothHfp;
    if ([portType isEqualToString:AVAudioSessionPortBluetoothLE]) {
        // Apple has no public marker for MFi hearing aids; best-effort by name match
        // against the major manufacturers. False negatives are acceptable here.
        NSString *lower = portName.lowercaseString ?: @"";
        if ([lower containsString:@"hearing"] || [lower containsString:@"resound"] ||
            [lower containsString:@"oticon"]  || [lower containsString:@"phonak"]  ||
            [lower containsString:@"widex"]   || [lower containsString:@"signia"]  ||
            [lower containsString:@"starkey"]) {
            return NAHOutputTypeHearingAid;
        }
        return NAHOutputTypeBluetoothLe;
    }
    if ([portType isEqualToString:AVAudioSessionPortHDMI])     return NAHOutputTypeHdmi;
    if ([portType isEqualToString:AVAudioSessionPortCarAudio]) return NAHOutputTypeCarAudio;
    if ([portType isEqualToString:AVAudioSessionPortAirPlay])  return NAHOutputTypeAirPlay;
    return NAHOutputTypeUnknown;
}

@interface NAHObserver : NSObject
+ (instancetype)shared;
- (void)startWithRoute:(NAHRouteChangedCallback)routeCb volume:(NAHVolumeChangedCallback)volumeCb;
- (void)stop;

@property (atomic, assign, readonly) NAHOutputType outputType;
@property (atomic, assign, readonly) NSInteger outputChannels;
@property (atomic, assign, readonly) double outputLatencySeconds;
// Stable malloc'd UTF-8 buffer, replaced on each refresh.
- (const char *)cachedOutputNameUTF8;
- (float)volume;
@end

@implementation NAHObserver {
    AVAudioSession *_session;
    NAHRouteChangedCallback _routeCb;
    NAHVolumeChangedCallback _volumeCb;
    BOOL _observing;
    char *_cachedNameUTF8;
}

+ (instancetype)shared {
    static NAHObserver *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[NAHObserver alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (!self) return nil;
    _session = [AVAudioSession sharedInstance];
    _cachedNameUTF8 = strdup("");
    [self refreshRouteCache];
    return self;
}

- (void)dealloc {
    [self stop];
    free(_cachedNameUTF8);
}

- (void)startWithRoute:(NAHRouteChangedCallback)routeCb volume:(NAHVolumeChangedCallback)volumeCb {
    if (_observing) [self stop];
    _routeCb = routeCb;
    _volumeCb = volumeCb;

    [_session addObserver:self forKeyPath:@"outputVolume" options:0 context:NULL];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRouteChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    _observing = YES;
    [self refreshRouteCache];
}

- (void)stop {
    if (!_observing) return;
    [_session removeObserver:self forKeyPath:@"outputVolume"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _observing = NO;
    _routeCb = NULL;
    _volumeCb = NULL;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context {
    if (![keyPath isEqualToString:@"outputVolume"]) return;
    NAHVolumeChangedCallback cb = _volumeCb;
    if (!cb) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        cb(self->_session.outputVolume);
    });
}

- (void)handleRouteChange:(NSNotification *)note {
    NAHRouteChangedCallback cb = _routeCb;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshRouteCache];
        if (cb) cb();
    });
}

- (void)refreshRouteCache {
    AVAudioSessionRouteDescription *route = _session.currentRoute;
    AVAudioSessionPortDescription *out = route.outputs.firstObject;

    NSString *portType = out.portType;
    NSString *portName = out.portName ?: @"";
    NAHOutputType type = (out == nil) ? NAHOutputTypeUnknown : NAHClassifyPort(portType, portName);

    _outputType = type;
    _outputChannels = (NSInteger)out.channels.count;
    _outputLatencySeconds = _session.outputLatency;

    const char *src = portName.UTF8String ?: "";
    char *replacement = strdup(src);
    char *previous = _cachedNameUTF8;
    _cachedNameUTF8 = replacement;
    free(previous);
}

- (const char *)cachedOutputNameUTF8 { return _cachedNameUTF8 ? _cachedNameUTF8 : ""; }
- (float)volume { return _session.outputVolume; }

@end

#pragma mark - Volume setter

// Apple does not provide a public API for changing the system output volume.
// The supported workaround — used by countless shipping apps — is to keep an
// MPVolumeView attached to a real window, locate its internal MPVolumeSlider
// subview, and set its `value`. MPVolumeSlider's setter propagates the change
// into the audio system and our KVO observer on outputVolume picks up the
// applied (quantised) value.
//
// Caveats:
//   • MPVolumeSlider is private API (class-name lookup); Apple could rename it.
//   • The view must be in a window hierarchy AND laid out before the slider's
//     value setter takes effect — that's why we attach to the key window.
//   • alpha 0.001 + off-screen frame keeps the view "logically present" without
//     disturbing the user-facing UI or suppressing the system volume HUD when
//     the user uses hardware volume keys.

@interface NAHVolumeSetter : NSObject
+ (instancetype)shared;
- (void)setVolume:(float)volume;
@end

@implementation NAHVolumeSetter {
    MPVolumeView *_volumeView;
    UISlider *_volumeSlider;
}

+ (instancetype)shared {
    static NAHVolumeSetter *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[NAHVolumeSetter alloc] init]; });
    return instance;
}

- (void)setVolume:(float)volume {
    float clamped = fmaxf(0.0f, fminf(1.0f, volume));
    if ([NSThread isMainThread]) {
        [self applyVolume:clamped];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{ [self applyVolume:clamped]; });
    }
}

- (void)applyVolume:(float)volume {
    if (![self attachIfNeeded]) return;
    _volumeSlider.value = volume;
}

- (BOOL)attachIfNeeded {
    UIWindow *window = [self currentKeyWindow];
    if (window == nil) return NO;

    if (_volumeView == nil) {
        _volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-10000, -10000, 100, 50)];
        _volumeView.alpha = 0.001f;
        _volumeView.userInteractionEnabled = NO;
    }

    if (_volumeView.superview != window) {
        [_volumeView removeFromSuperview];
        [window addSubview:_volumeView];
        _volumeSlider = nil; // tied to the previous window; rediscover
    }

    if (_volumeSlider == nil) {
        [_volumeView layoutIfNeeded];
        for (UIView *subview in _volumeView.subviews) {
            if ([NSStringFromClass(subview.class) isEqualToString:@"MPVolumeSlider"]) {
                _volumeSlider = (UISlider *)subview;
                break;
            }
        }
    }

    return _volumeSlider != nil;
}

- (UIWindow *)currentKeyWindow {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) return window;
        }
    }
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (!window.hidden) return window;
        }
    }
    return nil;
}

@end

#pragma mark - C interop

extern "C" {

void NAH_Start(NAHRouteChangedCallback routeCb, NAHVolumeChangedCallback volumeCb) {
    [[NAHObserver shared] startWithRoute:routeCb volume:volumeCb];
}

void NAH_Stop(void) {
    [[NAHObserver shared] stop];
}

void NAH_SetVolume(float volume) {
    [[NAHVolumeSetter shared] setVolume:volume];
}

int NAH_GetOutputType(void) {
    return (int)[[NAHObserver shared] outputType];
}

const char *NAH_GetOutputName(void) {
    return [[NAHObserver shared] cachedOutputNameUTF8];
}

int NAH_GetOutputChannels(void) {
    return (int)[[NAHObserver shared] outputChannels];
}

double NAH_GetOutputLatencySeconds(void) {
    return [[NAHObserver shared] outputLatencySeconds];
}

float NAH_GetVolume(void) {
    return [[NAHObserver shared] volume];
}

}
