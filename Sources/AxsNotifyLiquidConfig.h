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
// 自定义鱼图片（多张 ; 分隔，留空用手绘小鱼）。
- (NSString *)axs_notifyliquid_fishPng;
// 泡泡样式：大小倍数、透明度。
- (double)axs_notifyliquid_bubbleSize;
- (double)axs_notifyliquid_bubbleOpacity;
// 粒子方向：0=下落 1=上飘 2=横飘。
- (NSInteger)axs_notifyliquid_particleDir;
// 充电特效（⚡金色火花）。
- (BOOL)axs_notifyliquid_chargeFx;
// 低电量保护（自动降载）。
- (BOOL)axs_notifyliquid_lowPowerGuard;
// 时段自动切换（白天/夜间预设名）。
- (BOOL)axs_notifyliquid_autoSchedule;
- (NSString *)axs_notifyliquid_scheduleDayName;
- (NSString *)axs_notifyliquid_scheduleNightName;
// 配色来源：0=手动双色 1=跟随应用图标 2=跟随壁纸。
- (NSInteger)axs_notifyliquid_colorSource;
// 深色模式自动压暗。
- (BOOL)axs_notifyliquid_darkDim;
// 到达粒子爆发 / 消失消散。
- (BOOL)axs_notifyliquid_burstOn;
- (double)axs_notifyliquid_burstIntensity;
- (BOOL)axs_notifyliquid_dissolveOn;
// 粒子特效（图片文件导入）：开关、图片路径（多张用 ; 分隔）、数量（密度）、大小。
- (BOOL)axs_notifyliquid_particleOn;
- (NSString *)axs_notifyliquid_particlePng;
- (double)axs_notifyliquid_particleDensity;
- (double)axs_notifyliquid_particleSize;
// 爆发图片路径（找不到回退白色光点）。
- (NSString *)axs_notifyliquid_burstPng;
// Generic accessors.
- (id)axs_notifyliquid_valueForKey:(NSString *)key defaultValue:(id)defaultValue;
- (void)axs_notifyliquid_reload;
@end
