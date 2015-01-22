#import <Foundation/Foundation.h>
#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>
#import <libARSAL/ARSAL.h>
#import <libARNetwork/ARNetwork.h>
#import <libARNetworkAL/ARNetworkAL.h>

#import "RSlib/MiniDroneDeviceController.h"

static const char* TAG = "DeviceController";

void discover_drone() {
  ARService *foundService = nil;
  ARDiscovery *ARD = [ARDiscovery sharedInstance];

  while(foundService == nil) {
    [NSThread sleepForTimeInterval:1];
    for (ARService *obj in [ARD getCurrentListOfDevicesServices]) {
      NSLog(@"Found Something!");
      if ([obj.service isKindOfClass:[ARBLEService class]]) {
	ARBLEService *serviceIdx = (ARBLEService *)obj.service;
	NSLog(@"%@", serviceIdx.peripheral.name);
	NSString *NAME = @"RS_";
	NSString *PREFIX = [serviceIdx.peripheral.name substringToIndex:3];
	if ([PREFIX isEqualToString:NAME]) {
      NSLog(@"Found a Rolling Spider!");
	  NSLog(@"%@", serviceIdx.peripheral);
	  foundService = obj;
	  break;
	}
      }
    }
  }

  [ARD stop];
  
  MiniDroneDeviceController *MDDC = [[MiniDroneDeviceController alloc] initWithService:foundService];
  NSLog(@"Initialized MiniDroneDeviceController");
  [MDDC start];
  [NSThread sleepForTimeInterval:5];
  NSLog(@"MDDC Started");

  NSLog(@"Blink Blink");
  [MDDC userRequestSetAutoTakeOffMode:1];
  [NSThread sleepForTimeInterval:2];

  [MDDC userRequestSetAutoTakeOffMode:0];
  [NSThread sleepForTimeInterval:2];

  //[MDDC userGazChanged:2.0];
  //[MDDC controllerLoop];
  //[NSThread sleepForTimeInterval:2];

  //[MDDC userGazChanged:0.0];
  //[MDDC controllerLoop];
  //[NSThread sleepForTimeInterval:2];
  
  //[MDDC userRequestedLanding];
  //[NSThread sleepForTimeInterval:2];
  
  [MDDC stop];
  [NSThread sleepForTimeInterval:5];
  NSLog(@"MDDC Stopped...or rather, brought to a screeching hault");
  
  exit(0);
}

int main() {
  @autoreleasepool {
    ARDiscovery *ARD = [ARDiscovery sharedInstance];
    [ARD start];

    dispatch_queue_t my_main_thread = dispatch_queue_create("MyMainThread", NULL);
    dispatch_async(my_main_thread, ^{ discover_drone(); });

    [[NSRunLoop currentRunLoop] run];
  }
  return 0;
}
