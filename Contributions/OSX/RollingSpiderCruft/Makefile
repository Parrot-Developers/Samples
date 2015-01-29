LIBAR=../../../../ARSDKBuildUtils/Targets/Unix/Install

FRAMEWORKS=-framework Foundation -framework CoreBluetooth -framework CoreGraphics
INCLUDES=-I$(LIBAR)/include
LIBDIR=-L$(LIBAR)/lib
LIBS=-lardiscovery -larnetworkal -larsal -larnetwork -larcommands

RSLIB=RSlib/MiniDroneARNetworkConfig.m RSlib/ARNetworkConfig.m	\
RSlib/DeviceController.m RSlib/DeviceController+libARCommands.m	\
RSlib/MiniDroneDeviceController.m				\
RSlib/MiniDroneDeviceController+libARCommands.m

RollingSpiderTest: RollingSpiderTest.m Makefile
	clang -g -fobjc-arc $(LIBDIR) $(INCLUDES) $(LIBS) $(FRAMEWORKS) $(RSLIB) $< -o $@

clean:
	rm -rf RollingSpiderTest *.dSYM *~
