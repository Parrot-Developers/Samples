ifeq ("$(TARGET_PRODUCT)","Unix")

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_CATEGORY_PATH := samples
LOCAL_MODULE := BebopDroneDecodeStream
LOCAL_DESCRIPTION := Bebop Drone Decode Stream

LOCAL_LIBRARIES := ARSDKBuildUtils libARSAL libARCommands libARNetwork libARNetworkAL libARDiscovery libARStream

LOCAL_SRC_FILES := \
	$(call all-c-files-under,.)

ifeq ("$(TARGET_OS)","darwin")
  LOCAL_C_INCLUDES := -I/usr/local/include
  LOCAL_LDLIBS := -L/usr/local/lib
endif

LOCAL_LDLIBS += -lncurses -lavcodec -lavformat -lswscale -lavutil

include $(BUILD_EXECUTABLE)

endif
