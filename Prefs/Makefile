ARCHS = arm64 arm64e

ifeq ($(THEOS_PACKAGE_SCHEME), rootless)
    TARGET := iphone:clang:latest:15.0
    TARGET_OS_DEPLOYMENT_VERSION = 15.0
    ifneq ($(wildcard $(THEOS)/sdks/iPhoneOS15.6.sdk),)
        SYSROOT=$(THEOS)/sdks/iPhoneOS15.6.sdk
        SDKVERSION = 15.6
        INCLUDE_SDKVERSION = 15.6
    endif
else
    TARGET := iphone:clang:latest:13.0
    TARGET_OS_DEPLOYMENT_VERSION = 13.0
endif

include $(THEOS)/makefiles/common.mk

# arm64e: clang signs the class_ro pointer of every Objective-C class, and the
# libobjc that reads it back does not always authenticate that slot. When it does
# not, the injected process dies the instant dyld maps this dylib - inside
# libobjc's readClass(), EXC_BAD_ACCESS / SIGBUS. See root Makefile for the full
# explanation - same probe, applied here too since this bundle also ships arm64e.
LX_PTRAUTH_FLAG := -fno-ptrauth-objc-class-ro
LX_PTRAUTH_SUPPORTED := $(shell $(TARGET_CC) -target arm64e-apple-ios15.0 -x objective-c \
	-fsyntax-only $(LX_PTRAUTH_FLAG) /dev/null >/dev/null 2>&1 && echo yes)

ifeq ($(LX_PTRAUTH_SUPPORTED),yes)
LX_PTRAUTH_CFLAGS := $(LX_PTRAUTH_FLAG)
else ifeq ($(filter arm64e,$(ARCHS)),)
LX_PTRAUTH_CFLAGS :=
else
$(error $(LX_PTRAUTH_FLAG) is not accepted by $(TARGET_CC), but arm64e is in ARCHS.)
endif

BUNDLE_NAME = IslandAuraPrefs

IslandAuraPrefs_FILES = $(wildcard *.m)
IslandAuraPrefs_INSTALL_PATH = /Library/PreferenceBundles
IslandAuraPrefs_FRAMEWORKS += UIKit
IslandAuraPrefs_PRIVATE_FRAMEWORKS += Preferences
IslandAuraPrefs_EXTRA_FRAMEWORKS += CepheiPrefs Cephei
# Alderis's HBColorPickerTableCell only registers with the ObjC runtime once
# /usr/lib/libcolorpicker.dylib (installed by ws.hbang.alderis) is actually
# loaded into the Preferences process. We never call its symbols directly, but
# without this link the class never loads, so the cellClass in Root.plist
# resolves to nothing and the color row silently does nothing when tapped.
IslandAuraPrefs_LIBRARIES = colorpicker
IslandAuraPrefs_CFLAGS = -fobjc-arc $(LX_PTRAUTH_CFLAGS)

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/$(BUNDLE_NAME).plist$(ECHO_END)
