#import "AxsNotifyLiquidAnimator.h"
#import "AxsNotifyLiquidConfig.h"
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <math.h>

// 单条通知的效果容器（视图弱引用，通知消失自动失效）。
@interface AxsNotifyLiquidEffect : NSObject
@property (nonatomic, weak) UIView *view;
@property (nonatomic, strong) CAGradientLayer *gradient;   // 流动渐变背景
@property (nonatomic, strong) CAGradientLayer *glass;      // 流动高光
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

        // 液态玻璃高光：光带位置缓慢往复（locations 必须钳制在 [0,1]，越界 CA 不渲染）。
        if (glassOn) {
            e.glass.opacity = (float)(0.8 * glassIntensity);
            double pos = (sin(t * 0.5) + 1.0) / 2.0;   // 0..1
            double w = 0.25;
            double g0 = fmax(0.0, fmin(1.0, pos - w));
            double g2 = fmax(0.0, fmin(1.0, pos + w));
            e.glass.locations = @[@(g0), @(pos), @(g2)];
        } else if (e.glass.opacity != 0) {
            e.glass.opacity = 0;
        }
    }

    [CATransaction commit];

    if (self.effects.count == 0) [self axs_notifyliquid_stopLink];
}

- (void)dealloc {
    [self axs_notifyliquid_stopLink];
}

@end
