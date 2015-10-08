ifeq ("$(TARGET_PRODUCT)","Unix")

ifeq ("$(TARGET_OS)","darwin")

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_CATEGORY_PATH := samples
LOCAL_MODULE := RollingSpiderCruft
LOCAL_DESCRIPTION := Rolling Spider Cruft

LOCAL_LIBRARIES := ARSDKBuildUtils libARSAL libARCommands libARNetwork libARNetworkAL libARDiscovery

LOCAL_SRC_FILES := RollingSpiderTest.m RSlib/ARNetworkConfig.m RSlib/DeviceController+libARCommands.m RSlib/DeviceController+libARCommandsDebug.m RSlib/DeviceController.m RSlib/MiniDroneARNetworkConfig.m RSlib/MiniDroneDeviceController+libARCommands.m RSlib/MiniDroneDeviceController.m

LOCAL_LDLIBS := -framework Foundation -framework CoreBluetooth -framework CoreGraphics
LOCAL_CFLAGS := -fobjc-arc

include $(BUILD_EXECUTABLE)

endif

endif
