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
// 触摸发光（touch glow）：触摸通知时高光闪一下 + 微挤压。
- (BOOL)axs_notifyliquid_touchGlowOn;
// 液态玻璃质感（LiquidGlassKit 复刻）：材质 / 边缘高光 / 阴影 / 高光动画模式。
// 材质：0=清透 1=磨砂 2=着色 3=暗色。
- (BOOL)axs_notifyliquid_glassOn;
- (double)axs_notifyliquid_glassIntensity;
- (NSInteger)axs_notifyliquid_glassMaterial;
- (double)axs_notifyliquid_glassTintHue;
- (BOOL)axs_notifyliquid_edgeOn;
- (double)axs_notifyliquid_edgeIntensity;
// 色散边缘（chromatic aberration）：红/绿/蓝三色描边微偏移——Liquid Glass 标志性细节。
- (BOOL)axs_notifyliquid_edgeChroma;
// 内发光（inner glow）：玻璃内侧边缘柔光。
- (BOOL)axs_notifyliquid_innerGlowOn;
- (double)axs_notifyliquid_innerGlowIntensity;
- (BOOL)axs_notifyliquid_shadowOn;
- (double)axs_notifyliquid_shadowIntensity;
// 高光动画：0=关 1=shimmer 流光扫过 2=pulse 脉冲 3=breathe 呼吸。
- (NSInteger)axs_notifyliquid_highlightMode;
// Generic accessors.
- (id)axs_notifyliquid_valueForKey:(NSString *)key defaultValue:(id)defaultValue;
- (void)axs_notifyliquid_reload;
@end
