#import "AxsNotifyLiquidConfig.h"
#import "AxsNotifyLiquidPreferences.h"
#import <math.h>

@interface AxsNotifyLiquidConfig ()
@property (atomic, copy) NSDictionary *snapshot;
@property (nonatomic, strong) dispatch_queue_t reloadQueue;
@end

static void axs_notifyliquid_preferencesDidChange(CFNotificationCenterRef center, void *observer,
                                          CFStringRef name, const void *object, CFDictionaryRef info) {
    AxsNotifyLiquidConfig *config = (__bridge AxsNotifyLiquidConfig *)observer;
    dispatch_async(config.reloadQueue, ^{
        [config axs_notifyliquid_reload];
    });
}

@implementation AxsNotifyLiquidConfig

+ (instancetype)axs_notifyliquid_shared {
    static AxsNotifyLiquidConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _reloadQueue = dispatch_queue_create("com.axs.notifyliquid.preferences", DISPATCH_QUEUE_SERIAL);
        [self axs_notifyliquid_reload];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)self, axs_notifyliquid_preferencesDidChange,
            (__bridge CFStringRef)AxsNotifyLiquidPreferencesChanged, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
        // Close the window between the first read and observer registration.
        dispatch_async(_reloadQueue, ^{ [self axs_notifyliquid_reload]; });
    }
    return self;
}

- (void)axs_notifyliquid_reload {
    self.snapshot = axs_notifyliquid_readPreferences();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:AxsNotifyLiquidPreferencesChanged object:self];
    });
}

- (id)axs_notifyliquid_valueForKey:(NSString *)key defaultValue:(id)defaultValue {
    return self.snapshot[key] ?: defaultValue;
}

- (BOOL)axs_notifyliquid_isEnabled {
    id value = [self axs_notifyliquid_valueForKey:@"enabled" defaultValue:@(NO)];
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : NO;
}

// ── 访问器（全部带钳制与缺省） ──
static double axs_notifyliquid_clamped(id value, double def, double lo, double hi) {
    if (![value isKindOfClass:[NSNumber class]]) return def;
    double d = [value doubleValue];
    if (!isfinite(d)) return def;
    return fmax(lo, fmin(hi, d));
}
static BOOL axs_notifyliquid_bool(id value, BOOL def) {
    return [value isKindOfClass:[NSNumber class]] ? [value boolValue] : def;
}

- (double)axs_notifyliquid_notifyScale {
    return axs_notifyliquid_clamped([self axs_notifyliquid_valueForKey:@"notify_scale" defaultValue:nil], 1.0, 0.6, 1.5);
}
- (BOOL)axs_notifyliquid_gradientOn {
    return axs_notifyliquid_bool([self axs_notifyliquid_valueForKey:@"gradient_on" defaultValue:nil], NO);
}
- (double)axs_notifyliquid_gradientHue1 {
    return axs_notifyliquid_clamped([self axs_notifyliquid_valueForKey:@"gradient_hue1" defaultValue:nil], 0.5, 0.0, 1.0);
}
- (double)axs_notifyliquid_gradientHue2 {
    return axs_notifyliquid_clamped([self axs_notifyliquid_valueForKey:@"gradient_hue2" defaultValue:nil], 0.85, 0.0, 1.0);
}
- (double)axs_notifyliquid_gradientSpeed {
    return axs_notifyliquid_clamped([self axs_notifyliquid_valueForKey:@"gradient_speed" defaultValue:nil], 0.3, 0.02, 2.0);
}
- (double)axs_notifyliquid_gradientOpacity {
    return axs_notifyliquid_clamped([self axs_notifyliquid_valueForKey:@"gradient_opacity" defaultValue:nil], 0.35, 0.05, 1.0);
}
- (BOOL)axs_notifyliquid_elasticOn {
    return axs_notifyliquid_bool([self axs_notifyliquid_valueForKey:@"elastic_on" defaultValue:nil], NO);
}
- (double)axs_notifyliquid_elasticIntensity {
    return axs_notifyliquid_clamped([self axs_notifyliquid_valueForKey:@"elastic_intensity" defaultValue:nil], 1.0, 0.2, 2.0);
}
- (BOOL)axs_notifyliquid_glassOn {
    return axs_notifyliquid_bool([self axs_notifyliquid_valueForKey:@"glass_on" defaultValue:nil], NO);
}
- (double)axs_notifyliquid_glassIntensity {
    return axs_notifyliquid_clamped([self axs_notifyliquid_valueForKey:@"glass_intensity" defaultValue:nil], 0.6, 0.1, 1.0);
}
- (NSInteger)axs_notifyliquid_glassMaterial {
    double d = axs_notifyliquid_clamped([self axs_notifyliquid_valueForKey:@"glass_material" defaultValue:nil], 1.0, 0.0, 3.0);
    return (NSInteger)d;
}
- (double)axs_notifyliquid_glassTintHue {
    return axs_notifyliquid_clamped([self axs_notifyliquid_valueForKey:@"glass_tint_hue" defaultValue:nil], 0.6, 0.0, 1.0);
}
- (BOOL)axs_notifyliquid_edgeOn {
    return axs_notifyliquid_bool([self axs_notifyliquid_valueForKey:@"edge_on" defaultValue:nil], NO);
}
- (double)axs_notifyliquid_edgeIntensity {
    return axs_notifyliquid_clamped([self axs_notifyliquid_valueForKey:@"edge_intensity" defaultValue:nil], 0.6, 0.1, 1.0);
}
- (BOOL)axs_notifyliquid_shadowOn {
    return axs_notifyliquid_bool([self axs_notifyliquid_valueForKey:@"shadow_on" defaultValue:nil], NO);
}
- (double)axs_notifyliquid_shadowIntensity {
    return axs_notifyliquid_clamped([self axs_notifyliquid_valueForKey:@"shadow_intensity" defaultValue:nil], 0.5, 0.1, 1.0);
}
- (NSInteger)axs_notifyliquid_highlightMode {
    double d = axs_notifyliquid_clamped([self axs_notifyliquid_valueForKey:@"highlight_mode" defaultValue:nil], 0.0, 0.0, 3.0);
    return (NSInteger)d;
}

- (void)dealloc {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                            (__bridge const void *)self);
}

@end
