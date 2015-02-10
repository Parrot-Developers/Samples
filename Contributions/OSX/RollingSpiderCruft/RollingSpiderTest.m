#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>
#import <libARSAL/ARSAL.h>
#import <libARNetwork/ARNetwork.h>
#import <libARNetworkAL/ARNetworkAL.h>

#import "RSlib/MiniDroneDeviceController.h"

static const char* TAG = "DeviceController";

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
  
  MiniDroneDeviceController *MDDC = [[MiniDroneDeviceController alloc] initWithService:foundService];
  NSLog(@"Initialized MiniDroneDeviceController");
  [MDDC start];
  NSLog(@"MDDC Started");

  // meter/sec - min: 0.5, max: 2.5
  [MDDC userRequestedSpeedSettingsMaxVerticalSpeed:1.0];
  [NSThread sleepForTimeInterval:0.3];

  //degree - min: 5, max: 25
  [MDDC userRequestedPilotingSettingsMaxTilt:15.0];
  [NSThread sleepForTimeInterval:0.3];

  //degree/sec - min: 50, max: 360
  [MDDC userRequestedSpeedSettingsMaxRotationSpeed:150.0];
  [NSThread sleepForTimeInterval:0.3];

  //Activate ability to tilt
  [MDDC userCommandsActivationChanged:1];
  [NSThread sleepForTimeInterval:0.3];

  //Turn off wheels
  [MDDC userRequestedSpeedSettingsWheels:0];
  [NSThread sleepForTimeInterval:0.3];

  //Reset state of drone (maybe unnecessary)
  [MDDC controllerLoop];
  [NSThread sleepForTimeInterval:0.3];
  
  //NSLog(@"Blink Blink");
  //[MDDC userRequestSetAutoTakeOffMode:1];
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
      [MDDC userRequestedFlatTrim];
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
	[MDDC userRequestedLanding];
	[NSThread sleepForTimeInterval:1];
	land = 0;
      } else {
	NSLog(@"Taking Off");
	[MDDC userRequestedFlatTrim];
	[NSThread sleepForTimeInterval:0.30];
	[MDDC userRequestedTakeOff];
	[NSThread sleepForTimeInterval:0.1];
	[MDDC userRequestedFlatTrim];
	[NSThread sleepForTimeInterval:0.30];
	land = 1;
      }
    }
    //enter key - photo
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,36)) {
      NSLog(@"Taking Photo");
      [NSThread sleepForTimeInterval:0.25];
      [MDDC userRequestedRecordPicture:1];
      [NSThread sleepForTimeInterval:1.0];
    }
    //up arrow - tilt forward
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,126)) {
      commandFound = 1;
      NSLog(@"Tilting Forwards");
      [MDDC userPitchChanged:speed*0.5];
    }
    //back arrow - tilt backwards
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,125)) {
      commandFound = 1;
      NSLog(@"Tilting Backwards");
      [MDDC userPitchChanged:-speed*0.5];
    }
    //right arrow - rotate right
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,124)) {
      commandFound = 1;
      NSLog(@"Rotating Right");
      [MDDC userYawChanged:speed];
    }
    //left arrow - rotate left
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,123)) {
      commandFound = 1;
      NSLog(@"Rotating Left");
      [MDDC userYawChanged:-speed];
    }

    //W - up
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,13)) {
      commandFound = 1;
      NSLog(@"Going Up");
      [MDDC userGazChanged:speed*0.5];
    }
    //S - down
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,1)) {
      commandFound = 1;
      NSLog(@"Going Down");
      [MDDC userGazChanged:-speed*0.5];
    }
    //D - roll right
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,2)) {
      commandFound = 1;
      NSLog(@"Rolling Right");
      [MDDC userRollChanged:speed*0.5];
    }
    //A - roll left
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,0)) {
      commandFound = 1;
      NSLog(@"Rolling Left");
      [MDDC userRollChanged:-speed*0.5];
    }
    
    if(commandFound) {
      [MDDC controllerLoop];
      commandFound = 0;

      [MDDC userGazChanged:0];
      [MDDC userYawChanged:0];
      [MDDC userPitchChanged:0];
      [MDDC userRollChanged:0];
    }
    [NSThread sleepForTimeInterval:0.15];
  }
  
  [MDDC userRequestedLanding];
  [NSThread sleepForTimeInterval:2];
  
  [MDDC stop];
  [NSThread sleepForTimeInterval:5];
  NSLog(@"MDDC Stopped");
  
  exit(0);
}

int main() {
  @autoreleasepool {
    dispatch_queue_t my_main_thread = dispatch_queue_create("MyMainThread", NULL);

    /*
    dispatch_async(my_main_thread,^{
    	NSNotificationCenter *mainCenter = [NSNotificationCenter defaultCenter];
	[mainCenter postNotificationName:@"my_notification" object:nil];

	[[NSDistributedNotificationCenter defaultCenter] addObserverForName:nil object:nil queue:nil usingBlock:^(NSNotification *notification)
							 {
							   NSLog(@"%@", notification);
							 }];
      });
    */

    dispatch_async(my_main_thread,^{
	ARDiscovery *ARD = [ARDiscovery sharedInstance];
	[ARD start];
	discover_drone();
      });
    
    dispatch_async(my_main_thread, ^{
	[NSThread sleepForTimeInterval:5];
	discover_drone();
      });

    [[NSRunLoop currentRunLoop] run];
  }
  return 0;
}
