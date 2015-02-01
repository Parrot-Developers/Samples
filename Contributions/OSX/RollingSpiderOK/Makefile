LIBAR=../../../../ARSDKBuildUtils/Targets/Unix/Install

FRAMEWORKS=-framework Foundation -framework CoreBluetooth -framework CoreGraphics
INCLUDES=-I$(LIBAR)/include -I.
LIBDIR=-L$(LIBAR)/lib
LIBS=-lardiscovery -larnetworkal -larsal -larnetwork -larcommands

RSLIB=DeviceController.m

RollingSpiderTest: RollingSpiderTest.m Makefile $(RSLIB)
	clang -g -fobjc-arc $(LIBDIR) $(INCLUDES) $(LIBS) $(FRAMEWORKS) $(RSLIB) $< -o $@

run: RollingSpiderTest
	./RollingSpiderTest

clean:
	rm -rf RollingSpiderTest *.dSYM *~
