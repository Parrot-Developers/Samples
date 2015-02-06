#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>
#import <libARSAL/ARSAL.h>
#import <libARNetwork/ARNetwork.h>
#import <libARNetworkAL/ARNetworkAL.h>

#include <termios.h>

#import "DeviceController.h"

void discover_and_fly_drone() {
  
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
  
  DeviceController *MDDC = [[DeviceController alloc] init];

  while(MDDC.service == nil) {
    [NSThread sleepForTimeInterval:0.3];
  }

  BOOL connectError = [MDDC start];
  if(connectError) {
    NSLog(@"connectError = %d", connectError);
    [MDDC stop];
    return;
  } else {
    NSLog(@"MDDC Started");
  }
  
  //meter/sec - min: 0.5, max: 2.5
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

  float speed = 0.50;
  int land = 0;
  int autoTakeoff = 0;
  
  int commandFound = 0;

  NSLog(@"Rolling Spider ready for commands");

  /* Keys:
     escape key - lands and ends session
     f - sends flat trim command
     t - auto takeoff toggle
     + - speed up
     - - slow down
     space bar - land / takeoff toggle
     enter key - take a photo
     up arrow - tilt forward
     back arrow - tilt backwards
     right arrow - rotate right
     left arrow - rotate left
     w - ascend
     s - descend
     d - roll right
     a - roll left
   */  
  
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
      [NSThread sleepForTimeInterval:0.10];
    }
    //T - auto takeoff toggle
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,17)) {
      [MDDC setFlag:0];
      if(autoTakeoff == 0) {
	NSLog(@"Auto Takeoff Enabled");
	[MDDC sendAutoTakeoff:1];
	autoTakeoff = 1;
      } else {
	NSLog(@"Auto Takeoff Disabled");
	[MDDC sendAutoTakeoff:0];
	autoTakeoff = 0;
      }
      [NSThread sleepForTimeInterval:0.25];
    }
    //+ - faster
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,24)) {
      if(speed < 1.0) {
	speed += 0.1;
	NSLog(@"Speeding Up %f", speed);
      }
      [NSThread sleepForTimeInterval:0.10];
    }
    //- - slower
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,27)) {
      if(speed >= 0.1) {
	speed -= 0.1;
	NSLog(@"Speeding Down %f", speed);
      }
      [NSThread sleepForTimeInterval:0.10];
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

    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,126)) {
      //up arrow - tilt forward
      [MDDC setFlag:1];
      [MDDC setPitch:speed*0.5];
    } else if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,125)) {
      //back arrow - tilt backwards
      [MDDC setFlag:1];
      [MDDC setPitch:-speed*0.5];
    } else {
      [MDDC setPitch:0];
    }
    
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,124)) {
      //right arrow - rotate right
      [MDDC setYaw:speed];
    } else if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,123)) {
      //left arrow - rotate left
      [MDDC setYaw:-speed];
    } else {
      [MDDC setYaw:0];
    }

    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,13)) {
      //W - up
      [MDDC setGaz:speed*0.5];
    } else if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,1)) {
      //S - down
      [MDDC setGaz:-speed*0.5];
    } else {
      [MDDC setGaz:0];
    }
    
    if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,2)) {
      //D - roll right
      [MDDC setFlag:1];
      [MDDC setRoll:speed*0.5];
    } else if (CGEventSourceKeyState(kCGEventSourceStateCombinedSessionState,0)) {
      //A - roll left
      [MDDC setFlag:1];
      [MDDC setRoll:-speed*0.5];
    } else {
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
	discover_and_fly_drone();
	tcflush(STDOUT_FILENO, TCIOFLUSH);
	exit(0);
      });

    [[NSRunLoop currentRunLoop] run];
  }
  return 0;
}
