
# Prebuilt modules used as dependencies for Unix build

ifeq ("$(TARGET_OS_FLAVOUR)","native")

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := ncurses
LOCAL_EXPORT_LDLIBS := -lncurses
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := ffmpeg
LOCAL_EXPORT_C_INCLUDES := $(shell pkg-config --cflags libavcodec libavformat libswscale libavutil)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs libavcodec libavformat libswscale libavutil)
include $(BUILD_PREBUILT)

endif
