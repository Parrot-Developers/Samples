LOCAL_PATH := $(call my-dir)

# Rename armeabi-v7a to armeabi_v7a, note there should be no space in subst arguments
MY_ARCH_ABI := $(subst -,_,$(TARGET_ARCH_ABI))

REL_PATH_LIBS := ../../../../../../out/Android-$(MY_ARCH_ABI)/staging/usr/lib
REL_PATH_INCLUDE := ../../../../../../out/Android-$(MY_ARCH_ABI)/staging/usr/include

# libARCommands
include $(CLEAR_VARS)

LOCAL_MODULE := libARCommands-prebuilt
LOCAL_SRC_FILES := $(REL_PATH_LIBS)/libarcommands.so
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/$(REL_PATH_INCLUDE)

include $(PREBUILT_SHARED_LIBRARY)

# libARDiscovery
include $(CLEAR_VARS)

LOCAL_MODULE := libARDiscovery-prebuilt
LOCAL_SRC_FILES := $(REL_PATH_LIBS)/libardiscovery.so
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/$(REL_PATH_INCLUDE)

include $(PREBUILT_SHARED_LIBRARY)

# libARNetwork
include $(CLEAR_VARS)

LOCAL_MODULE := libARNetwork-prebuilt
LOCAL_SRC_FILES := $(REL_PATH_LIBS)/libarnetwork.so
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/$(REL_PATH_INCLUDE)

include $(PREBUILT_SHARED_LIBRARY)

# libARNetworkAL
include $(CLEAR_VARS)

LOCAL_MODULE := libARNetworkAL-prebuilt
LOCAL_SRC_FILES := $(REL_PATH_LIBS)/libarnetworkal.so
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/$(REL_PATH_INCLUDE)

include $(PREBUILT_SHARED_LIBRARY)

# libARSAL
include $(CLEAR_VARS)

LOCAL_MODULE := libARSAL-prebuilt
LOCAL_SRC_FILES := $(REL_PATH_LIBS)/libarsal.so
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/$(REL_PATH_INCLUDE)

include $(PREBUILT_SHARED_LIBRARY)

# json
include $(CLEAR_VARS)

LOCAL_MODULE := json-prebuilt
LOCAL_SRC_FILES := $(REL_PATH_LIBS)/libjson.so
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/$(REL_PATH_INCLUDE)

include $(PREBUILT_SHARED_LIBRARY)

