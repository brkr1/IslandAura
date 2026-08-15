#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Cephei/HBPreferences.h>

// IslandAura: draws a persistent neon glow around the Dynamic Island, as a
// transparent, non-interactive overlay window sitting above everything else
// in SpringBoard - including the lock screen. Three styles: Glow (static
// outline + shadow, the original), Pulse (Glow's outline, breathing via a
// looped shadowOpacity animation), and Tint (a soft filled color wash
// instead of a bright outline).
//
// Live-tracking history: the first two attempts hooked MRUSessionNowPlayingView
// / MRUActivityNowPlayingView cross-process inside com.apple.MediaRemoteUI and
// got wrong, unrecoverable positions - that code is still in the repo under
// MediaRemoteUIHalf/, kept for reference but out of the build. A third,
// in-process diagnostic dump (still below, gated behind "debugLogging") found
// the real answer instead of guessing again: SpringBoard itself creates a
// window called SBSystemApertureWindow the first time Now Playing content
// ever shows (it doesn't exist before that), and SBSystemApertureContainerView
// inside it lays out to the island's exact live frame - compact AND expanded
// - on every change. It sits at screen origin with zero-offset ancestors the
// whole way up, so no cross-process anything, and none of the coordinate-
// space math that broke the earlier attempts. We just mirror that view's
// frame directly.

// Measured for iPhone 14 Pro Max (430x932pt logical screen, portrait) - used
// as the startup frame before SBSystemApertureContainerView has laid out for
// the first time since boot (nothing has played yet, so it doesn't exist).
static const CGFloat kLXIslandWidth = 126.0;
static const CGFloat kLXIslandHeight = 37.0;
static const CGFloat kLXIslandTopInset = 11.0;

static NSString *const kLXAuraModeGlow = @"glow";
static NSString *const kLXAuraModePulse = @"pulse";
static NSString *const kLXAuraModeTint = @"tint";
static NSString *const kLXAuraPulseAnimationKey = @"lx_auraPulse";

HBPreferences *lx_islandAuraPreferences;
UIWindow *lx_islandAuraWindow;
UIView *lx_islandAuraGlowView;
CAShapeLayer *lx_islandAuraStrokeLayer;

UIColor *lx_colorFromHexString(NSString *hexString) {
    NSString *cleanString = [hexString stringByReplacingOccurrencesOfString: @"#" withString: @""];
    unsigned int rgbValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString: cleanString];
    [scanner scanHexInt: &rgbValue];

    return [UIColor colorWithRed: ((rgbValue & 0xFF0000) >> 16) / 255.0
                            green: ((rgbValue & 0x00FF00) >> 8) / 255.0
                             blue: (rgbValue & 0x0000FF) / 255.0
                            alpha: 1.0];
}

NSString *lx_islandAuraMode(void) {
    return [lx_islandAuraPreferences objectForKey: @"auraMode"] ?: kLXAuraModeGlow;
}

void lx_stopPulseAnimation(void) {
    [lx_islandAuraGlowView.layer removeAnimationForKey: kLXAuraPulseAnimationKey];
    [lx_islandAuraStrokeLayer removeAnimationForKey: kLXAuraPulseAnimationKey];
}

void lx_startPulseAnimation(void) {
    if (!lx_islandAuraGlowView || !lx_islandAuraStrokeLayer || [lx_islandAuraGlowView.layer animationForKey: kLXAuraPulseAnimationKey]) {
        return;
    }

    // Animating just the soft shadow left the crisp stroke itself constant,
    // so the "breathing" barely read as different from Glow. Swinging the
    // stroke's own opacity too - on the CAShapeLayer, not the container
    // view's layer - makes the whole outline visibly dim and brighten.
    CABasicAnimation *shadowBreathe = [CABasicAnimation animationWithKeyPath: @"shadowOpacity"];
    shadowBreathe.fromValue = @(1.0);
    shadowBreathe.toValue = @(0.15);
    shadowBreathe.duration = 1.2;
    shadowBreathe.autoreverses = YES;
    shadowBreathe.repeatCount = HUGE_VALF;
    shadowBreathe.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseInEaseOut];
    [lx_islandAuraGlowView.layer addAnimation: shadowBreathe forKey: kLXAuraPulseAnimationKey];

    CABasicAnimation *strokeBreathe = [CABasicAnimation animationWithKeyPath: @"opacity"];
    strokeBreathe.fromValue = @(1.0);
    strokeBreathe.toValue = @(0.3);
    strokeBreathe.duration = 1.2;
    strokeBreathe.autoreverses = YES;
    strokeBreathe.repeatCount = HUGE_VALF;
    strokeBreathe.timingFunction = shadowBreathe.timingFunction;
    [lx_islandAuraStrokeLayer addAnimation: strokeBreathe forKey: kLXAuraPulseAnimationKey];
}

// Glow: bright, thick outline + tight shadow, the original look. Pulse:
// same outline, but both its shadow and the stroke itself breathe via
// lx_startPulseAnimation - not just the halo, or the swing barely read as
// different from Glow. Tint: thin, dim outline behind a solid-ish fill and
// a wide shadow - a soft color wash instead of a defined edge.
void lx_applyIslandAuraStyle(void) {
    if (!lx_islandAuraGlowView || !lx_islandAuraStrokeLayer) {
        return;
    }

    NSString *colorHex = [lx_islandAuraPreferences objectForKey: @"neonColor"] ?: @"#00D4FF";
    UIColor *color = lx_colorFromHexString(colorHex);
    NSString *mode = lx_islandAuraMode();
    BOOL isTint = [mode isEqualToString: kLXAuraModeTint];
    BOOL isPulse = [mode isEqualToString: kLXAuraModePulse];

    lx_islandAuraGlowView.layer.shadowColor = color.CGColor;

    if (isTint) {
        lx_islandAuraStrokeLayer.fillColor = [color colorWithAlphaComponent: 0.4].CGColor;
        lx_islandAuraStrokeLayer.strokeColor = [color colorWithAlphaComponent: 0.35].CGColor;
        lx_islandAuraStrokeLayer.lineWidth = 0.75;
        lx_islandAuraGlowView.layer.shadowRadius = 18.0;
        lx_islandAuraGlowView.layer.shadowOpacity = 0.85;
    } else {
        lx_islandAuraStrokeLayer.fillColor = [UIColor clearColor].CGColor;
        lx_islandAuraStrokeLayer.strokeColor = color.CGColor;
        lx_islandAuraStrokeLayer.lineWidth = 2.5;
        lx_islandAuraGlowView.layer.shadowRadius = 10.0;
        lx_islandAuraGlowView.layer.shadowOpacity = 1.0;
    }

    if (isPulse) {
        lx_startPulseAnimation();
    } else {
        lx_stopPulseAnimation();
    }
}

void lx_updateIslandAuraStrokePath(void) {
    if (!lx_islandAuraGlowView || !lx_islandAuraStrokeLayer) {
        return;
    }

    lx_islandAuraStrokeLayer.frame = lx_islandAuraGlowView.bounds;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect: lx_islandAuraGlowView.bounds
                                                      cornerRadius: lx_islandAuraGlowView.bounds.size.height / 2.0];
    lx_islandAuraStrokeLayer.path = path.CGPath;
}

CGRect lx_islandAuraCompactFrame(void) {
    if (!lx_islandAuraGlowView || !lx_islandAuraGlowView.superview) {
        return CGRectZero;
    }
    CGFloat screenWidth = lx_islandAuraGlowView.superview.bounds.size.width;
    return CGRectMake((screenWidth - kLXIslandWidth) / 2.0, kLXIslandTopInset, kLXIslandWidth, kLXIslandHeight);
}

// Diagnostic only, off by default and not exposed in Root.plist - this is
// what actually found SBSystemApertureContainerView (see file header), kept
// around in case a future iOS version renames things and this needs to run
// again. Enable by adding "debugLogging" = true directly to
// /var/mobile/Library/Preferences/com.brkr1.tweaks.islandaura.hbprefs.plist
// (Filza/SSH), respring, then play something. Output goes both to the device
// console (NSLog, visible via idevicesyslog/Console.app) and appended to
// /var/mobile/Documents/IslandAuraDebug.log for offline pickup.
BOOL lx_islandAuraDebugLoggingEnabled(void) {
    return [lx_islandAuraPreferences boolForKey: @"debugLogging"];
}

void lx_appendIslandAuraDebugLog(NSString *text) {
    NSString *path = @"/var/mobile/Documents/IslandAuraDebug.log";
    if (![[NSFileManager defaultManager] fileExistsAtPath: path]) {
        [[NSFileManager defaultManager] createFileAtPath: path contents: nil attributes: nil];
    }
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath: path];
    [handle seekToEndOfFile];
    [handle writeData: [text dataUsingEncoding: NSUTF8StringEncoding]];
    [handle closeFile];
}

void lx_walkViewForIslandRegion(UIView *view, CGRect regionInScreen, NSMutableString *log, NSInteger depth) {
    CGRect screenFrame = [view convertRect: view.bounds toView: nil];

    if (CGRectIntersectsRect(screenFrame, regionInScreen)) {
        NSString *indent = [@"" stringByPaddingToLength: depth * 2 withString: @" " startingAtIndex: 0];
        [log appendFormat: @"%@%@ frame=%@ alpha=%.2f hidden=%d layerClass=%@\n",
            indent, NSStringFromClass([view class]), NSStringFromCGRect(screenFrame),
            view.alpha, view.hidden, NSStringFromClass([view.layer class])];
    }

    for (UIView *subview in view.subviews) {
        lx_walkViewForIslandRegion(subview, regionInScreen, log, depth + 1);
    }
}

void lx_dumpIslandRegionHierarchy(NSString *reason) {
    if (!lx_islandAuraDebugLoggingEnabled()) {
        return;
    }

    UIWindowScene *scene = nil;
    for (UIScene *candidate in [UIApplication sharedApplication].connectedScenes) {
        if ([candidate isKindOfClass: [UIWindowScene class]]) {
            scene = (UIWindowScene *) candidate;
            break;
        }
    }
    if (!scene) {
        return;
    }

    CGFloat screenWidth = scene.screen.bounds.size.width;
    // Generous band around the island - covers the compact pill and every
    // plausible expanded size, so whatever the real owner is, it's caught.
    CGRect region = CGRectMake(screenWidth / 2.0 - 140.0, 0.0, 280.0, 80.0);

    NSMutableString *log = [NSMutableString stringWithFormat: @"\n=== IslandAura hierarchy dump (%@) at %@ ===\n", reason, [NSDate date]];
    for (UIWindow *window in scene.windows) {
        if (window == lx_islandAuraWindow) {
            continue;
        }
        [log appendFormat: @"-- window %@ level=%.0f hidden=%d --\n", NSStringFromClass([window class]), window.windowLevel, window.hidden];
        lx_walkViewForIslandRegion(window, region, log, 1);
    }

    NSLog(@"[IslandAuraDebug]%@", log);
    lx_appendIslandAuraDebugLog(log);
}

static NSTimeInterval lx_lastDebugDumpTime = 0;

void lx_maybeDumpIslandRegionHierarchy(NSString *reason) {
    if (!lx_islandAuraDebugLoggingEnabled()) {
        return;
    }
    // A full region tree walk is heavier than the frame mirroring itself, and
    // layoutSubviews can fire many times per second during the expand/
    // collapse animation - space samples out so the log stays readable.
    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    if (now - lx_lastDebugDumpTime < 0.5) {
        return;
    }
    lx_lastDebugDumpTime = now;
    lx_dumpIslandRegionHierarchy(reason);
}

// The actual live-tracking fix: SBSystemApertureContainerView's frame *is*
// the island's real on-screen frame, already in screen coordinates (its
// window sits at the screen origin and every ancestor in between has zero
// offset), for both the compact pill and every expanded size. Mirror it
// directly - no animation wrapper, since Apple already drives this view
// through its own spring animation and calls layoutSubviews repeatedly
// through it; wrapping our own animation on top would just lag behind.
void lx_trackLiveIslandFrame(UIView *apertureView) {
    if (!lx_islandAuraGlowView) {
        return;
    }

    CGRect frame = [apertureView convertRect: apertureView.bounds toView: nil];
    if (frame.size.width <= 0 || frame.size.height <= 0) {
        return;
    }

    lx_islandAuraGlowView.frame = frame;
    lx_updateIslandAuraStrokePath();
    lx_maybeDumpIslandRegionHierarchy(@"apertureLayout");
}

void lx_setUpIslandAuraWindow(void) {
    if (lx_islandAuraWindow != nil) {
        return;
    }
    if (![lx_islandAuraPreferences boolForKey: @"enabled"]) {
        return;
    }

    UIWindowScene *scene = nil;
    for (UIScene *candidate in [UIApplication sharedApplication].connectedScenes) {
        if ([candidate isKindOfClass: [UIWindowScene class]] && candidate.activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *) candidate;
            break;
        }
    }
    if (scene == nil) {
        // SpringBoard's main scene may not be ready yet this early - try again shortly.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            lx_setUpIslandAuraWindow();
        });
        return;
    }

    lx_islandAuraWindow = [[UIWindow alloc] initWithWindowScene: scene];
    // Deliberately very high - needs to render above the lock screen
    // (CoverSheet), not just the status bar.
    lx_islandAuraWindow.windowLevel = CGFLOAT_MAX - 1000;
    lx_islandAuraWindow.backgroundColor = [UIColor clearColor];
    lx_islandAuraWindow.userInteractionEnabled = NO;
    lx_islandAuraWindow.hidden = NO;

    lx_islandAuraGlowView = [[UIView alloc] initWithFrame: CGRectZero];
    lx_islandAuraGlowView.backgroundColor = [UIColor clearColor];
    lx_islandAuraGlowView.userInteractionEnabled = NO;

    lx_islandAuraStrokeLayer = [CAShapeLayer layer];
    [lx_islandAuraGlowView.layer addSublayer: lx_islandAuraStrokeLayer];

    lx_islandAuraGlowView.layer.shadowOffset = CGSizeZero;

    [lx_islandAuraWindow addSubview: lx_islandAuraGlowView];

    lx_islandAuraGlowView.frame = lx_islandAuraCompactFrame();
    lx_updateIslandAuraStrokePath();
    lx_applyIslandAuraStyle();
}

void lx_tearDownIslandAuraWindow(void) {
    [lx_islandAuraWindow removeFromSuperview];
    lx_islandAuraWindow.hidden = YES;
    lx_islandAuraWindow = nil;
    lx_islandAuraGlowView = nil;
    lx_islandAuraStrokeLayer = nil;
}

%hook SpringBoard

- (void) applicationDidFinishLaunching: (id) application {
    %orig;
    lx_setUpIslandAuraWindow();
}

%end

@interface SBSystemApertureContainerView : UIView
@end

%hook SBSystemApertureContainerView

- (void) layoutSubviews {
    %orig;
    lx_trackLiveIslandFrame(self);
}

%end

%ctor {
    lx_islandAuraPreferences = [[HBPreferences alloc] initWithIdentifier: @"com.brkr1.tweaks.islandaura.hbprefs"];
    [lx_islandAuraPreferences registerDefaults: @{
        @"enabled": @true,
        @"neonColor": @"#00D4FF",
        @"auraMode": kLXAuraModeGlow,
        @"debugLogging": @false
    }];

    // React immediately when the user changes something in Settings, no
    // respring needed.
    [lx_islandAuraPreferences registerPreferenceChangeBlock: ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL shouldBeEnabled = [lx_islandAuraPreferences boolForKey: @"enabled"];

            if (shouldBeEnabled && lx_islandAuraWindow == nil) {
                lx_setUpIslandAuraWindow();
            } else if (!shouldBeEnabled && lx_islandAuraWindow != nil) {
                lx_tearDownIslandAuraWindow();
            }

            lx_applyIslandAuraStyle();
        });
    }];
}
