#import "AxsNotifyLiquidAnimator.h"
#import "AxsNotifyLiquidConfig.h"
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <math.h>

// 单条通知的效果容器（视图弱引用，通知消失自动失效）。
@interface AxsNotifyLiquidEffect : NSObject
@property (nonatomic, weak) UIView *view;
@property (nonatomic, strong) CAGradientLayer *gradient;   // 流动渐变背景
@property (nonatomic, strong) NSMutableArray<CALayer *> *fishLayers;  // 鱼缸游鱼
@end
@implementation AxsNotifyLiquidEffect
@end

// emoji 渲染成图片（鱼 sprite）。
static UIImage *axs_notifyliquid_emojiImage(NSString *emoji, CGFloat size) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
    NSMutableParagraphStyle *style = [NSMutableParagraphStyle new];
    style.alignment = NSTextAlignmentCenter;
    [emoji drawInRect:CGRectMake(0, size * 0.05, size, size * 0.9)
       withAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:size * 0.8],
                        NSParagraphStyleAttributeName: style}];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@interface AxsNotifyLiquidAnimator ()
@property (nonatomic, strong) NSMutableArray<AxsNotifyLiquidEffect *> *effects;
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic, assign) CFTimeInterval phase;
@end

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
    for (AxsNotifyLiquidEffect *e in self.effects) {
        if (e.view == view) {
            [self axs_notifyliquid_refreshForView:view];
            return;
        }
    }

    AxsNotifyLiquidEffect *effect = [[AxsNotifyLiquidEffect alloc] init];
    effect.view = view;
    CGFloat radius = view.layer.cornerRadius > 0 ? view.layer.cornerRadius : 24.0;

    // 流动渐变背景（三段渐变横向流动，zPosition 10 浮在通知毛玻璃背景之上）。
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = view.bounds;
    gradient.cornerRadius = radius;
    gradient.startPoint = CGPointMake(0, 0.5);
    gradient.endPoint = CGPointMake(1, 0.5);
    gradient.opacity = 0;
    gradient.zPosition = 10;
    [view.layer addSublayer:gradient];
    effect.gradient = gradient;

    // 鱼缸游鱼：预建 8 条（上限），tick 按 fish_count 显示前 N 条。
    effect.fishLayers = [NSMutableArray array];
    NSArray<NSString *> *fishEmoji = @[@"🐟", @"🐠", @"🐡", @"🐟", @"🐠", @"🐡", @"🐟", @"🐠"];
    for (NSInteger i = 0; i < 8; i++) {
        CALayer *fish = [CALayer layer];
        fish.opacity = 0;
        fish.zPosition = 6;   // 背景之上、渐变之下
        [view.layer addSublayer:fish];
        [effect.fishLayers addObject:fish];
        // sprite 用中等尺寸渲染（2x 保真），实际显示大小由 bounds + fish_size 控制。
        UIImage *img = axs_notifyliquid_emojiImage(fishEmoji[(NSUInteger)i], 40.0);
        fish.contents = (__bridge id)img.CGImage;
    }

    [self.effects addObject:effect];

    // 出现动画（五档）：果冻弹跳 / 除雾渐显 / 挤压拉伸 / 凝胶膨胀。
    NSInteger appearMode = [config axs_notifyliquid_appearMode];
    if (appearMode > 0) {
        double intensity = [config axs_notifyliquid_appearIntensity];
        double s = [config axs_notifyliquid_notifyScale];
        CAAnimationGroup *group = [CAAnimationGroup animation];
        group.removedOnCompletion = YES;
        if (appearMode == 1) {
            // 果冻弹跳（jelly pop）。
            CAKeyframeAnimation *pop = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
            pop.values = @[@(s * (1.0 - 0.25 * intensity)),
                           @(s * (1.0 + 0.08 * intensity)),
                           @(s * (1.0 - 0.03 * intensity)),
                           @(s)];
            pop.keyTimes = @[@0, @0.45, @0.75, @1.0];
            group.animations = @[pop];
            group.duration = 0.55;
        } else if (appearMode == 2) {
            // 除雾渐显（progressive defogging）：半透明雾感 → 清晰。
            CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
            fade.fromValue = @0.15;
            fade.toValue = @1.0;
            CABasicAnimation *settle = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
            settle.fromValue = @(s * 1.07);
            settle.toValue = @(s);
            group.animations = @[fade, settle];
            group.duration = 0.65;
        } else if (appearMode == 3) {
            // 挤压拉伸（squeeze & stretch）：X/Y 反相形变。
            CAKeyframeAnimation *sx = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale.x"];
            sx.values = @[@(s), @(s * (1.0 + 0.20 * intensity)),
                          @(s * (1.0 - 0.12 * intensity)), @(s * (1.0 + 0.05 * intensity)), @(s)];
            sx.keyTimes = @[@0, @0.25, @0.55, @0.8, @1.0];
            CAKeyframeAnimation *sy = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale.y"];
            sy.values = @[@(s), @(s * (1.0 - 0.18 * intensity)),
                          @(s * (1.0 + 0.12 * intensity)), @(s * (1.0 - 0.04 * intensity)), @(s)];
            sy.keyTimes = @[@0, @0.25, @0.55, @0.8, @1.0];
            group.animations = @[sx, sy];
            group.duration = 0.6;
        } else {
            // 凝胶膨胀（gel swell）：从压缩胶囊膨胀回弹。
            CAKeyframeAnimation *pop = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
            pop.values = @[@(s * (1.0 - 0.30 * intensity)),
                           @(s * (1.0 + 0.12 * intensity)),
                           @(s * (1.0 - 0.04 * intensity)),
                           @(s)];
            pop.keyTimes = @[@0, @0.5, @0.78, @1.0];
            group.animations = @[pop];
            group.duration = 0.5;
        }
        group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        [view.layer addAnimation:group forKey:@"axs_liquid_appear"];
    }

    [self axs_notifyliquid_refreshForView:view];
    [self axs_notifyliquid_ensureLink];
}

- (void)axs_notifyliquid_detachView:(UIView *)view {
    for (NSInteger i = (NSInteger)self.effects.count - 1; i >= 0; i--) {
        AxsNotifyLiquidEffect *e = self.effects[(NSUInteger)i];
        if (e.view == view || e.view == nil) {
            [e.gradient removeFromSuperlayer];
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
        e.gradient.frame = v.bounds;
        e.gradient.cornerRadius = v.layer.cornerRadius > 0 ? v.layer.cornerRadius : 24.0;
        // 通知缩放（transform，布局后重施即自愈——frame 由系统管，transform 归我们）。
        double s = [config axs_notifyliquid_notifyScale];
        v.layer.transform = CATransform3DMakeScale(s, s, 1.0);
        return;
    }
}

#pragma mark - 触摸发光（touch glow）：渐变闪亮 + 微挤压

- (void)axs_notifyliquid_touchGlowForView:(UIView *)view {
    AxsNotifyLiquidConfig *config = [AxsNotifyLiquidConfig axs_notifyliquid_shared];
    if (![config axs_notifyliquid_isEnabled] || ![config axs_notifyliquid_touchGlowOn]) return;
    for (AxsNotifyLiquidEffect *e in self.effects) {
        if (e.view != view) continue;
        // 渐变闪亮：透明度瞬间拉高再落回。
        float base = e.gradient.opacity;
        CAKeyframeAnimation *glow = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        glow.values = @[@(base), @(fmin(1.0f, base + 0.5f)), @(base)];
        glow.keyTimes = @[@0, @0.3, @1.0];
        glow.duration = 0.45;
        [e.gradient addAnimation:glow forKey:@"axs_touch_glow"];
        // 微挤压（果冻手感）。
        double s = [config axs_notifyliquid_notifyScale];
        CAKeyframeAnimation *squeeze = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        squeeze.values = @[@(s), @(s * 0.95), @(s * 1.02), @(s)];
        squeeze.keyTimes = @[@0, @0.3, @0.7, @1.0];
        squeeze.duration = 0.35;
        [view.layer addAnimation:squeeze forKey:@"axs_touch_squeeze"];
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

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    BOOL gradientOn = [config axs_notifyliquid_gradientOn];
    double gSpeed = [config axs_notifyliquid_gradientSpeed];
    double gOpacity = [config axs_notifyliquid_gradientOpacity];
    double hue1 = [config axs_notifyliquid_gradientHue1];
    double hue2 = [config axs_notifyliquid_gradientHue2];

    for (NSInteger i = (NSInteger)self.effects.count - 1; i >= 0; i--) {
        AxsNotifyLiquidEffect *e = self.effects[(NSUInteger)i];
        UIView *v = e.view;
        if (!v) {
            [e.gradient removeFromSuperlayer];
            [self.effects removeObjectAtIndex:(NSUInteger)i];
            continue;
        }

        // 流动渐变：色相随时间漂移 + 渐变位点往复移动（"流动"感，locations 钳制 [0,1]）。
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

        // 鱼缸游鱼：前 fish_count 条可见，正弦游动 + 方向翻转（数量/大小实时生效）。
        BOOL fishOn = [config axs_notifyliquid_fishOn];
        NSInteger fishCount = [config axs_notifyliquid_fishCount];
        double fishSize = [config axs_notifyliquid_fishSize];
        for (NSInteger fi = 0; fi < (NSInteger)e.fishLayers.count; fi++) {
            CALayer *fish = e.fishLayers[(NSUInteger)fi];
            if (!fishOn || fi >= fishCount) {
                if (fish.opacity != 0) fish.opacity = 0;
                continue;
            }
            fish.opacity = 0.9f;
            CGFloat displaySize = (CGFloat)(22.0 * fishSize);
            fish.bounds = CGRectMake(0, 0, displaySize, displaySize);
            double speed = 0.35 + (fi % 4) * 0.09;
            double phase = t * speed + fi * 1.3;
            CGRect b = v.bounds;
            CGFloat fishX = (CGFloat)(sin(phase) * b.size.width * 0.32) + CGRectGetMidX(b);
            CGFloat fishY = (CGFloat)(cos(phase * 0.7) * 7.0) + b.size.height * (0.40 + 0.09 * (fi % 3));
            fish.position = CGPointMake(fishX, fishY);
            fish.transform = cos(phase) < 0 ? CATransform3DMakeScale(-1, 1, 1) : CATransform3DIdentity;
        }
    }

    [CATransaction commit];

    if (self.effects.count == 0) [self axs_notifyliquid_stopLink];
}

- (void)dealloc {
    [self axs_notifyliquid_stopLink];
}

@end
