#import <UIKit/UIKit.h>
#import "AxsNotifyLiquidConfig.h"
#import "AxsNotifyLiquidAnimator.h"
#import "AxsNotifyLiquidPreferences.h"
#import "AxsNotifyLiquidPrivate.h"

// ── 时段自动切换：白天 [7,19) 用 day 预设名，其余 night 预设名 ─────────────────
static NSArray<NSString *> *axs_notifyliquid_presetKeys(void) {
    return @[@"enabled", @"notify_scale",
             @"gradient_on", @"gradient_hue1", @"gradient_hue2",
             @"gradient_speed", @"gradient_opacity",
             @"color_source", @"dark_dim",
             @"burst_on", @"burst_intensity", @"dissolve_on",
             @"appear_mode", @"elastic_intensity", @"touch_glow_on",
             @"fish_on", @"fish_count", @"fish_size", @"fish_png",
             @"bubble_size", @"bubble_opacity",
             @"particle_on", @"particle_png", @"particle_density",
             @"particle_size", @"particle_dir",
             @"charge_fx", @"low_power_guard",
             @"auto_schedule", @"schedule_day", @"schedule_night"];
}
static void axs_notifyliquid_applyScheduledPreset(void) {
    AxsNotifyLiquidConfig *config = [AxsNotifyLiquidConfig axs_notifyliquid_shared];
    if (![config axs_notifyliquid_autoSchedule]) return;
    NSDictionary *all = axs_notifyliquid_readPreferences();
    NSArray *presets = [all[@"custom_presets"] isKindOfClass:[NSArray class]] ? all[@"custom_presets"] : nil;
    if (presets.count == 0) return;
    NSInteger hour = [[NSCalendar currentCalendar] component:NSCalendarUnitHour fromDate:[NSDate date]];
    BOOL isDay = (hour >= 7 && hour < 19);
    NSString *want = isDay ? [config axs_notifyliquid_scheduleDayName]
                           : [config axs_notifyliquid_scheduleNightName];
    if (want.length == 0) return;
    for (NSDictionary *preset in presets) {
        if (![[preset objectForKey:@"name"] isKindOfClass:[NSString class]]) continue;
        if ([[preset objectForKey:@"name"] isEqualToString:want]) {
            NSDictionary *settings = [preset objectForKey:@"settings"];
            if ([settings isKindOfClass:[NSDictionary class]]) {
                NSError *error = nil;
                for (NSString *key in axs_notifyliquid_presetKeys()) {
                    id v = settings[key];
                    if (v) axs_notifyliquid_writePreference(key, v, &error);
                }
            }
            break;
        }
    }
}

%ctor {
    @autoreleasepool {
        // Readers load a snapshot; they never write default preferences.
        [AxsNotifyLiquidConfig axs_notifyliquid_shared];
        // 时段自动切换：启动后应用一次，此后每小时检查。
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            axs_notifyliquid_applyScheduledPreset();
            NSTimer *hourly = [NSTimer scheduledTimerWithTimeInterval:3600.0 repeats:YES
                block:^(NSTimer *t) {
                axs_notifyliquid_applyScheduledPreset();
            }];
            [NSRunLoop.mainRunLoop addTimer:hourly forMode:NSRunLoopCommonModes];
        });
    }
}

// ── 锁屏通知液态：hook 通知视图（私有类，类名随 iOS 版本变化） ─────────────────
// 主类 NCNotificationShortLookView（iOS 15–18 锁屏横幅通知）。
// 类不存在时 Logos 自动跳过该 hook，不影响其它部分。
%hook NCNotificationShortLookView

- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_attachToView:self];
    } else {
        [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_detachView:self];
    }
}

- (void)layoutSubviews {
    %orig;
    // 系统重新布局后刷新层帧 + 重施缩放（自愈）。
    [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_refreshForView:self];
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;
    if (!newWindow) {
        // 即将离场：液态溶解（叠加在系统划走动画上）。
        [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_dissolveForView:self];
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    // 触摸发光（touch glow）：高光脉冲 + 微挤压。
    [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_touchGlowForView:self];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    UITouch *touch = [touches anyObject];
    if (!touch) return;
    CGFloat dy = [touch locationInView:self].y - CGRectGetMidY(self.bounds);
    [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_dragGradientForView:self translationY:dy];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_endDragForView:self];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_endDragForView:self];
}

%end

// 长按展开态（LongLook）同套效果。
%hook NCNotificationLongLookView

- (void)didMoveToWindow {
    %orig;
    if (self.window) {
        [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_attachToView:self];
    } else {
        [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_detachView:self];
    }
}

- (void)layoutSubviews {
    %orig;
    [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_refreshForView:self];
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;
    if (!newWindow) {
        [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_dissolveForView:self];
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_touchGlowForView:self];
}

%end

