/*
    Copyright (C) 2014 Parrot SA

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in
      the documentation and/or other materials provided with the 
      distribution.
    * Neither the name of Parrot nor the names
      of its contributors may be used to endorse or promote products
      derived from this software without specific prior written
      permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED 
    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
    SUCH DAMAGE.
*/
//
//  MiniDroneDeviceController.m
//  ARFreeFlight
//
//  Created by Hugo Grostabussiat on 09/12/2013.
//  Copyright (c) 2013 Parrot SA. All rights reserved.
//
#import <libARSAL/ARSAL.h>
#import <libARCommands/ARCommands.h>
#import "DeviceController+libARCommands.h"
#import "MiniDroneDeviceController+libARCommands.h"
#import "MiniDroneDeviceController+libARCommandsDebug.h"
#import "MiniDroneARNetworkConfig.h"
#import "DeviceControllerProtected.h"
//#import "MiniDronePhotoRecordController.h"

NSString* MiniDroneDeviceControllerFlyingStateChangedNotification = @"MiniDroneDeviceControllerFlyingStateChangedNotification";
NSString* MiniDroneDeviceControllerEmergencyStateChangedNotification = @"MiniDroneDeviceControllerEmergencyStateChangedNotification";
NSString* MiniDroneDeviceControllerDebug1ReceivedNotification = @"MiniDroneDeviceControllerDebug1ReceivedNotification";
NSString* MiniDroneDeviceControllerDebug2ReceivedNotification = @"MiniDroneDeviceControllerDebug2ReceivedNotification";
NSString* MiniDroneDeviceControllerDebug3ReceivedNotification = @"MiniDroneDeviceControllerDebug3ReceivedNotification";

static const char* TAG = "MiniDroneDeviceController";
static const NSTimeInterval LOOP_INTERVAL = 0.05;

/* Used for ARNetwork notification data. */
typedef enum ARNetworkSendMetadataType {
    kARNetworkSendMetadataTypeTest1,
    kARNetworkSendMetadataTypeTest2,
    kARNetworkSendMetadataTypeTest3,
} eARNetworkSendMetadataType;

typedef struct
{
    MiniDronePilotingData_t pilotingData;
} MiniDroneData_t;

@interface MiniDroneDeviceController () <ARNetworkSendStatusDelegate>
@property (atomic, readonly) eDEVICE_CONTROLLER_STATE state;
@property (nonatomic) NSRecursiveLock *stateLock;
@property (nonatomic) MiniDroneData_t droneState; // Current MiniDrone state. Lock before use.
@property (nonatomic) NSRecursiveLock* droneStateLock; // Lock for the MiniDrone state.
@property (atomic) BOOL startCancelled;
@property (nonatomic) BOOL initialSettingsReceived;
@property (nonatomic) NSCondition *initialSettingsReceivedCondition;
@property (nonatomic) BOOL initialStatesReceived;
@property (nonatomic) NSCondition *initialStatesReceivedCondition;
@property (atomic) BOOL isInPause;
@property (atomic) NSTimeInterval currentLoopInterval;
@end

@implementation MiniDroneDeviceController
- (id)initWithService:(ARService*)service;
{
    MiniDroneARNetworkConfig* netConfig = [[MiniDroneARNetworkConfig alloc] init];
    self = [super initWithARNetworkConfig:netConfig withARService:service withBridgeDeviceController:nil withLoopInterval:LOOP_INTERVAL];
    if (self != nil) {
        _stateLock = [[NSRecursiveLock alloc] init];
        _state = DEVICE_CONTROLLER_STATE_STOPPED;
        _droneStateLock = [[NSRecursiveLock alloc] init];
        _startCancelled = NO;
        _initialSettingsReceived = NO;
        _initialSettingsReceivedCondition = [[NSCondition alloc] init];
        _initialStatesReceived = NO;
        _initialStatesReceivedCondition = [[NSCondition alloc] init];
    }
    return self;
}

- (void)start
{
    [_stateLock lock];
    if (_state == DEVICE_CONTROLLER_STATE_STOPPED)
    {
      _state = DEVICE_CONTROLLER_STATE_STARTING;
      _startCancelled = NO;
      _initialSettingsReceived = NO;
      _initialStatesReceived = NO;
      
      
      [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerWillStartNotification object:self];
      BOOL failed = NO;
      if ([self privateStart] == NO)
	{
	  ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Failed to start the controller.");
	  failed = YES;
	}
      if (!failed && !_startCancelled)
	{
	  [_stateLock lock];
	  _state = DEVICE_CONTROLLER_STATE_STARTED;
	  [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerDidStartNotification object:self];
	  [_stateLock unlock];
	}
      else
	{
	  [_stateLock lock];
	  _state = DEVICE_CONTROLLER_STATE_STOPPING;
	  if (failed) {
	    [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerDidFailNotification object:self];
	  } // No else: Do not send failure notification for a cancelled start.
	  [_stateLock unlock];
	  [self privateStop];
          
	  [_stateLock lock];
	  _state = DEVICE_CONTROLLER_STATE_STOPPED;
	  [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerDidStopNotification object:self];
	  [_stateLock unlock];
	}
    }
    [_stateLock unlock];
}

- (void)stop
{
    [_stateLock lock];
    if (_state == DEVICE_CONTROLLER_STATE_STARTED)
    {
        /* Go to the stopping state. */
        _state = DEVICE_CONTROLLER_STATE_STOPPING;

        /* Do the actual stop process in the background. */
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerWillStopNotification object:self];
            
            [[NSNotificationCenter defaultCenter] removeObserver:self name:DeviceControllerSettingsStateAllSettingsChangedNotification object:nil];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:DeviceControllerCommonStateAllStatesChangedNotification object:nil];
            
            /* Perform the actual stop. */
            [self privateStop];
            
            /* Go to the STOPPED state and notify. */
            [_stateLock lock];
            _state = DEVICE_CONTROLLER_STATE_STOPPED;
            [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerDidStopNotification object:self];
            [_stateLock unlock];
        });
    }
    else if (_state == DEVICE_CONTROLLER_STATE_STARTING && !_startCancelled)
    {
        /* Go to the stopping state and request cancellation. */
        _state = DEVICE_CONTROLLER_STATE_STOPPING;
        _startCancelled = YES;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerWillStopNotification object:self];
            
            [[NSNotificationCenter defaultCenter] removeObserver:self name:DeviceControllerSettingsStateAllSettingsChangedNotification object:nil];
            [[NSNotificationCenter defaultCenter] removeObserver:self name:DeviceControllerCommonStateAllStatesChangedNotification object:nil];
            [super cancelBaseControllerStart];
            
            [_initialSettingsReceivedCondition lock];
            [_initialSettingsReceivedCondition signal];
            [_initialSettingsReceivedCondition unlock];
            
            [_initialStatesReceivedCondition lock];
            [_initialStatesReceivedCondition signal];
            [_initialStatesReceivedCondition unlock];
        });
    }
    [_stateLock unlock];
}

- (void)pause:(BOOL)pause
{
    [_stateLock lock];
    _isInPause = pause;
    [_stateLock unlock];
}

- (void)looperThreadRoutine:(id)userData
{
    NSTimeInterval lastInterval = [NSDate timeIntervalSinceReferenceDate];
    _currentLoopInterval = self.loopInterval;
    
    while (![NSThread currentThread].isCancelled)
    {
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceReferenceDate:lastInterval + self.currentLoopInterval]];
        lastInterval = [NSDate timeIntervalSinceReferenceDate];
        
        [self controllerLoop];
    }
}

- (void)controllerLoop
{
    eDEVICE_CONTROLLER_STATE currentState;
    MiniDroneData_t localState;
    BOOL isRunning = NO;
    
    [_stateLock lock];
    currentState = _state;
    isRunning = !_isInPause;
    [_stateLock unlock];
    
    if (isRunning)
    {
      switch(currentState) {
        case DEVICE_CONTROLLER_STATE_STARTED:
	  // Make a copy of the drone state.
	  [_droneStateLock lock];
	  localState = _droneState;
	  [_droneStateLock unlock];
	  NSLog(@"====> %d, %d, %d, %d, %d, %f", (uint8_t)(localState.pilotingData.active ? 1 : 0),
		(int8_t)(localState.pilotingData.roll * 100.f),
		(int8_t)(localState.pilotingData.pitch * 100.f),
		(int8_t)(localState.pilotingData.yaw * 100.f),
		(int8_t)(localState.pilotingData.gaz * 100.f),
		localState.pilotingData.heading);
	  [self MiniDroneDeviceController_SendPilotingPCMD:[MiniDroneARNetworkConfig c2dNackId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withFlag:(uint8_t)(localState.pilotingData.active ? 1 : 0) withRoll:(int8_t)(localState.pilotingData.roll * 100.f) withPitch:(int8_t)(localState.pilotingData.pitch * 100.f) withYaw:(int8_t)(localState.pilotingData.yaw * 100.f) withGaz:(int8_t)(localState.pilotingData.gaz * 100.f) withPsi:localState.pilotingData.heading];
	  break;
                
        case DEVICE_CONTROLLER_STATE_STOPPING:
        case DEVICE_CONTROLLER_STATE_STARTING:
        case DEVICE_CONTROLLER_STATE_STOPPED:
        default:
	  //DO NOT SEND DATA
	  break;
      }
    }
}

#pragma mark - HUD-called methods.
- (void)userCommandsActivationChanged:(BOOL)activated
{
    [_droneStateLock lock];
    _droneState.pilotingData.active = activated;
    [_droneStateLock unlock];
}

- (void)userGazChanged:(float)gaz
{
    [_droneStateLock lock];
    _droneState.pilotingData.gaz = gaz;
    [_droneStateLock unlock];
}

- (void)userPitchChanged:(float)pitch
{
    [_droneStateLock lock];
    _droneState.pilotingData.pitch = pitch;
    [_droneStateLock unlock];
}

- (void)userRollChanged:(float)roll
{
    [_droneStateLock lock];
    _droneState.pilotingData.roll = roll;
    [_droneStateLock unlock];
}

- (void)userYawChanged:(float)yaw
{
    [_droneStateLock lock];
    _droneState.pilotingData.yaw = yaw;
    [_droneStateLock unlock];
}

- (void)userHeadingChanged:(float)heading
{
    [_droneStateLock lock];
    _droneState.pilotingData.heading = heading;
    [_droneStateLock unlock];
}

- (void)userRequestedEmergency
{
    // Send the emergency command
    [self MiniDroneDeviceController_SendPilotingEmergency:[MiniDroneARNetworkConfig c2dEmergencyId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil];
}

- (void)userRequestedTakeOff
{
    // Send the emergency command
    [self MiniDroneDeviceController_SendPilotingTakeOff:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestedLanding
{
    // Send the emergency command
    [self MiniDroneDeviceController_SendPilotingLanding:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestFlip:(eARCOMMANDS_MINIDRONE_ANIMATIONS_FLIP_DIRECTION)flipDirection
{
    [self MiniDroneDeviceController_SendAnimationsFlip:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withDirection:flipDirection];
}

- (void)userRequestCap:(int16_t)offset
{
    [self MiniDroneDeviceController_SendAnimationsCap:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withOffset:offset];
}

- (void)userRequestedFlatTrim
{
    [self MiniDroneDeviceController_SendPilotingFlatTrim:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestedRecordPicture:(int)massStorageId
{
    [self MiniDroneDeviceController_SendMediaRecordPicture:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withMass_storage_id:massStorageId];
}

- (void)userRequestSetAutoTakeOffMode:(uint8_t)state
{
    [self MiniDroneDeviceController_SendPilotingAutoTakeOffMode:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withState:state];
}

- (BOOL)userSetDebug1Value:(int8_t)value
{
    BOOL result = [self MiniDroneDeviceController_SendDebugTest1:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil withT1Args:value];
    
    [self postDebug1AckNotification];
    
    return result;
}

- (BOOL)userSetDebug2Value:(int8_t)value
{
    BOOL result = [self MiniDroneDeviceController_SendDebugTest2:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil withT2Args:value];
    
    [self postDebug2AckNotification];
    
    return result;
}

- (BOOL)userSetDebug3Value:(int8_t)value
{
    BOOL result = [self MiniDroneDeviceController_SendDebugTest3:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil withT3Args:value];
    
    [self postDebug1AckNotification];
    
    return result;
}

- (void)userRequestedPilotingSettingsMaxAltitude:(float)maxAltitude
{
    [self MiniDroneDeviceController_SendPilotingSettingsMaxAltitude:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withCurrent:maxAltitude];
}

- (void)userRequestedPilotingSettingsMaxTilt:(float)maxTilt
{
    [self MiniDroneDeviceController_SendPilotingSettingsMaxTilt:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withCurrent:maxTilt];
}

- (void)userRequestedSpeedSettingsMaxRotationSpeed:(float)maxRotationSpeed
{
    [self MiniDroneDeviceController_SendSpeedSettingsMaxRotationSpeed:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withCurrent:maxRotationSpeed];
}

- (void)userRequestedSpeedSettingsMaxVerticalSpeed:(float)maxVerticalSpeed
{
    [self MiniDroneDeviceController_SendSpeedSettingsMaxVerticalSpeed:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withCurrent:maxVerticalSpeed];
}

- (void)userRequestedSpeedSettingsWheels:(BOOL)present
{
    [self MiniDroneDeviceController_SendSpeedSettingsWheels:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withPresent:present ? 1 : 0];
}

- (void)userRequestedSpeedSettingsCutOut:(BOOL)enable;
{
    [self MiniDroneDeviceController_SendSettingsCutOutMode:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withEnable:enable ? 1 : 0];
}


- (void)userRequestedSettingsReset
{
    [self DeviceController_SendSettingsReset:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestedSettingsProductName:(NSString *)productName
{
    [self DeviceController_SendSettingsProductName:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withName:(char *)[productName cStringUsingEncoding:NSUTF8StringEncoding]];
}

- (void)userRequestedReboot
{
    [self DeviceController_SendCommonReboot:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

// The code to send the command is not autogenerated, so send it manually.
- (void)userEnteredPilotingHud:(BOOL)inHud
{
    u_int8_t cmdbuf[128];
    int32_t actualSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    BOOL sentStatus;
    
    // Send isPilotingChanged command
    sentStatus = NO;
    cmdError = ARCOMMANDS_Generator_GenerateCommonControllerIsPiloting(cmdbuf, sizeof(cmdbuf), &actualSize, (inHud ? 1 : 0));
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        sentStatus = [self sendData:cmdbuf withSize:actualSize onBufferWithId:[MiniDroneARNetworkConfig c2dAckId]withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil];
    }
    if (!sentStatus)
    {
        ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Failed to send isPilotingChanged command.");
    }
}


#pragma mark - Send notifications
- (void)postDebug1AckNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MiniDroneDeviceControllerDebug1ReceivedNotification object:self];
}

- (void)postDebug2AckNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MiniDroneDeviceControllerDebug2ReceivedNotification object:self];
}

- (void)postDebug3AckNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:MiniDroneDeviceControllerDebug3ReceivedNotification object:self];
}

#pragma mark - Miscellaneous private methods.

- (void)initDroneState
{
    [_droneStateLock lock];
    _droneState.pilotingData = (MiniDronePilotingData_t){ NO, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f };
    [_droneStateLock unlock];
}

- (BOOL)privateStart
{
    BOOL failed = NO;
    
    /* Initialize initial commands state. */
    [self initDroneState];
    
    if (!failed && !_startCancelled)
    {
        failed = ([self startBaseController] == BASE_DEVICE_CONTROLLER_START_RETVAL_FAILED);
        if (failed) {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Failed to start the base controller.");
        }
    }
    if (!failed && !_startCancelled)
    {
      // Register ARCommands callbacks.
      [self registerMiniDroneARCommandsCallbacks];
    }

    if (!failed && !_startCancelled && !self.fastReconnection)
    {
        NSDate *currentDate = [NSDate date];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
        [dateFormatter setLocale:[NSLocale systemLocale]];
        
        // Set date
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
        [self DeviceController_SendCommonCurrentDate:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil withDate:(char *)[[dateFormatter stringFromDate:currentDate] cStringUsingEncoding:NSUTF8StringEncoding]];
        
        // Set time
        [dateFormatter setDateFormat:@"'T'HHmmssZZZ"];
        [self DeviceController_SendCommonCurrentTime:[MiniDroneARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil withTime:(char *)[[dateFormatter stringFromDate:currentDate] cStringUsingEncoding:NSUTF8StringEncoding]];
    }

    return (failed == NO);
}

- (void)privateStop
{
  //_photoRecordController = nil;
  [self unregisterMiniDroneARCommandsCallbacks];
  [self stopBaseController];
}

- (void)stateAllSettingsChanged:(NSNotification *)notification
{
    [_initialSettingsReceivedCondition lock];
    _initialSettingsReceived = YES;
    [_initialSettingsReceivedCondition signal];
    [_initialSettingsReceivedCondition unlock];
}

- (void)stateAllStatesChanged:(NSNotification *)notification
{
    [_initialStatesReceivedCondition lock];
    _initialStatesReceived = YES;
    [_initialStatesReceivedCondition signal];
    [_initialStatesReceivedCondition unlock];
}

#pragma mark - ARNetwork acknowledged commands.
- (void)debugTest1ValueAcknowledged
{
    [self postDebug1AckNotification];
}

- (void)debugTest2ValueAcknowledged
{
    [self postDebug2AckNotification];
}

- (void)debugTest3ValueAcknowledged
{
    [self postDebug3AckNotification];
}

@end

