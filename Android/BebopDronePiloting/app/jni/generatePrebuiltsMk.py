libs = [
'libARCommands',
'libARDiscovery',
'libARNetwork',
'libARNetworkAL',
'libARSAL',
'json',
]

andMkTmpName = 'prebuilts.mk'

REL_PATH_LIBS = '../../../../../../out/Android-$(MY_ARCH_ABI)/staging/usr/lib'
REL_PATH_INCLUDE = '../../../../../../out/Android-$(MY_ARCH_ABI)/staging/usr/include'

andMk = open(andMkTmpName, 'w')
andMk.write('LOCAL_PATH := $(call my-dir)\n')
andMk.write('\n')

andMk.write('# Rename armeabi-v7a to armeabi_v7a, note there should be no space in subst arguments\n')
andMk.write('MY_ARCH_ABI := $(subst -,_,$(TARGET_ARCH_ABI))\n')
andMk.write('\n')

andMk.write('REL_PATH_LIBS := %(REL_PATH_LIBS)s\n' % locals())
andMk.write('REL_PATH_INCLUDE := %(REL_PATH_INCLUDE)s\n' % locals())

andMk.write('\n')

for soName in libs:
    libPrefix = 'lib' if not soName.startswith('lib') else ''
    libPrefixUpper = libPrefix.upper()
    
    soNameUpper = libPrefixUpper + soName.upper()
    soNameLower = libPrefix + soName.lower()
    pbName = '%(soName)s-prebuilt' % locals()
    andMk.write('# %(soName)s\n' % locals())
    andMk.write('include $(CLEAR_VARS)\n')
    andMk.write('\n')
    andMk.write('LOCAL_MODULE := %(pbName)s\n' % locals())

    andMk.write('LOCAL_SRC_FILES := $(REL_PATH_LIBS)/%(soNameLower)s.so' % locals() + '\n')
    andMk.write('LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/$(REL_PATH_INCLUDE)\n')
    
    andMk.write('\n')
    andMk.write('include $(PREBUILT_SHARED_LIBRARY)\n')
    andMk.write('\n')
