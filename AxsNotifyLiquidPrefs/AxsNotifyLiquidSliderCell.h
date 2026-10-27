#pragma once

#import <Preferences/PSTableCell.h>
#import <Preferences/PSSpecifier.h>
#include <math.h>

@protocol AxsNotifyLiquidSliderCellHandler <NSObject>
- (double)axs_notifyliquid_sliderValueForSpecifier:(PSSpecifier *)specifier;
- (void)axs_notifyliquid_setSliderValue:(double)value specifier:(PSSpecifier *)specifier;
@end

@interface AxsNotifyLiquidSliderCell : PSTableCell
@property (nonatomic, weak) id<AxsNotifyLiquidSliderCellHandler> handler;
- (void)axs_notifyliquid_reloadState;
@end
