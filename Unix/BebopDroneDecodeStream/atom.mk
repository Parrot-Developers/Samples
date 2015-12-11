ifeq ("$(TARGET_PRODUCT)","Unix")

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_CATEGORY_PATH := samples
LOCAL_MODULE := BebopDroneDecodeStream
LOCAL_DESCRIPTION := Bebop Drone Decode Stream

LOCAL_LIBRARIES := ARSDKBuildUtils libARSAL libARCommands libARNetwork libARNetworkAL libARDiscovery libARStream
LOCAL_LIBRARIES += ncurses ffmpeg

LOCAL_SRC_FILES := \
	$(call all-c-files-under,.)

include $(BUILD_EXECUTABLE)

endif
