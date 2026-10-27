#import "AxsNotifyLiquidRootListController.h"
#import "AxsNotifyLiquidPreferences.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>
#import "AxsNotifyLiquidSliderCell.h"

@interface AxsNotifyLiquidRootListController () <AxsNotifyLiquidSliderCellHandler>
@end

@implementation AxsNotifyLiquidRootListController

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *items = [[self loadSpecifiersFromPlistName:@"AxsNotifyLiquidRoot"
                                                           target:self] mutableCopy];
        [items addObject:[PSSpecifier preferenceSpecifierNamed:@"关于我们" target:self
                     set:nil get:nil detail:nil cell:PSGroupCell edit:nil]];
        [self axs_notifyliquid_addButton:@"Sileo 越狱源" action:@selector(axs_notifyliquid_openRepository:) to:items];
        [self axs_notifyliquid_addButton:@"TG分享频道" action:@selector(axs_notifyliquid_openTelegram:) to:items];
        [self axs_notifyliquid_addButton:@"QQ交流群组" action:@selector(axs_notifyliquid_openQQ:) to:items];
        _specifiers = items;
    }
    return _specifiers;
}

- (void)axs_notifyliquid_addButton:(NSString *)title action:(SEL)action to:(NSMutableArray *)items {
    PSSpecifier *item = [PSSpecifier preferenceSpecifierNamed:title target:self
                          set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    item.buttonAction = action;
    [items addObject:item];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (key.length == 0) return nil;
    return axs_notifyliquid_readPreferences()[key] ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (key.length == 0) return;
    NSError *error = nil;
    if (!axs_notifyliquid_writePreference(key, value, &error)) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置未保存"
            message:error.localizedDescription ?: @"请检查配置文件路径和写入权限。"
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self reloadSpecifiers];
    }
}

- (void)axs_notifyliquid_openURL:(NSURL *)url fallback:(NSURL *)fallback {
    if (!url) return;
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
        if (success) return;
        if (fallback) {
            [self axs_notifyliquid_openURL:fallback fallback:nil];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"无法打开链接"
                message:@"请确认已安装对应应用。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

- (void)axs_notifyliquid_openRepository:(id)sender {
    NSString *source = @"https://axs66.github.io/pro";
    // Encode the entire URL as a path component, including its own delimiters.
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
                              @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    NSString *encoded = [source stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    NSURL *primary = [NSURL URLWithString:[@"sileo://source/" stringByAppendingString:encoded]];
    [self axs_notifyliquid_openURL:primary fallback:[NSURL URLWithString:source]];
}

- (void)axs_notifyliquid_openTelegram:(id)sender {
    [self axs_notifyliquid_openURL:[NSURL URLWithString:@"tg://resolve?domain=wxfx8"]
                   fallback:[NSURL URLWithString:@"https://t.me/wxfx8"]];
}

- (void)axs_notifyliquid_openQQ:(id)sender {
    [self axs_notifyliquid_openURL:[NSURL URLWithString:@"mqqapi://card/show_pslcard?src_type=internal&version=1&uin=678055716&card_type=group&source=qrcode"] fallback:nil];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([PSListController instancesRespondToSelector:_cmd]) {
        [super tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
    if ([cell isKindOfClass:[AxsNotifyLiquidSliderCell class]]) {
        AxsNotifyLiquidSliderCell *sliderCell = (AxsNotifyLiquidSliderCell *)cell;
        sliderCell.handler = self;
        [sliderCell axs_notifyliquid_reloadState];
    }
}

- (double)axs_notifyliquid_sliderValueForSpecifier:(PSSpecifier *)specifier {
    id value = [self readPreferenceValue:specifier];
    return [value isKindOfClass:[NSNumber class]] ? [value doubleValue] : 0.0;
}

- (void)axs_notifyliquid_setSliderValue:(double)value specifier:(PSSpecifier *)specifier {
    double minimum = [[specifier propertyForKey:@"min"] doubleValue];
    double maximum = [[specifier propertyForKey:@"max"] doubleValue];
    if (!isfinite(minimum)) minimum = 0.0;
    if (!isfinite(maximum) || maximum <= minimum) maximum = minimum + 1.0;
    if (!isfinite(value)) value = minimum;
    [self setPreferenceValue:@(fmax(minimum, fmin(maximum, value))) specifier:specifier];
}

// 打开素材文件夹（不存在则创建），跳 Filza。素材放这里，路径填
// /var/mobile/Documents/NotifyLiquid/文件名.png 即可。
- (void)axs_notifyliquid_openAssetsFolder:(id)sender {
    NSString *dir = @"/var/mobile/Documents/NotifyLiquid";
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    NSURL *url = [NSURL URLWithString:[@"filza://" stringByAppendingString:dir]];
    if (url) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

#pragma mark - 自定义预设（保存 / 应用 / 删除）

static NSArray<NSString *> *axs_notifyliquid_presetKeys(void) {
    return @[@"enabled", @"notify_scale",
             @"gradient_on", @"gradient_hue1", @"gradient_hue2",
             @"gradient_speed", @"gradient_opacity",
             @"color_source", @"dark_dim",
             @"burst_on", @"burst_intensity", @"dissolve_on",
             @"appear_mode", @"elastic_intensity", @"touch_glow_on",
             @"fish_on", @"fish_count", @"fish_size", @"fish_png",
             @"bubble_size", @"bubble_opacity",
             @"particle_on", @"particle_png", @"particle_density",
             @"particle_size", @"particle_dir",
             @"charge_fx", @"low_power_guard",
             @"auto_schedule", @"schedule_day", @"schedule_night"];
}

- (void)axs_notifyliquid_savePreset:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存预设"
        message:@"给当前配置起个名字" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"例如：星空夜";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *act) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceCharacterSet]];
        if (name.length == 0) return;
        NSDictionary *all = axs_notifyliquid_readPreferences();
        NSMutableDictionary *settings = [NSMutableDictionary dictionary];
        for (NSString *key in axs_notifyliquid_presetKeys()) {
            id v = all[key];
            if (v) settings[key] = v;
        }
        NSArray *existing = [all[@"custom_presets"] isKindOfClass:[NSArray class]] ? all[@"custom_presets"] : @[];
        NSMutableArray *presets = [existing mutableCopy];
        [presets addObject:@{@"name": name, @"settings": settings}];
        NSError *error = nil;
        axs_notifyliquid_writePreference(@"custom_presets", presets, &error);
        [self reloadSpecifiers];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)axs_notifyliquid_managePresets:(id)sender {
    NSDictionary *all = axs_notifyliquid_readPreferences();
    NSArray<NSDictionary *> *presets = [all[@"custom_presets"] isKindOfClass:[NSArray class]] ? all[@"custom_presets"] : @[];
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"已存预设"
        message:presets.count ? nil : @"还没有保存的预设" preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary *preset in presets) {
        NSString *name = [preset objectForKey:@"name"] ?: @"未命名";
        [sheet addAction:[UIAlertAction actionWithTitle:[@"应用：" stringByAppendingString:name]
            style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
            NSDictionary *settings = [preset objectForKey:@"settings"];
            if ([settings isKindOfClass:[NSDictionary class]]) {
                NSError *error = nil;
                for (NSString *key in axs_notifyliquid_presetKeys()) {
                    id v = settings[key];
                    if (v) axs_notifyliquid_writePreference(key, v, &error);
                }
                [self reloadSpecifiers];
            }
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:[@"删除：" stringByAppendingString:name]
            style:UIAlertActionStyleDestructive handler:^(UIAlertAction *act) {
            NSMutableArray *next = [presets mutableCopy];
            [next removeObject:preset];
            NSError *error = nil;
            axs_notifyliquid_writePreference(@"custom_presets", next, &error);
            [self reloadSpecifiers];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.view;
    [self presentViewController:sheet animated:YES completion:nil];
}

@end
