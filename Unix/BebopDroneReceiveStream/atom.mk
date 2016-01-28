ifeq ("$(TARGET_OS_FLAVOUR)","native")

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_CATEGORY_PATH := samples
LOCAL_MODULE := BebopDroneReceiveStream
LOCAL_DESCRIPTION := Bebop Drone Receive Stream

LOCAL_LIBRARIES := \
	libARSAL \
	libARCommands \
	libARNetwork \
	libARNetworkAL \
	libARDiscovery \
	libARStream

LOCAL_SRC_FILES := \
	$(call all-c-files-under,.)

include $(BUILD_EXECUTABLE)

endif
