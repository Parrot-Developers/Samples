ifeq ("$(TARGET_OS_FLAVOUR)","native")

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_CATEGORY_PATH := samples
LOCAL_MODULE := JumpingSumoSample
LOCAL_DESCRIPTION := JumpingSumo sample

LOCAL_LIBRARIES := \
	libARSAL \
	libARController \
	libARDiscovery \
	ncurses

LOCAL_SRC_FILES := \
	$(call all-c-files-under,.)

include $(BUILD_EXECUTABLE)

endif
