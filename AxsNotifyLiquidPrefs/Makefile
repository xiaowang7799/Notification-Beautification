include ../AxsNotifyLiquidBuild.mk
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AxsNotifyLiquidPrefs
AxsNotifyLiquidPrefs_FILES = $(wildcard *.m)
AxsNotifyLiquidPrefs_CFLAGS = -fobjc-arc -I../Sources
AxsNotifyLiquidPrefs_FRAMEWORKS = UIKit Foundation CoreFoundation
AxsNotifyLiquidPrefs_PRIVATE_FRAMEWORKS = Preferences
AxsNotifyLiquidPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
