ifeq ("$(TARGET_PRODUCT)","Unix")

ifeq ("$(TARGET_OS)","darwin")

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_CATEGORY_PATH := samples
LOCAL_MODULE := RollingSpiderOK
LOCAL_DESCRIPTION := Rolling Spider OK

LOCAL_LIBRARIES := ARSDKBuildUtils libARSAL libARCommands libARNetwork libARNetworkAL libARDiscovery

LOCAL_SRC_FILES := DeviceController.m RollingSpiderTest.m

LOCAL_LDLIBS := -framework Foundation -framework CoreBluetooth -framework CoreGraphics
LOCAL_CFLAGS := -fobjc-arc

include $(BUILD_EXECUTABLE)

endif

endif
