#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>
#import <libARSAL/ARSAL.h>
#import <libARNetwork/ARNetwork.h>
#import <libARNetworkAL/ARNetworkAL.h>

#import "DeviceController.h"

void discover_drone() {
  ARService *foundService = nil;
  ARDiscovery *ARD = [ARDiscovery sharedInstance];

  /*
  int j;
  while(1) {
    int i;
    for(i = 0; i < 128; i++) {
      if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,i)) {
	NSLog(@"keypressed %d", i);
      }
    }
  }
  */

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

  DeviceController *MDDC = [[DeviceController alloc] initWithARService:foundService];
  NSLog(@"Initialized MiniDroneDeviceController");
  BOOL connectError = [MDDC start];
  if(connectError) {
    NSLog(@"connectError = %d", connectError);
    [MDDC stop];
    return;
  } else {
    NSLog(@"MDDC Started");
  }
  
  // meter/sec - min: 0.5, max: 2.5
  [MDDC sendMaxVerticalSpeed:1.0];
  [NSThread sleepForTimeInterval:0.3];
 
  //degree - min: 5, max: 25
  [MDDC sendMaxTilt:15.0];
  [NSThread sleepForTimeInterval:0.3];

  //degree/sec - min: 50, max: 360
  [MDDC sendMaxRotationSpeed:150.0];
  [NSThread sleepForTimeInterval:0.3];

  //meter - min: 2, max: 10
  [MDDC sendMaxAltitude:3];
  [NSThread sleepForTimeInterval:0.3];
  
  //Turn off wheels
  [MDDC sendWheelsOn:0];
  [NSThread sleepForTimeInterval:0.3];

  //NSLog(@"Blink Blink");
  //[MDDC sendAutoTakeoff:1];
  //[NSThread sleepForTimeInterval:0.3];

  float speed = 0.50;
  int land = 0;
  
  int commandFound = 0;

  NSLog(@"Rolling Spider ready for commands");
  while(1) {
    //escape
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,53)) {
      commandFound = 1;
      NSLog(@"Landing");
      break;
    }
    //F - flat trim
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,3)) {
      NSLog(@"Flat trim");
      [MDDC sendFlatTrim];
      [NSThread sleepForTimeInterval:0.25];
    }
    //+ - faster
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,24)) {
      if(speed < 1.0) {
	speed += 0.1;
	NSLog(@"Speeding Up %f", speed);
      }
      [NSThread sleepForTimeInterval:0.25];
    }
    //- - slower
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,27)) {
      if(speed >= 0.1) {
	speed -= 0.1;
	NSLog(@"Speeding Down %f", speed);
      }
      [NSThread sleepForTimeInterval:0.25];
    }
    //space - land or takeoff
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,49)) {
      if(land == 1) {
	NSLog(@"Landing");
	[MDDC sendLanding];
	[NSThread sleepForTimeInterval:1];
	land = 0;
      } else {
	NSLog(@"Taking Off");
	//Deactivate ability to tilt
	[MDDC setFlag:0];
	[MDDC sendFlatTrim];
	[NSThread sleepForTimeInterval:0.25];
	[MDDC sendTakeoff];
	[NSThread sleepForTimeInterval:0.5];
	[MDDC sendFlatTrim];
	[NSThread sleepForTimeInterval:0.25];
	//Reactiviate ability to tilt
	[MDDC setFlag:1];
	land = 1;
      }
    }
    //enter key - photo
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,36)) {
      NSLog(@"Taking Photo");
      [NSThread sleepForTimeInterval:0.25];
      [MDDC sendMediaRecordPicture:1];
      [NSThread sleepForTimeInterval:1.0];
    }
    //up arrow - tilt forward
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,126)) {
      commandFound = 1;
      NSLog(@"Tilting Forwards");
      [MDDC setPitch:speed*0.5];
    }
    //back arrow - tilt backwards
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,125)) {
      commandFound = 1;
      NSLog(@"Tilting Backwards");
      [MDDC setPitch:-speed*0.5];
    }
    //right arrow - rotate right
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,124)) {
      commandFound = 1;
      NSLog(@"Rotating Right");
      [MDDC setYaw:speed];
    }
    //left arrow - rotate left
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,123)) {
      commandFound = 1;
      NSLog(@"Rotating Left");
      [MDDC setYaw:-speed];
    }

    //W - up
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,13)) {
      commandFound = 1;
      NSLog(@"Going Up");
      [MDDC setGaz:speed*0.5];
    }
    //S - down
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,1)) {
      commandFound = 1;
      NSLog(@"Going Down");
      [MDDC setGaz:-speed*0.5];
    }
    //D - roll right
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,2)) {
      commandFound = 1;
      NSLog(@"Rolling Right");
      [MDDC setRoll:speed*0.5];
    }
    //A - roll left
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,0)) {
      commandFound = 1;
      NSLog(@"Rolling Left");
      [MDDC setRoll:-speed*0.5];
    }

    [NSThread sleepForTimeInterval:0.15];
    if(commandFound) {
      commandFound = 0;

      [MDDC setGaz:0];
      [MDDC setYaw:0];
      [MDDC setPitch:0];
      [MDDC setRoll:0];
    }
  }
  
  [MDDC sendLanding];
  [NSThread sleepForTimeInterval:2];
  
  [MDDC stop];
  NSLog(@"MDDC Stopped");
}

int main() {
  @autoreleasepool {
    dispatch_queue_t my_main_thread = dispatch_queue_create("MyMainThread", NULL);

    dispatch_async(my_main_thread,^{
	ARDiscovery *ARD = [ARDiscovery sharedInstance];
	[ARD start];
	discover_drone();
	[ARD stop];
	exit(0);
      });
    
    dispatch_async(my_main_thread, ^{
	[NSThread sleepForTimeInterval:5];
	discover_drone();
      });

    [[NSRunLoop currentRunLoop] run];
  }
  return 0;
}
