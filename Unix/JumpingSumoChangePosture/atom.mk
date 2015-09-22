ifeq ("$(TARGET_PRODUCT)","Unix")

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_CATEGORY_PATH := samples
LOCAL_MODULE := JumpingSumoChangePosture
LOCAL_DESCRIPTION := Jumping Sumo Change Posture

LOCAL_LIBRARIES := ARSDKBuildUtils libARSAL libARCommands libARNetwork libARNetworkAL libARDiscovery

LOCAL_SRC_FILES := \
	$(call all-c-files-under,.)

include $(BUILD_EXECUTABLE)

endif
