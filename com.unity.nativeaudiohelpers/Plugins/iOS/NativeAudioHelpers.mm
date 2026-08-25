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

// Every getter re-reads AVAudioSession rather than serving the snapshot taken at
// the last route-change notification. A notification is not a reliable clock for
// the route: iOS suspends the session while the app is inactive, so a route that
// changes behind Control Center or Settings — which is exactly how a user pairs
// AirPods — is either never posted or posted against the suspended session and
// read back stale. Wired headphones never showed this because plugging them in
// happens with the app on screen (TA-124).
// Mirrors Android's AudioHelpers.pickPrimaryOutput: an accessory anywhere in the
// route outranks whatever happens to be first. `outputs` is an array and iOS
// documents no ordering for it; the implementation before 2026-05 scanned all of
// it, and narrowing to firstObject is half of why a connected accessory could
// report "no headphones" (TA-124). Keep this set in sync with C#
// AudioOutputInfo.IsHeadphones and Kotlin AudioHelpers.isHeadphoneType.
static BOOL NAHIsHeadphoneType(NAHOutputType type) {
    switch (type) {
        case NAHOutputTypeWiredHeadphones:
        case NAHOutputTypeWiredHeadset:
        case NAHOutputTypeUsbHeadset:
        case NAHOutputTypeBluetoothA2dp:
        case NAHOutputTypeBluetoothHfp:
        case NAHOutputTypeBluetoothLe:
        case NAHOutputTypeHearingAid:
            return YES;
        default:
            return NO;
    }
}

static AVAudioSessionPortDescription *NAHPickPrimaryOutput(AVAudioSessionRouteDescription *route) {
    for (AVAudioSessionPortDescription *out in route.outputs) {
        if (NAHIsHeadphoneType(NAHClassifyPort(out.portType, out.portName))) return out;
    }
    return route.outputs.firstObject;
}

@interface NAHObserver : NSObject
+ (instancetype)shared;
- (void)startWithRoute:(NAHRouteChangedCallback)routeCb volume:(NAHVolumeChangedCallback)volumeCb;
- (void)stop;

- (NAHOutputType)outputType;
- (NSInteger)outputChannels;
- (double)outputLatencySeconds;
// Valid until the next call into this observer; C# marshals it immediately.
- (const char *)cachedOutputNameUTF8;
- (float)volume;
@end

@interface NAHObserver ()
// Declared up front so the callers above its definition see the BOOL return.
- (BOOL)refreshRouteCache;
@end

// All reads and refreshes run on the Unity main thread: the getters are called
// from C# and both notification handlers hop to the main queue before touching
// the cache, so the malloc'd name buffer needs no further locking.
@implementation NAHObserver {
    AVAudioSession *_session;
    NAHRouteChangedCallback _routeCb;
    NAHVolumeChangedCallback _volumeCb;
    BOOL _observing;
    NAHOutputType _outputType;
    NSInteger _outputChannels;
    double _outputLatencySeconds;
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
    // The route can change while we are not running; re-read on the way back in.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDidBecomeActive:)
                                                 name:UIApplicationDidBecomeActiveNotification
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

// Deferred past the synchronous did-become-active observers so the audio plugin
// has re-activated the session by the time we read the route off it. Only a real
// change is published: this fires on every foreground, and a spurious event would
// make every route observer re-run its work for nothing.
- (void)handleDidBecomeActive:(NSNotification *)note {
    NAHRouteChangedCallback cb = _routeCb;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self refreshRouteCache] && cb) cb();
    });
}

// Returns whether the route this call read differs from the previous one.
- (BOOL)refreshRouteCache {
    AVAudioSessionRouteDescription *route = _session.currentRoute;
    AVAudioSessionPortDescription *out = NAHPickPrimaryOutput(route);

    NSString *portType = out.portType;
    NSString *portName = out.portName ?: @"";
    NAHOutputType type = (out == nil) ? NAHOutputTypeUnknown : NAHClassifyPort(portType, portName);

    const char *src = portName.UTF8String ?: "";
    BOOL changed = (type != _outputType) ||
                   (_cachedNameUTF8 == NULL) ||
                   (strcmp(_cachedNameUTF8, src) != 0);

    _outputType = type;
    _outputChannels = (NSInteger)out.channels.count;
    _outputLatencySeconds = _session.outputLatency;

    char *replacement = strdup(src);
    char *previous = _cachedNameUTF8;
    _cachedNameUTF8 = replacement;
    free(previous);

    return changed;
}

- (NAHOutputType)outputType { [self refreshRouteCache]; return _outputType; }
- (NSInteger)outputChannels { [self refreshRouteCache]; return _outputChannels; }
- (double)outputLatencySeconds { [self refreshRouteCache]; return _outputLatencySeconds; }

- (const char *)cachedOutputNameUTF8 {
    [self refreshRouteCache];
    return _cachedNameUTF8 ? _cachedNameUTF8 : "";
}

- (float)volume { return _session.outputVolume; }

@end

#pragma mark - Volume setter

// Apple exposes no public API for setting the system output volume. The
// workaround used by countless shipping apps is to host an MPVolumeView, reach
// its private MPVolumeSlider subview, and set `value`; the setter propagates
// into the audio system and our outputVolume KVO observer reports the applied
// (quantised) value.
//
// An MPVolumeView that lives in the key window's hierarchy SUPPRESSES the system
// volume HUD (the level overlay shown on hardware-button presses) — an off-screen
// frame and near-zero alpha do not change that; mere presence is what suppresses
// it. So we attach only transiently around a set and detach shortly after, which
// keeps the HUD working for ordinary hardware-button presses (TA-102).
//
// Caveats:
//   • MPVolumeSlider is private API (class-name lookup); Apple could rename it.
//   • The slider's value setter is a no-op until the view is in a window and laid
//     out, and (iOS 11.4+) only applies when set on a later runloop turn — hence
//     the deferred commit below.

@interface NAHVolumeSetter : NSObject
+ (instancetype)shared;
- (void)setVolume:(float)volume;
@end

// Kept attached just long enough for the value to land, then detached so the
// system volume HUD returns. Rapid sets (e.g. an in-app slider drag) coalesce and
// reuse the attached view, so there is no add/remove churn while one is in flight.
static const NSTimeInterval kNAHVolumeViewDetachDelay = 0.3;

@implementation NAHVolumeSetter {
    MPVolumeView *_volumeView;
    UISlider *_volumeSlider;
    float _pendingVolume;
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
    _pendingVolume = volume;
    if (![self attachIfNeeded]) return;
    // Commit on the next runloop turn (the slider must be laid out first), then
    // detach after a short grace period so the system volume HUD comes back.
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(commitPendingVolume) withObject:nil afterDelay:0.0];
    [self performSelector:@selector(detach) withObject:nil afterDelay:kNAHVolumeViewDetachDelay];
}

- (void)commitPendingVolume {
    _volumeSlider.value = _pendingVolume;
}

- (void)detach {
    [_volumeView removeFromSuperview];
    _volumeSlider = nil; // bound to this window; rediscover on the next attach
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
