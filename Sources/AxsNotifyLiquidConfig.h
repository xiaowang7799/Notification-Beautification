#pragma once

#import <Foundation/Foundation.h>

@interface AxsNotifyLiquidConfig : NSObject
+ (instancetype)axs_notifyliquid_shared;
- (BOOL)axs_notifyliquid_isEnabled;
// 通知缩放（0.6–1.5）。
- (double)axs_notifyliquid_notifyScale;
// 流动渐变背景。
- (BOOL)axs_notifyliquid_gradientOn;
- (double)axs_notifyliquid_gradientHue1;
- (double)axs_notifyliquid_gradientHue2;
- (double)axs_notifyliquid_gradientSpeed;
- (double)axs_notifyliquid_gradientOpacity;
// 液态弹性动画（通知出现时果冻弹跳）。
- (BOOL)axs_notifyliquid_elasticOn;
- (double)axs_notifyliquid_elasticIntensity;
// 液态玻璃质感（流动高光）。
- (BOOL)axs_notifyliquid_glassOn;
- (double)axs_notifyliquid_glassIntensity;
// Generic accessors.
- (id)axs_notifyliquid_valueForKey:(NSString *)key defaultValue:(id)defaultValue;
- (void)axs_notifyliquid_reload;
@end
