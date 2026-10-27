#pragma once

#import <UIKit/UIKit.h>

// Declare only private interfaces confirmed on the target iOS version.
//
// 锁屏通知视图是 UIView 子类（iOS 15–18 稳定），声明为 UIView 子类即可解析
// window / layoutSubviews 等 UIView 成员。不发任何未验证的私有 selector。
@interface NCNotificationShortLookView : UIView
@end

@interface NCNotificationLongLookView : UIView
@end
