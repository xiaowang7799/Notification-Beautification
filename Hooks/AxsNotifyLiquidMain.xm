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

%end

%ctor {
    @autoreleasepool {
        // Readers load a snapshot; they never write default preferences.
        [AxsNotifyLiquidConfig axs_notifyliquid_shared];
    }
}
