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
// 出现动画（liquid_glass_widgets 风格）：0=关 1=果冻弹跳 2=除雾渐显 3=挤压拉伸 4=凝胶膨胀。
- (NSInteger)axs_notifyliquid_appearMode;
- (double)axs_notifyliquid_appearIntensity;
// 触摸发光（touch glow）：触摸通知时渐变闪一下 + 微挤压。
- (BOOL)axs_notifyliquid_touchGlowOn;
// 鱼缸游鱼：每条通知背景里游动的小鱼（数量/大小可调）。
- (BOOL)axs_notifyliquid_fishOn;
- (NSInteger)axs_notifyliquid_fishCount;
- (double)axs_notifyliquid_fishSize;
// 配色来源：0=手动双色 1=跟随应用图标 2=跟随壁纸。
- (NSInteger)axs_notifyliquid_colorSource;
// 深色模式自动压暗。
- (BOOL)axs_notifyliquid_darkDim;
// 到达粒子爆发 / 消失消散。
- (BOOL)axs_notifyliquid_burstOn;
- (double)axs_notifyliquid_burstIntensity;
- (BOOL)axs_notifyliquid_dissolveOn;
// 粒子特效：0=关 1=❄️ 2=🌸 3=🍂 4=⭐ 5=❤️ 6=自动 7=自定义。
- (NSInteger)axs_notifyliquid_particleStyle;
- (double)axs_notifyliquid_particleSize;
- (NSString *)axs_notifyliquid_particleCustom;
// Generic accessors.
- (id)axs_notifyliquid_valueForKey:(NSString *)key defaultValue:(id)defaultValue;
- (void)axs_notifyliquid_reload;
@end
