#import <UIKit/UIKit.h>
#import "AxsNotifyLiquidConfig.h"
#import "AxsNotifyLiquidAnimator.h"
#import "AxsNotifyLiquidPrivate.h"

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

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    // 触摸发光（touch glow）：高光脉冲 + 微挤压。
    [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_touchGlowForView:self];
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

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    [[AxsNotifyLiquidAnimator axs_notifyliquid_shared] axs_notifyliquid_touchGlowForView:self];
}

%end

%ctor {
    @autoreleasepool {
        // Readers load a snapshot; they never write default preferences.
        [AxsNotifyLiquidConfig axs_notifyliquid_shared];
    }
}

// ── 界面净化：隐藏「通知中心」标题字与「清除所有通知」按钮 ───────────────────────
// 按文字匹配（中英），避开通知本体内的同名文字；清除按钮连同最近的 UIControl 祖先一起隐藏。

static BOOL axs_notifyliquid_isInNotificationBody(UIView *view) {
    UIView *p = view.superview;
    while (p) {
        NSString *cls = NSStringFromClass([p class]);
        if ([cls containsString:@"ShortLook"] || [cls containsString:@"LongLook"]) return YES;
        p = p.superview;
    }
    return NO;
}

static void axs_notifyliquid_checkChrome(UILabel *label) {
    AxsNotifyLiquidConfig *config = [AxsNotifyLiquidConfig axs_notifyliquid_shared];
    if (![config axs_notifyliquid_isEnabled]) return;
    BOOL hideTitle = [config axs_notifyliquid_hideNcTitle];
    BOOL hideClear = [config axs_notifyliquid_hideClearAll];
    if (!hideTitle && !hideClear) return;

    NSString *trimmed = [(label.text ?: @"") stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL isTitle = [trimmed isEqualToString:@"通知中心"]
                || [trimmed isEqualToString:@"Notification Center"];
    BOOL isClear = [trimmed isEqualToString:@"清除所有通知"]
                || [trimmed isEqualToString:@"清除所有"]
                || [trimmed isEqualToString:@"全部清除"]
                || [trimmed isEqualToString:@"Clear All Notifications"]
                || [trimmed isEqualToString:@"Clear All"];
    if (isTitle && !hideTitle) return;
    if (isClear && !hideClear) return;
    if (!isTitle && !isClear) return;
    // 通知本体里的同名文字不动（比如用户真收到一条写着"清除所有"的通知）。
    if (axs_notifyliquid_isInNotificationBody(label)) return;

    UIView *target = label;
    if (isClear) {
        // 清除按钮：连最近的 UIControl 祖先一起隐藏（否则剩一个透明可点区域）。
        UIView *p = label.superview;
        while (p && ![p isKindOfClass:[UIControl class]]) p = p.superview;
        if (p) target = p;
    } else {
        // 标题：祖先里有 Header 容器则整块隐藏（去掉空白间隙）。
        UIView *p = label.superview;
        while (p) {
            if ([NSStringFromClass([p class]) containsString:@"Header"]) { target = p; break; }
            p = p.superview;
        }
    }
    target.hidden = YES;
}

%hook UILabel
- (void)setText:(NSString *)text {
    %orig;
    axs_notifyliquid_checkChrome(self);
}
- (void)setAttributedText:(NSAttributedString *)text {
    %orig;
    axs_notifyliquid_checkChrome(self);
}
%end
