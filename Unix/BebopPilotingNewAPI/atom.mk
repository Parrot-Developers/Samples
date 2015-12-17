ifeq ("$(TARGET_PRODUCT)","Unix")

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_CATEGORY_PATH := samples
LOCAL_MODULE := BebopPilotingNewAPI
LOCAL_DESCRIPTION := Bebop Piloting Using ARDeviceController

LOCAL_LIBRARIES := ARSDKBuildUtils libARSAL libARController libARDataTransfer libARUtils libARCommands libARNetwork libARNetworkAL libARDiscovery libARStream libARStream2

LOCAL_SRC_FILES := \
	$(call all-c-files-under,.)

ifeq ("$(TARGET_OS)","darwin")
  LOCAL_C_INCLUDES := -I/usr/local/include
  LOCAL_LDLIBS := -L/usr/local/lib
endif

#LOCAL_LDLIBS += -lncurses -lavcodec -lavformat -lswscale -lavutil
LOCAL_LDLIBS += -lncurses

include $(BUILD_EXECUTABLE)

endif
