LOCAL_PATH := $(call my-dir)

# Include makefiles here. Its important that these 
# includes are done after the main module, explanation below.

# create a temp variable with the current path, because it 
# changes after each include
ZPATH := $(LOCAL_PATH)

# Rename armeabi-v7a to armeabi_v7a, note there should be no space in subst arguments
MY_ARCH_ABI := $(subst -,_,$(TARGET_ARCH_ABI))
include $(ZPATH)/../../../../out/Android-$(MY_ARCH_ABI)/sdk/Android.mk

include $(ZPATH)/../../../../../../libARCommands/Android.mk
include $(ZPATH)/../../../../../../libARController/Android.mk
include $(ZPATH)/../../../../../../libARDiscovery/Android.mk
include $(ZPATH)/../../../../../../libARNetworkAL/Android.mk
include $(ZPATH)/../../../../../../libARNetwork/Android.mk
include $(ZPATH)/../../../../../../libARSAL/Android.mk
include $(ZPATH)/../../../../../../libARStream/Android.mk
include $(ZPATH)/../../../../../../libARStream2/Android.mk
