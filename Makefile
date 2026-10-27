DEBUG = 0
FINALPACKAGE = 1

ARCHS = arm64 arm64e

# Share the SDK and deployment targets with the PreferenceBundle.
include AxsNotifyLiquidBuild.mk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AxsNotifyLiquid
AxsNotifyLiquid_FILES = $(wildcard Hooks/*.xm Sources/*.m)
AxsNotifyLiquid_CFLAGS = -fobjc-arc -I./Headers -I./Sources
AxsNotifyLiquid_FRAMEWORKS = UIKit Foundation CoreFoundation
AxsNotifyLiquid_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += AxsNotifyLiquidPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
