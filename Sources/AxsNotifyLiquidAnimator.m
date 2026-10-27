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
@property (nonatomic, strong) NSMutableArray<NSNumber *> *fishNextBubble;  // 每条鱼的吐泡倒计时
@property (nonatomic, strong) CAEmitterLayer *burst;       // 到达粒子爆发
@property (nonatomic, strong) CAEmitterLayer *season;      // 季节粒子
@property (nonatomic, strong) UIColor *iconColor;          // 应用图标取色（缓存）
@property (nonatomic, assign) NSInteger lastParticleKey;   // 粒子样式缓存
@property (nonatomic, assign) BOOL burstPlayed;
@end
@implementation AxsNotifyLiquidEffect
@end

// emoji 渲染成图片（粒子 sprite）。
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

// 手绘小鱼（渐变身体 + 尾鳍 + 背鳍 + 眼睛高光 + 条纹）——替代 emoji 的精致版本。
static UIImage *axs_notifyliquid_fishImage(UIColor *base, CGFloat size) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat w = size, h = size;

    // 尾鳍（扇形，半透明略深）。
    UIBezierPath *tail = [UIBezierPath bezierPath];
    [tail moveToPoint:CGPointMake(w * 0.66, h * 0.5)];
    [tail addQuadCurveToPoint:CGPointMake(w * 0.97, h * 0.16)
                 controlPoint:CGPointMake(w * 0.92, h * 0.34)];
    [tail addLineToPoint:CGPointMake(w * 0.97, h * 0.84)];
    [tail addQuadCurveToPoint:CGPointMake(w * 0.66, h * 0.5)
                 controlPoint:CGPointMake(w * 0.92, h * 0.66)];
    [tail closePath];
    [[base colorWithAlphaComponent:0.75] setFill];
    [tail fill];

    // 身体（水滴形，头尖尾圆）。
    UIBezierPath *body = [UIBezierPath bezierPath];
    [body moveToPoint:CGPointMake(w * 0.05, h * 0.5)];
    [body addQuadCurveToPoint:CGPointMake(w * 0.70, h * 0.18)
                 controlPoint:CGPointMake(w * 0.34, h * 0.10)];
    [body addQuadCurveToPoint:CGPointMake(w * 0.70, h * 0.82)
                 controlPoint:CGPointMake(w * 0.92, h * 0.5)];
    [body addQuadCurveToPoint:CGPointMake(w * 0.05, h * 0.5)
                 controlPoint:CGPointMake(w * 0.34, h * 0.90)];
    [body closePath];
    // 竖向渐变（上亮下深）。
    CGFloat r = 0, g = 0, b = 0, a = 1;
    [base getRed:&r green:&g blue:&b alpha:&a];
    CGFloat topR = (CGFloat)fmin(1.0, r * 1.25 + 0.08);
    CGFloat topG = (CGFloat)fmin(1.0, g * 1.25 + 0.08);
    CGFloat topB = (CGFloat)fmin(1.0, b * 1.25 + 0.08);
    CGFloat comps[] = {topR, topG, topB, 1, (CGFloat)(r * 0.8), (CGFloat)(g * 0.8), (CGFloat)(b * 0.8), 1};
    CGFloat locs[] = {0, 1};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef grad = CGGradientCreateWithColorComponents(space, comps, locs, 2);
    CGContextSaveGState(ctx);
    [body addClip];
    CGContextDrawLinearGradient(ctx, grad, CGPointMake(0, h * 0.15), CGPointMake(0, h * 0.85), 0);
    CGContextRestoreGState(ctx);
    CGGradientRelease(grad);
    CGColorSpaceRelease(space);

    // 背鳍（小三角）。
    UIBezierPath *fin = [UIBezierPath bezierPath];
    [fin moveToPoint:CGPointMake(w * 0.40, h * 0.22)];
    [fin addQuadCurveToPoint:CGPointMake(w * 0.60, h * 0.16)
                 controlPoint:CGPointMake(w * 0.54, h * 0.02)];
    [fin addQuadCurveToPoint:CGPointMake(w * 0.50, h * 0.26)
                 controlPoint:CGPointMake(w * 0.58, h * 0.20)];
    [fin closePath];
    [[base colorWithAlphaComponent:0.9] setFill];
    [fin fill];

    // 条纹（两道浅弧）。
    [[UIColor colorWithWhite:1 alpha:0.28] setStroke];
    for (int s = 0; s < 2; s++) {
        UIBezierPath *stripe = [UIBezierPath bezierPath];
        CGFloat sx = w * (0.42 + 0.16 * s);
        [stripe moveToPoint:CGPointMake(sx, h * 0.24)];
        [stripe addQuadCurveToPoint:CGPointMake(sx, h * 0.76)
                      controlPoint:CGPointMake(sx + w * 0.12, h * 0.5)];
        stripe.lineWidth = w * 0.045;
        stripe.lineCapStyle = kCGLineCapRound;
        [stripe stroke];
    }

    // 眼睛（白 + 瞳孔 + 高光）。
    CGRect eyeRect = CGRectMake(w * 0.20, h * 0.38, w * 0.17, h * 0.17);
    [[UIColor whiteColor] setFill];
    [[UIBezierPath bezierPathWithOvalInRect:eyeRect] fill];
    [[UIColor colorWithWhite:0.08 alpha:1] setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectInset(eyeRect, w * 0.042, h * 0.042)] fill];
    [[UIColor whiteColor] setFill];
    [[UIBezierPath bezierPathWithOvalInRect:
      CGRectMake(eyeRect.origin.x + w * 0.05, eyeRect.origin.y + h * 0.05, w * 0.04, h * 0.04)] fill];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

// UIImage 平均色（壁纸/图标取色用）。
@interface UIImage (AxsNotifyLiquidAverage)
- (UIColor *)axs_notifyliquid_averageColor;
@end
@implementation UIImage (AxsNotifyLiquidAverage)
- (UIColor *)axs_notifyliquid_averageColor {
    CGImageRef cg = self.CGImage;
    if (!cg) return nil;
    size_t w = 16, h = 16;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    uint8_t *buf = (uint8_t *)calloc(w * h * 4, 1);
    if (!buf) { CGColorSpaceRelease(space); return nil; }
    CGContextRef ctx = CGBitmapContextCreate(buf, w, h, 8, w * 4, space,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    if (!ctx) { free(buf); CGColorSpaceRelease(space); return nil; }
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cg);
    double r = 0, g = 0, b = 0;
    for (size_t i = 0; i < w * h; i++) { r += buf[i*4]; g += buf[i*4+1]; b += buf[i*4+2]; }
    size_t n = w * h;
    UIColor *color = [UIColor colorWithRed:r/n/255.0 green:g/n/255.0 blue:b/n/255.0 alpha:1.0];
    CGContextRelease(ctx); CGColorSpaceRelease(space); free(buf);
    return color;
}
@end

// 壁纸主色（缓存 5 秒，避免逐帧解码）。
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static UIColor *axs_notifyliquid_wallpaperColor(void) {
    static UIColor *cached = nil;
    static CFTimeInterval cachedAt = -100.0;
    CFTimeInterval now = CFAbsoluteTimeGetCurrent();
    if (cached && now - cachedAt < 5.0) return cached;
    cachedAt = now;
    if (@available(iOS 13.0, *)) {
        Class cls = NSClassFromString(@"SBFWallpaperView");
        if (!cls) return cached;
        SEL sharedSel = NSSelectorFromString(@"sharedInstance");
        if (![cls respondsToSelector:sharedSel]) return cached;
        id view = [cls performSelector:sharedSel];
        if (!view) return cached;
        SEL imgSel = NSSelectorFromString(@"currentWallpaperImage");
        if (![view respondsToSelector:imgSel]) return cached;
        UIImage *img = [view performSelector:imgSel];
        if (![img isKindOfClass:[UIImage class]]) return cached;
        cached = [img axs_notifyliquid_averageColor];
        return cached;
    }
    return cached;
}
#pragma clang diagnostic pop

// 找通知里的应用图标（正方形小 UIImageView）。
static UIImageView *axs_notifyliquid_findIconView(UIView *view, int depth) {
    if (depth > 6) return nil;
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)sub;
            CGFloat w = iv.bounds.size.width;
            if (iv.image && w > 8 && w < 80 && fabs(w - iv.bounds.size.height) < 4) {
                return iv;
            }
        }
        UIImageView *deep = axs_notifyliquid_findIconView(sub, depth + 1);
        if (deep) return deep;
    }
    return nil;
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

    // 鱼缸游鱼：手绘小鱼 5 色（金橙/青蓝/粉/紫/绿），预建 8 条上限，tick 按 fish_count 显示前 N 条。
    effect.fishLayers = [NSMutableArray array];
    effect.fishNextBubble = [NSMutableArray array];
    NSArray<UIColor *> *palette = @[
        [UIColor colorWithRed:1.00 green:0.62 blue:0.21 alpha:1],   // 金橙
        [UIColor colorWithRed:0.25 green:0.72 blue:0.85 alpha:1],   // 青蓝
        [UIColor colorWithRed:1.00 green:0.45 blue:0.62 alpha:1],   // 粉
        [UIColor colorWithRed:0.66 green:0.42 blue:0.90 alpha:1],   // 紫
        [UIColor colorWithRed:0.36 green:0.82 blue:0.50 alpha:1],   // 绿
    ];
    for (NSInteger i = 0; i < 8; i++) {
        CALayer *fish = [CALayer layer];
        fish.opacity = 0;
        fish.zPosition = 6;   // 背景之上、渐变之下
        [view.layer addSublayer:fish];
        [effect.fishLayers addObject:fish];
        // sprite 高分辨率渲染（矢量小鱼），实际显示大小由 bounds + fish_size 控制。
        UIImage *img = axs_notifyliquid_fishImage(palette[(NSUInteger)i % palette.count], 64.0);
        fish.contents = (__bridge id)img.CGImage;
        [effect.fishNextBubble addObject:@(1.0 + (i % 5) * 0.6)];
    }

    // 应用图标取色（按 App 专属渐变色，attach 采样一次）。
    UIImageView *iconView = axs_notifyliquid_findIconView(view, 0);
    effect.iconColor = iconView.image ? [iconView.image axs_notifyliquid_averageColor] : nil;

    // 到达粒子爆发层（新通知瞬间光斑飞溅）。
    CAEmitterLayer *burst = [CAEmitterLayer layer];
    burst.frame = view.bounds;
    burst.emitterPosition = CGPointMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds));
    burst.emitterSize = CGSizeMake(6, 6);
    burst.emitterShape = kCAEmitterLayerRectangle;
    burst.renderMode = kCAEmitterLayerAdditive;
    burst.opacity = 0;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(12, 12), NO, 0);
    CGContextRef bctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(bctx, [UIColor whiteColor].CGColor);
    CGContextFillEllipseInRect(bctx, CGRectMake(3, 3, 6, 6));
    UIImage *dot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CAEmitterCell *bCell = [CAEmitterCell emitterCell];
    bCell.contents = (__bridge id)dot.CGImage;
    bCell.birthRate = 26.0;
    bCell.lifetime = 1.0;
    bCell.velocity = 110.0;
    bCell.velocityRange = 55.0;
    bCell.emissionRange = M_PI * 2;
    bCell.scale = 0.35;
    bCell.scaleRange = 0.2;
    bCell.alphaSpeed = -1.2;
    burst.emitterCells = @[bCell];
    [view.layer addSublayer:burst];
    effect.burst = burst;
    effect.burstPlayed = NO;

    // 季节粒子层（飘落 emoji）。
    CAEmitterLayer *season = [CAEmitterLayer layer];
    season.frame = view.bounds;
    season.emitterPosition = CGPointMake(CGRectGetMidX(view.bounds), -6.0);
    season.emitterSize = CGSizeMake(view.bounds.size.width, 3.0);
    season.emitterShape = kCAEmitterLayerLine;
    season.renderMode = kCAEmitterLayerUnordered;
    season.opacity = 0;
    [view.layer addSublayer:season];
    effect.season = season;
    effect.lastParticleKey = -1;

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

    // 到达粒子爆发：一次性播放。延迟 0.1s 等布局完成，按实际 bounds 中心发射
    //（挂载瞬间 bounds 可能还是零，之前光斑会跑到左上角图标处）。
    if ([config axs_notifyliquid_burstOn] && !effect.burstPlayed) {
        effect.burstPlayed = YES;
        double bi = [config axs_notifyliquid_burstIntensity];
        __weak AxsNotifyLiquidEffect *we = effect;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            AxsNotifyLiquidEffect *e = we;
            UIView *ev = e.view;
            if (!e || !ev || !e.burst) return;
            e.burst.frame = ev.bounds;
            e.burst.emitterPosition = CGPointMake(CGRectGetMidX(ev.bounds), CGRectGetMidY(ev.bounds));
            e.burst.emitterSize = CGSizeMake(MAX(6.0, ev.bounds.size.width * 0.3),
                                             MAX(6.0, ev.bounds.size.height * 0.3));
            e.burst.opacity = 1.0f;
            CAEmitterCell *bc = e.burst.emitterCells.firstObject;
            if (bc) {
                bc.birthRate = (float)(26.0 * bi);
                bc.scale = (float)(0.35 * (0.7 + 0.3 * bi));
                UIColor *source = e.iconColor ?: [UIColor colorWithHue:0.6 saturation:0.7 brightness:1 alpha:1];
                bc.color = source.CGColor;
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                AxsNotifyLiquidEffect *e2 = we;
                if (e2 && e2.burst) e2.burst.birthRate = 0;
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                AxsNotifyLiquidEffect *e2 = we;
                if (e2 && e2.burst) e2.burst.opacity = 0;
            });
        });
    }
}

- (void)axs_notifyliquid_detachView:(UIView *)view {
    for (NSInteger i = (NSInteger)self.effects.count - 1; i >= 0; i--) {
        AxsNotifyLiquidEffect *e = self.effects[(NSUInteger)i];
        if (e.view == view || e.view == nil) {
            [e.gradient removeFromSuperlayer];
            for (CALayer *f in e.fishLayers) [f removeFromSuperlayer];
            [e.burst removeFromSuperlayer];
            [e.season removeFromSuperlayer];
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
        e.burst.frame = v.bounds;
        e.burst.emitterPosition = CGPointMake(CGRectGetMidX(v.bounds), CGRectGetMidY(v.bounds));
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

#pragma mark - 消失消散（划走/清除时液态溶解）

- (void)axs_notifyliquid_dissolveForView:(UIView *)view {
    AxsNotifyLiquidConfig *config = [AxsNotifyLiquidConfig axs_notifyliquid_shared];
    if (![config axs_notifyliquid_isEnabled] || ![config axs_notifyliquid_dissolveOn]) return;
    // 整体淡出 + 轻微收缩（叠加在系统划走动画上，产生"溶解"感）。
    CAAnimationGroup *group = [CAAnimationGroup animation];
    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = @1.0;
    fade.toValue = @0.0;
    CABasicAnimation *shrink = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    shrink.fromValue = @1.0;
    shrink.toValue = @0.88;
    group.animations = @[fade, shrink];
    group.duration = 0.3;
    group.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
    group.removedOnCompletion = NO;
    group.fillMode = kCAFillModeForwards;
    [view.layer addAnimation:group forKey:@"axs_liquid_dissolve"];
    // 我们的效果层同步淡出。
    for (AxsNotifyLiquidEffect *e in self.effects) {
        if (e.view != view) continue;
        CABasicAnimation *lf = [CABasicAnimation animationWithKeyPath:@"opacity"];
        lf.fromValue = @(e.gradient.opacity);
        lf.toValue = @0.0;
        lf.duration = 0.3;
        lf.removedOnCompletion = NO;
        lf.fillMode = kCAFillModeForwards;
        [e.gradient addAnimation:lf forKey:@"axs_dissolve"];
        for (CALayer *fish in e.fishLayers) [fish addAnimation:lf forKey:@"axs_dissolve"];
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
            for (CALayer *f in e.fishLayers) [f removeFromSuperlayer];
            [e.burst removeFromSuperlayer];
            [e.season removeFromSuperlayer];
            [self.effects removeObjectAtIndex:(NSUInteger)i];
            continue;
        }

        // 流动渐变：配色来源（手动双色 / 应用图标取色 / 壁纸取色）+ 色相漂移 + 位点往复。
        if (gradientOn) {
            double dim = 1.0;
            if ([config axs_notifyliquid_darkDim]) {
                if (@available(iOS 12.0, *)) {
                    if (v.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) dim = 0.72;
                }
            }
            e.gradient.opacity = (float)(gOpacity * dim);
            UIColor *c1, *c2, *cm;
            NSInteger source = [config axs_notifyliquid_colorSource];
            if (source == 1 && e.iconColor) {
                // 应用图标取色：同色系微漂移（每条通知专属色）。
                CGFloat h, s, b;
                [e.iconColor getHue:&h saturation:&s brightness:&b alpha:nil];
                c1 = [UIColor colorWithHue:(CGFloat)fmod(h + 0.05 + t * 0.02, 1.0) saturation:MAX(s, 0.5f) brightness:1 alpha:1];
                c2 = [UIColor colorWithHue:(CGFloat)fmod(h - 0.05 + t * 0.02, 1.0) saturation:MAX(s, 0.5f) brightness:1 alpha:1];
                cm = [UIColor colorWithHue:(CGFloat)fmod(h + t * 0.02, 1.0) saturation:MAX(s, 0.5f) brightness:1 alpha:1];
            } else if (source == 2) {
                // 壁纸取色：主色 ± 微漂移。
                UIColor *wp = axs_notifyliquid_wallpaperColor();
                CGFloat h = 0.6f, s = 0.5f;
                if (wp) [wp getHue:&h saturation:NULL brightness:NULL alpha:nil];
                c1 = [UIColor colorWithHue:(CGFloat)fmod(h + 0.06 + t * 0.02, 1.0) saturation:MAX(s, 0.4f) brightness:1 alpha:1];
                c2 = [UIColor colorWithHue:(CGFloat)fmod(h - 0.06 + t * 0.02, 1.0) saturation:MAX(s, 0.4f) brightness:1 alpha:1];
                cm = [UIColor colorWithHue:(CGFloat)fmod(h + t * 0.02, 1.0) saturation:MAX(s, 0.4f) brightness:1 alpha:1];
            } else {
                c1 = [UIColor colorWithHue:(CGFloat)fmod(hue1 + t * 0.04, 1.0) saturation:0.75 brightness:1 alpha:1];
                c2 = [UIColor colorWithHue:(CGFloat)fmod(hue2 + t * 0.04, 1.0) saturation:0.75 brightness:1 alpha:1];
                cm = [UIColor colorWithHue:(CGFloat)fmod((hue1 + hue2) / 2.0 + t * 0.04, 1.0) saturation:0.75 brightness:1 alpha:1];
            }
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
            // 方向翻转：鱼图头朝左，向右游（cos>0）时镜像。
            fish.transform = cos(phase) > 0 ? CATransform3DMakeScale(-1, 1, 1) : CATransform3DIdentity;

            // 鱼吐泡泡：倒计时到 0 时从嘴边冒一个泡泡，上浮渐隐后自清。
            if (fi < (NSInteger)e.fishNextBubble.count) {
                double remain = [e.fishNextBubble[(NSUInteger)fi] doubleValue] - (link.duration > 0 ? link.duration : 1.0 / 30.0);
                if (remain <= 0) {
                    remain = 1.4 + ((double)arc4random() / UINT32_MAX) * 1.8;
                    CGFloat bs = (CGFloat)(3.5 + fishSize * 2.5);
                    CALayer *bub = [CALayer layer];
                    bub.bounds = CGRectMake(0, 0, bs, bs);
                    bub.cornerRadius = bs / 2.0;
                    bub.borderWidth = 1.1;
                    bub.borderColor = [UIColor colorWithWhite:1 alpha:0.7].CGColor;
                    bub.backgroundColor = [UIColor colorWithWhite:1 alpha:0.16].CGColor;
                    CGFloat dir = cos(phase) < 0 ? -1 : 1;
                    bub.position = CGPointMake(fish.position.x + dir * displaySize * 0.42,
                                               fish.position.y - displaySize * 0.12);
                    bub.zPosition = 7;
                    [v.layer addSublayer:bub];
                    CABasicAnimation *rise = [CABasicAnimation animationWithKeyPath:@"position.y"];
                    rise.fromValue = @(bub.position.y);
                    rise.toValue = @(bub.position.y - 42);
                    CABasicAnimation *bfade = [CABasicAnimation animationWithKeyPath:@"opacity"];
                    bfade.fromValue = @0.9;
                    bfade.toValue = @0.0;
                    CAAnimationGroup *bg = [CAAnimationGroup animation];
                    bg.animations = @[rise, bfade];
                    bg.duration = 2.2;
                    bg.removedOnCompletion = YES;
                    [bub addAnimation:bg forKey:@"axs_bubble_rise"];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.3 * NSEC_PER_SEC)),
                                   dispatch_get_main_queue(), ^{
                        [bub removeFromSuperlayer];
                    });
                }
                e.fishNextBubble[(NSUInteger)fi] = @(remain);
            }
        }

        // 季节粒子：emoji 飘落（关/❄️/🌸/🍂/⭐/❤️/自动/自定义，大小可调）。
        NSInteger pStyle = [config axs_notifyliquid_particleStyle];
        if (pStyle > 0) {
            e.season.frame = v.bounds;
            e.season.emitterPosition = CGPointMake(CGRectGetMidX(v.bounds), -6.0);
            e.season.emitterSize = CGSizeMake(v.bounds.size.width, 3.0);
            e.season.opacity = 0.85f;
            NSString *emoji = nil;
            NSInteger styleKey = pStyle;
            if (pStyle == 7) {
                // 自定义：文本按 emoji 拆分。
                NSString *custom = [config axs_notifyliquid_particleCustom];
                NSMutableArray<NSString *> *parts = [NSMutableArray array];
                [custom enumerateSubstringsInRange:NSMakeRange(0, custom.length)
                    options:NSStringEnumerationByComposedCharacterSequences
                    usingBlock:^(NSString *sub, NSRange sr, NSRange er, BOOL *stop) {
                        NSString *tr = [sub stringByTrimmingCharactersInSet:
                                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        if (tr.length > 0) [parts addObject:sub];
                    }];
                emoji = parts.count ? parts[parts.count / 2] : @"✨";
                styleKey = 7000 + (NSInteger)((NSUInteger)[custom hash] % 100000);
            } else if (pStyle == 6) {
                // 自动：按月份选季节。
                NSInteger m = [[NSCalendar currentCalendar] component:NSCalendarUnitMonth fromDate:[NSDate date]];
                emoji = (m == 12 || m <= 2) ? @"❄️" : (m <= 5 ? @"🌸" : (m <= 8 ? @"⭐" : @"🍂"));
                styleKey = 600 + m;
            } else {
                NSArray<NSString *> *pool = @[@"", @"❄️", @"🌸", @"🍂", @"⭐", @"❤️"];
                emoji = pool[(NSUInteger)pStyle < pool.count ? (NSUInteger)pStyle : 1];
            }
            if (e.lastParticleKey != styleKey) {
                e.lastParticleKey = styleKey;
                UIImage *sprite = axs_notifyliquid_emojiImage(emoji, 24.0);
                CAEmitterCell *pCell = [CAEmitterCell emitterCell];
                pCell.contents = (__bridge id)sprite.CGImage;
                pCell.birthRate = 3.5f;
                pCell.lifetime = 5.0f;
                pCell.velocity = 32.0f;
                pCell.velocityRange = 14.0f;
                pCell.emissionLongitude = M_PI_2;   // 向下飘落
                pCell.emissionRange = M_PI / 6.0;
                pCell.spin = 0.5f;
                pCell.spinRange = 1.2f;
                pCell.alphaSpeed = -0.12f;
                e.season.emitterCells = @[pCell];
            }
            double pSize = [config axs_notifyliquid_particleSize];
            CAEmitterCell *pc = e.season.emitterCells.firstObject;
            if (pc) {
                pc.scale = (float)(0.5 * pSize);
                pc.scaleRange = (float)(0.2 * pSize);
            }
        } else if (e.season.opacity != 0) {
            e.season.opacity = 0;
        }
    }

    [CATransaction commit];

    if (self.effects.count == 0) [self axs_notifyliquid_stopLink];
}

- (void)dealloc {
    [self axs_notifyliquid_stopLink];
}

@end
