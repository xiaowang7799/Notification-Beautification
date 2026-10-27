#import "AxsNotifyLiquidAnimator.h"
#import "AxsNotifyLiquidConfig.h"
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <math.h>

// 单条通知的效果容器（视图弱引用，通知消失自动失效）。
@interface AxsNotifyLiquidEffect : NSObject
@property (nonatomic, weak) UIView *view;
@property (nonatomic, strong) CAGradientLayer *gradient;   // 流动渐变背景
@property (nonatomic, strong) CAGradientLayer *glass;      // 流动高光（shimmer/pulse/breathe）
@property (nonatomic, strong) CAGradientLayer *tint;       // 材质着色（清透/磨砂/着色/暗色）
@property (nonatomic, strong) CAShapeLayer *edge;          // 边缘高光
@property (nonatomic, strong) CAShapeLayer *chromaR;       // 色散：红偏移
@property (nonatomic, strong) CAShapeLayer *chromaG;       // 色散：绿偏移
@property (nonatomic, strong) CAShapeLayer *chromaB;       // 色散：蓝偏移
@property (nonatomic, strong) CAGradientLayer *innerGlow;  // 内发光
@end
@implementation AxsNotifyLiquidEffect
@end

@interface AxsNotifyLiquidAnimator ()
@property (nonatomic, strong) NSMutableArray<AxsNotifyLiquidEffect *> *effects;
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic, assign) CFTimeInterval phase;
@property (nonatomic, assign) NSUInteger frameCounter;
@end

// 波浪路径已移除（功能取消）。

@implementation AxsNotifyLiquidAnimator

+ (instancetype)axs_notifyliquid_shared {
    static AxsNotifyLiquidAnimator *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _effects = [NSMutableArray array];
    }
    return self;
}

#pragma mark - 挂载 / 卸载

- (void)axs_notifyliquid_attachToView:(UIView *)view {
    if (!view) return;
    AxsNotifyLiquidConfig *config = [AxsNotifyLiquidConfig axs_notifyliquid_shared];
    if (![config axs_notifyliquid_isEnabled]) return;
    // 已挂过只刷新。
    for (AxsNotifyLiquidEffect *e in self.effects) {
        if (e.view == view) {
            [self axs_notifyliquid_refreshForView:view];
            return;
        }
    }

    AxsNotifyLiquidEffect *effect = [[AxsNotifyLiquidEffect alloc] init];
    effect.view = view;
    CGFloat radius = view.layer.cornerRadius > 0 ? view.layer.cornerRadius : 24.0;

    // 流动渐变背景（横向往复的三段渐变，颜色随时间流动）。
    // zPosition 10：必须浮在通知毛玻璃背景之上，否则被背景遮住（iOS 26 实测）。
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = view.bounds;
    gradient.cornerRadius = radius;
    gradient.startPoint = CGPointMake(0, 0.5);
    gradient.endPoint = CGPointMake(1, 0.5);
    gradient.opacity = 0;
    gradient.zPosition = 10;
    [view.layer addSublayer:gradient];
    effect.gradient = gradient;

    // 液态玻璃高光（斜向白色光带缓慢移动，同样浮在上层）。
    CAGradientLayer *glass = [CAGradientLayer layer];
    glass.frame = view.bounds;
    glass.cornerRadius = radius;
    glass.startPoint = CGPointMake(0, 0);
    glass.endPoint = CGPointMake(1, 1);
    glass.colors = @[(id)[UIColor clearColor].CGColor,
                     (id)[UIColor colorWithWhite:1 alpha:0.22].CGColor,
                     (id)[UIColor clearColor].CGColor];
    glass.locations = @[@0, @0.5, @1];
    glass.opacity = 0;
    glass.zPosition = 11;
    [view.layer addSublayer:glass];
    effect.glass = glass;

    // 材质着色层（LiquidGlassKit 材质：清透/磨砂/着色/暗色，整层纯色叠加）。
    CAGradientLayer *tint = [CAGradientLayer layer];
    tint.frame = view.bounds;
    tint.cornerRadius = radius;
    tint.opacity = 0;
    tint.zPosition = 9;
    [view.layer addSublayer:tint];
    effect.tint = tint;

    // 边缘高光（一圈亮边，LiquidGlassKit 的 edge highlight）。
    CAShapeLayer *edge = [CAShapeLayer layer];
    edge.frame = view.bounds;
    edge.fillColor = [UIColor clearColor].CGColor;
    edge.lineWidth = 1.5;
    edge.opacity = 0;
    edge.zPosition = 12;
    [view.layer addSublayer:edge];
    effect.edge = edge;

    // 色散边缘（chromatic aberration）：红/绿/蓝三描边微偏移，呈现彩虹分离。
    NSArray<NSNumber *> *chromaOffsets = @[@(-1.0), @(0.0), @(1.0)];
    NSArray<UIColor *> *chromaColors = @[
        [UIColor colorWithRed:1 green:0.25 blue:0.25 alpha:1],
        [UIColor colorWithRed:0.25 green:1 blue:0.45 alpha:1],
        [UIColor colorWithRed:0.3 green:0.5 blue:1 alpha:1],
    ];
    CAShapeLayer *chromaLayers[3];
    for (int i = 0; i < 3; i++) {
        CAShapeLayer *cl = [CAShapeLayer layer];
        cl.frame = view.bounds;
        cl.fillColor = [UIColor clearColor].CGColor;
        cl.lineWidth = 1.2;
        cl.strokeColor = chromaColors[i].CGColor;
        cl.opacity = 0;
        cl.zPosition = 12;
        cl.affineTransform = CGAffineTransformMakeTranslation(chromaOffsets[i].floatValue, 0);
        [view.layer addSublayer:cl];
        chromaLayers[i] = cl;
    }
    effect.chromaR = chromaLayers[0];
    effect.chromaG = chromaLayers[1];
    effect.chromaB = chromaLayers[2];

    // 内发光（inner glow）：径向渐变中心透明、边缘柔白光。
    CAGradientLayer *innerGlow = [CAGradientLayer layer];
    innerGlow.frame = view.bounds;
    innerGlow.cornerRadius = radius;
    innerGlow.type = kCAGradientLayerRadial;
    innerGlow.startPoint = CGPointMake(0.5, 0.5);
    innerGlow.endPoint = CGPointMake(1.0, 1.0);
    innerGlow.colors = @[(id)[UIColor clearColor].CGColor,
                         (id)[UIColor clearColor].CGColor,
                         (id)[UIColor colorWithWhite:1 alpha:0.25].CGColor];
    innerGlow.locations = @[@0, @0.6, @1];
    innerGlow.opacity = 0;
    innerGlow.zPosition = 13;
    [view.layer addSublayer:innerGlow];
    effect.innerGlow = innerGlow;

    [self.effects addObject:effect];

    // 液态弹性出现动画（果冻弹跳）。
    if ([config axs_notifyliquid_elasticOn]) {
        double intensity = [config axs_notifyliquid_elasticIntensity];
        double scale = [config axs_notifyliquid_notifyScale];
        CAKeyframeAnimation *pop = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        pop.values = @[@(scale * (1.0 - 0.25 * intensity)),
                       @(scale * (1.0 + 0.08 * intensity)),
                       @(scale * (1.0 - 0.03 * intensity)),
                       @(scale)];
        pop.keyTimes = @[@0, @0.45, @0.75, @1.0];
        pop.duration = 0.55;
        pop.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        pop.removedOnCompletion = YES;
        [view.layer addAnimation:pop forKey:@"axs_liquid_pop"];
    }

    [self axs_notifyliquid_refreshForView:view];
    [self axs_notifyliquid_ensureLink];
}

- (void)axs_notifyliquid_detachView:(UIView *)view {
    for (NSInteger i = (NSInteger)self.effects.count - 1; i >= 0; i--) {
        AxsNotifyLiquidEffect *e = self.effects[(NSUInteger)i];
        if (e.view == view || e.view == nil) {
            [e.gradient removeFromSuperlayer];
            [e.glass removeFromSuperlayer];
            [e.tint removeFromSuperlayer];
            [e.edge removeFromSuperlayer];
            [e.chromaR removeFromSuperlayer];
            [e.chromaG removeFromSuperlayer];
            [e.chromaB removeFromSuperlayer];
            [e.innerGlow removeFromSuperlayer];
            [self.effects removeObjectAtIndex:(NSUInteger)i];
        }
    }
    if (self.effects.count == 0) [self axs_notifyliquid_stopLink];
}

- (void)axs_notifyliquid_refreshForView:(UIView *)view {
    AxsNotifyLiquidConfig *config = [AxsNotifyLiquidConfig axs_notifyliquid_shared];
    if (![config axs_notifyliquid_isEnabled]) return;
    for (AxsNotifyLiquidEffect *e in self.effects) {
        if (e.view != view) continue;
        UIView *v = e.view;
        if (!v) return;
        CGFloat radius = v.layer.cornerRadius > 0 ? v.layer.cornerRadius : 24.0;
        e.gradient.frame = v.bounds;
        e.gradient.cornerRadius = radius;
        e.glass.frame = v.bounds;
        e.glass.cornerRadius = radius;
        e.tint.frame = v.bounds;
        e.tint.cornerRadius = radius;
        e.edge.frame = v.bounds;
        e.edge.path = [UIBezierPath bezierPathWithRoundedRect:v.bounds cornerRadius:radius].CGPath;
        // 色散三描边共用圆角矩形 path（各自 affineTransform 微偏移）。
        CGPathRef roundPath = [UIBezierPath bezierPathWithRoundedRect:v.bounds cornerRadius:radius].CGPath;
        e.chromaR.path = roundPath;
        e.chromaG.path = roundPath;
        e.chromaB.path = roundPath;
        e.innerGlow.frame = v.bounds;
        e.innerGlow.cornerRadius = radius;
        // 通知缩放（transform，布局后重施即自愈——frame 由系统管，transform 归我们）。
        double s = [config axs_notifyliquid_notifyScale];
        v.layer.transform = CATransform3DMakeScale(s, s, 1.0);
        return;
    }
}

#pragma mark - 动画驱动（30fps，仅有效果时运行）

- (void)axs_notifyliquid_ensureLink {
    if (self.link) return;
    self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(axs_notifyliquid_tick:)];
    // 30fps：慢动画足够流畅，省电降温。
    self.link.preferredFramesPerSecond = 30;
    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)axs_notifyliquid_stopLink {
    [self.link invalidate];
    self.link = nil;
}

- (void)axs_notifyliquid_tick:(CADisplayLink *)link {
    AxsNotifyLiquidConfig *config = [AxsNotifyLiquidConfig axs_notifyliquid_shared];
    if (![config axs_notifyliquid_isEnabled]) {
        [self axs_notifyliquid_stopLink];
        return;
    }
    double t = self.phase += link.duration > 0 ? link.duration : 1.0 / 30.0;
    self.frameCounter++;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    BOOL gradientOn = [config axs_notifyliquid_gradientOn];
    BOOL glassOn = [config axs_notifyliquid_glassOn];
    double gSpeed = [config axs_notifyliquid_gradientSpeed];
    double gOpacity = [config axs_notifyliquid_gradientOpacity];
    double hue1 = [config axs_notifyliquid_gradientHue1];
    double hue2 = [config axs_notifyliquid_gradientHue2];
    double glassIntensity = [config axs_notifyliquid_glassIntensity];

    for (NSInteger i = (NSInteger)self.effects.count - 1; i >= 0; i--) {
        AxsNotifyLiquidEffect *e = self.effects[(NSUInteger)i];
        UIView *v = e.view;
        if (!v) {
            [e.gradient removeFromSuperlayer];
            [e.glass removeFromSuperlayer];
            [e.tint removeFromSuperlayer];
            [e.edge removeFromSuperlayer];
            [e.chromaR removeFromSuperlayer];
            [e.chromaG removeFromSuperlayer];
            [e.chromaB removeFromSuperlayer];
            [e.innerGlow removeFromSuperlayer];
            [self.effects removeObjectAtIndex:(NSUInteger)i];
            continue;
        }

        // 流动渐变：色相随时间漂移 + 渐变位点往复移动（"流动"感）。
        if (gradientOn) {
            e.gradient.opacity = (float)gOpacity;
            UIColor *c1 = [UIColor colorWithHue:(CGFloat)fmod(hue1 + t * 0.04, 1.0) saturation:0.75 brightness:1 alpha:1];
            UIColor *c2 = [UIColor colorWithHue:(CGFloat)fmod(hue2 + t * 0.04, 1.0) saturation:0.75 brightness:1 alpha:1];
            UIColor *cm = [UIColor colorWithHue:(CGFloat)fmod((hue1 + hue2) / 2.0 + t * 0.04, 1.0) saturation:0.75 brightness:1 alpha:1];
            e.gradient.colors = @[(id)c1.CGColor, (id)cm.CGColor, (id)c2.CGColor];
            double travel = (sin(t * gSpeed * 2.0) + 1.0) / 2.0;   // 0..1 往复
            double span = 0.25;
            double l0 = fmax(0.0, fmin(1.0, travel * (1.0 - span)));
            double l2 = fmax(0.0, fmin(1.0, l0 + span));
            e.gradient.locations = @[@(l0), @((l0 + l2) / 2.0), @(l2)];
        } else if (e.gradient.opacity != 0) {
            e.gradient.opacity = 0;
        }

        // ── 液态玻璃（LiquidGlassKit 复刻）：材质 + 高光动画 + 边缘 + 阴影 ──
        if (glassOn) {
            // 材质着色：清透(无) / 磨砂(白) / 着色(色相) / 暗色(黑)。
            NSInteger material = [config axs_notifyliquid_glassMaterial];
            double tintHue = [config axs_notifyliquid_glassTintHue];
            UIColor *tintColor = [UIColor clearColor];
            float tintAlpha = 0;
            switch (material) {
                case 1: tintColor = [UIColor whiteColor]; tintAlpha = (float)(0.12 * glassIntensity); break;
                case 2: tintColor = [UIColor colorWithHue:(CGFloat)tintHue saturation:0.6 brightness:1 alpha:1];
                        tintAlpha = (float)(0.22 * glassIntensity); break;
                case 3: tintColor = [UIColor blackColor]; tintAlpha = (float)(0.30 * glassIntensity); break;
                default: break;
            }
            e.tint.colors = @[(id)tintColor.CGColor, (id)tintColor.CGColor];
            e.tint.opacity = tintAlpha;

            // 高光动画三模式（LiquidGlassKit: shimmer / pulse / breathe）。
            NSInteger mode = [config axs_notifyliquid_highlightMode];
            if (mode == 1) {
                // shimmer：斜向光带缓慢扫过。
                e.glass.opacity = (float)(0.8 * glassIntensity);
                double pos = (sin(t * 0.5) + 1.0) / 2.0;
                double w = 0.25;
                double g0 = fmax(0.0, fmin(1.0, pos - w));
                double g2 = fmax(0.0, fmin(1.0, pos + w));
                e.glass.locations = @[@(g0), @(pos), @(g2)];
            } else if (mode == 2) {
                // pulse：亮度按节奏脉冲（1.5 秒周期）。
                e.glass.locations = @[@0, @0.5, @1];
                double pulse = (sin(t * 2.0 * M_PI / 1.5) + 1.0) / 2.0;
                e.glass.opacity = (float)((0.15 + 0.55 * pulse) * glassIntensity);
            } else if (mode == 3) {
                // breathe：高光缓慢呼吸（4 秒周期）。
                e.glass.locations = @[@0, @0.5, @1];
                double breathe = (sin(t * 2.0 * M_PI / 4.0) + 1.0) / 2.0;
                e.glass.opacity = (float)((0.10 + 0.50 * breathe) * glassIntensity);
            } else if (e.glass.opacity != 0) {
                e.glass.opacity = 0;
            }

            // 边缘高光（一圈亮边，随高光模式轻微明暗呼吸）。
            BOOL chromaOn = [config axs_notifyliquid_edgeChroma];
            if ([config axs_notifyliquid_edgeOn]) {
                double ei = [config axs_notifyliquid_edgeIntensity];
                e.edge.opacity = chromaOn ? 0 : 1.0f;   // 色散模式下白色边让位给彩边
                e.edge.strokeColor = [UIColor colorWithWhite:1 alpha:(CGFloat)(0.35 + 0.35 * ei)].CGColor;
            } else if (e.edge.opacity != 0) {
                e.edge.opacity = 0;
            }

            // 色散边缘：RGB 三描边微偏移（Liquid Glass 标志性彩虹分离）。
            if (chromaOn && [config axs_notifyliquid_edgeOn]) {
                float chromaAlpha = (float)(0.35 + 0.35 * [config axs_notifyliquid_edgeIntensity]);
                e.chromaR.opacity = chromaAlpha;
                e.chromaG.opacity = chromaAlpha;
                e.chromaB.opacity = chromaAlpha;
            } else if (e.chromaR.opacity != 0) {
                e.chromaR.opacity = 0;
                e.chromaG.opacity = 0;
                e.chromaB.opacity = 0;
            }

            // 内发光：玻璃内侧边缘柔光。
            if ([config axs_notifyliquid_innerGlowOn]) {
                e.innerGlow.opacity = (float)(0.8 * [config axs_notifyliquid_innerGlowIntensity]);
            } else if (e.innerGlow.opacity != 0) {
                e.innerGlow.opacity = 0;
            }

            // 阴影（LiquidGlassKit 的 shadow）。
            if ([config axs_notifyliquid_shadowOn]) {
                double si = [config axs_notifyliquid_shadowIntensity];
                v.layer.shadowColor = [UIColor blackColor].CGColor;
                v.layer.shadowRadius = (CGFloat)(4.0 + 10.0 * si);
                v.layer.shadowOpacity = (float)(0.45 * si);
                v.layer.shadowOffset = CGSizeMake(0, 6);
            } else if (v.layer.shadowOpacity != 0) {
                v.layer.shadowOpacity = 0;
            }
        } else {
            if (e.glass.opacity != 0) e.glass.opacity = 0;
            if (e.tint.opacity != 0) e.tint.opacity = 0;
            if (e.edge.opacity != 0) e.edge.opacity = 0;
            if (e.chromaR.opacity != 0) { e.chromaR.opacity = 0; e.chromaG.opacity = 0; e.chromaB.opacity = 0; }
            if (e.innerGlow.opacity != 0) e.innerGlow.opacity = 0;
            if (v.layer.shadowOpacity != 0) v.layer.shadowOpacity = 0;
        }
    }

    [CATransaction commit];

    if (self.effects.count == 0) [self axs_notifyliquid_stopLink];
}

- (void)dealloc {
    [self axs_notifyliquid_stopLink];
}

@end
