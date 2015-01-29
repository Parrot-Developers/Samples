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
//  ARDrone3DeviceController.m
//  ARFreeFlight
//
//  Created by Hugo Grostabussiat on 09/12/2013.
//  Copyright (c) 2013 Parrot SA. All rights reserved.
//
#import <libARSAL/ARSAL.h>
#import <libARCommands/ARCommands.h>
#import "ARDrone3DeviceController+libARCommands.h"
#import "ARDrone3DeviceController+libARCommandsDebug.h"
#import "ARDrone3ARNetworkConfig.h"
#import "DeviceControllerProtected.h"
#import "ARDrone3VideoRecordController.h"
#import "ARDrone3PhotoRecordController.h"

/* ARCommands callbacks forward declaration. */
static const char* TAG = "ARDrone3DeviceController";
static const NSTimeInterval LOOP_INTERVAL = 0.025;

typedef struct
{
    ARDrone3PilotingData_t pilotingData;
    ARDrone3CameraData_t cameraData;
} ARDrone3Data_t;

@interface ARDrone3DeviceController ()
@property (atomic, readonly) eDEVICE_CONTROLLER_STATE state;
@property (nonatomic) NSRecursiveLock *stateLock;
@property (atomic) BOOL startCancelled;
@property (nonatomic) ARDrone3Data_t droneState; // Current ARDrone3 data. Lock before use.
@property (nonatomic) NSRecursiveLock* droneStateLock; // Lock for the ARDrone3 state.
@property (nonatomic) BOOL initialSettingsReceived;
@property (nonatomic) NSCondition *initialSettingsReceivedCondition;
@property (nonatomic) BOOL initialStatesReceived;
@property (nonatomic) NSCondition *initialStatesReceivedCondition;
@end

@implementation ARDrone3DeviceController

- (id)initWithService:(ARService*)service;
{
    return [self initWithService:service withBridgeDeviceController:nil];
}

- (id)initWithService:(ARService*)service withBridgeDeviceController:(DeviceController*)bridgeDeviceController;
{
    ARDrone3ARNetworkConfig* netConfig = [[ARDrone3ARNetworkConfig alloc] init];
    self = [super initWithARNetworkConfig:netConfig withARService:service withBridgeDeviceController:bridgeDeviceController withLoopInterval:LOOP_INTERVAL];
    if (self != nil)
    {
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
        
        /* Asynchronously start the base controller. */
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerWillStartNotification object:self];
            BOOL failed = NO;
            if ([self privateStart] == NO)
            {
                ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Failed to start the controller.");
                failed = YES;
            }
            
            if (!failed && !_startCancelled)
            {
                /* Go to the STARTED state and notify. */
                [_stateLock lock];
                _state = DEVICE_CONTROLLER_STATE_STARTED;
                [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerDidStartNotification object:self];
                [_stateLock unlock];
            }
            else
            {
                /* We failed to start. Go to the STOPPING state and stop in the background. */
                [_stateLock lock];
                _state = DEVICE_CONTROLLER_STATE_STOPPING;
                if (failed) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerDidFailNotification object:self];
                } // No else: Do not send failure notification for a cancelled start.
                [_stateLock unlock];
                [self privateStop];
                
                /* Go to the STOPPED state and notify. */
                [_stateLock lock];
                _state = DEVICE_CONTROLLER_STATE_STOPPED;
                [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerDidStopNotification object:self];
                [_stateLock unlock];
            }
        });
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
}

- (void)controllerLoop
{
    eDEVICE_CONTROLLER_STATE currentState;
    ARDrone3Data_t localState;
    
    [_stateLock lock];
    currentState = _state;
    [_stateLock unlock];
    
    switch(currentState)
    {
        case DEVICE_CONTROLLER_STATE_STARTED:
            // Make a copy of the drone state.
            [_droneStateLock lock];
            memcpy(&localState, &_droneState, sizeof(ARDrone3Data_t));
            [_droneStateLock unlock];
            
            [self ARDrone3DeviceController_SendPilotingPCMD:[ARDrone3ARNetworkConfig c2dNackId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withFlag:(uint8_t)(localState.pilotingData.active ? 1 : 0) withRoll:(int8_t)(localState.pilotingData.roll * 100.f) withPitch:(int8_t)(localState.pilotingData.pitch * 100.f) withYaw:(int8_t)(localState.pilotingData.yaw * 100.f) withGaz:(int8_t)(localState.pilotingData.gaz * 100.f) withPsi:localState.pilotingData.heading];
            [self ARDrone3DeviceController_SendCameraOrientation:[ARDrone3ARNetworkConfig c2dNackId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withTilt:(int8_t)localState.cameraData.tilt withPan:(int8_t)localState.cameraData.pan];
            break;
            
        case DEVICE_CONTROLLER_STATE_STOPPING:
        case DEVICE_CONTROLLER_STATE_STARTING:
        case DEVICE_CONTROLLER_STATE_STOPPED:
        default:
            // DO NOT SEND DATA
            break;
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

- (void)userCameraTiltChanged:(float)tilt
{
    [_droneStateLock lock];
    _droneState.cameraData.tilt = tilt;
    [_droneStateLock unlock];
}

- (void)userCameraPanChanged:(float)pan
{
    [_droneStateLock lock];
    _droneState.cameraData.pan = pan;
    [_droneStateLock unlock];
}

- (void)userRequestedEmergency
{
    // Send the emergency command
    [self ARDrone3DeviceController_SendPilotingEmergency:[ARDrone3ARNetworkConfig c2dEmergencyId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil];
}

- (void)userRequestedTakeOff
{
    // Send the emergency command
    [self ARDrone3DeviceController_SendPilotingTakeOff:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestedLanding
{
    // Send the emergency command
    [self ARDrone3DeviceController_SendPilotingLanding:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestedNavigateHome:(BOOL)start
{
    [self ARDrone3DeviceController_SendPilotingNavigateHome:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withStart:start ? 1 : 0];
}

- (void)userRequestedFlatTrim
{
    [self ARDrone3DeviceController_SendPilotingFlatTrim:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestFlip:(eARCOMMANDS_ARDRONE3_ANIMATIONS_FLIP_DIRECTION)flipDirection
{
    [self ARDrone3DeviceController_SendAnimationsFlip:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withDirection:flipDirection];
}

- (void)userRequestedRecordPicture:(int)massStorageId
{
    [self ARDrone3DeviceController_SendMediaRecordPicture:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withMass_storage_id:massStorageId];
}

- (void)userRequestedRecordVideoStart:(int)massStorageId
{
    [self ARDrone3DeviceController_SendMediaRecordVideo:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withRecord:ARCOMMANDS_ARDRONE3_MEDIARECORD_VIDEO_RECORD_START withMass_storage_id:massStorageId];
}

- (void)userRequestedRecordVideoStop:(int)massStorageId
{
    [self ARDrone3DeviceController_SendMediaRecordVideo:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withRecord:ARCOMMANDS_ARDRONE3_MEDIARECORD_VIDEO_RECORD_STOP withMass_storage_id:massStorageId];
}

- (void)userRequestedSettingsReset
{
    [self DeviceController_SendSettingsReset:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestedSettingsCountry:(NSString *)country
{
    char* countryChar = strdup([country cStringUsingEncoding:NSUTF8StringEncoding]);
    [self DeviceController_SendSettingsCountry:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withCode:countryChar];
}

- (void)userRequestAutoCountry:(int)automatic
{
    [self DeviceController_SendSettingsAutoCountry:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withAutomatic:automatic];
}

- (void)userRequestedSettingsProductName:(NSString *)productName
{
    [self DeviceController_SendSettingsProductName:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withName:(char *)[productName cStringUsingEncoding:NSUTF8StringEncoding]];
}

- (void)userRequestedSettingsNetworkWifiType:(eARCOMMANDS_ARDRONE3_NETWORKSETTINGS_WIFISELECTION_TYPE)type band:(eARCOMMANDS_ARDRONE3_NETWORKSETTINGS_WIFISELECTION_BAND)band channel:(int) channel
{
    [self ARDrone3DeviceController_SendNetworkSettingsWifiSelection:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withType:type withBand:band withChannel:channel];
}

- (void)userRequestedSettingsNetworkWifiScan:(eARCOMMANDS_ARDRONE3_NETWORK_WIFISCAN_BAND)band
{
    [self ARDrone3DeviceController_SendNetworkWifiScan:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withBand:band];
}

- (void)userRequestedSettingsNetworkWifiAuthChannel
{
    [self ARDrone3DeviceController_SendNetworkWifiAuthChannel:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestedPilotingSettingsMaxAltitude:(float)maxAltitude
{
    [self ARDrone3DeviceController_SendPilotingSettingsMaxAltitude:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withCurrent:maxAltitude];
}

- (void)userRequestedPilotingSettingsMaxTilt:(float)maxTilt
{
    [self ARDrone3DeviceController_SendPilotingSettingsMaxTilt:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withCurrent:maxTilt];
}

- (void)userRequestedPilotingSettingsAbsolutControl:(BOOL)on
{
    [self ARDrone3DeviceController_SendPilotingSettingsAbsolutControl:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withOn:on ? 1 : 0];
}

- (void)userRequestedSpeedSettingsMaxRotationSpeed:(float)maxRotationSpeed
{
    [self ARDrone3DeviceController_SendSpeedSettingsMaxRotationSpeed:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withCurrent:maxRotationSpeed];
}

- (void)userRequestedSpeedSettingsMaxVerticalSpeed:(float)maxVerticalSpeed
{
    [self ARDrone3DeviceController_SendSpeedSettingsMaxVerticalSpeed:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withCurrent:maxVerticalSpeed];
}

- (void)userRequestedSpeedSettingsHullProtection:(BOOL)present
{
    [self ARDrone3DeviceController_SendSpeedSettingsHullProtection:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withPresent:present ? 1 : 0];
}

- (void)userRequestedSpeedSettingsOutdoor:(BOOL)outdoor
{
    [self ARDrone3DeviceController_SendSpeedSettingsOutdoor:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withOutdoor:outdoor ? 1 : 0];
}

- (void)userRequestedWithBalance
{
    [self ARDrone3DeviceController_SendVideoManualWhiteBalance:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestedReboot
{
    [self DeviceController_SendCommonReboot:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestedPictureSettingsPictureFormat:(eARCOMMANDS_ARDRONE3_PICTURESETTINGS_PICTUREFORMATSELECTION_TYPE)photoFormat
{
    [self ARDrone3DeviceController_SendPictureSettingsPictureFormatSelection:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withType:photoFormat];
}

- (void)userRequestedPictureSettingsWhiteBalance:(eARCOMMANDS_ARDRONE3_PICTURESETTINGS_AUTOWHITEBALANCESELECTION_TYPE)awbMode
{
    [self ARDrone3DeviceController_SendPictureSettingsAutoWhiteBalanceSelection:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withType:awbMode];
}

- (void)userRequestedPictureSettingsExposition:(float)expositionValue
{
    [self ARDrone3DeviceController_SendPictureSettingsExpositionSelection:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withValue:expositionValue];
}

- (void)userRequestedPictureSettingsSaturation:(float)saturationValue
{
    [self ARDrone3DeviceController_SendPictureSettingsSaturationSelection:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withValue:saturationValue];
}

- (void)userRequestedPictureSettingsTimelapseMode:(BOOL)enabled withInterval:(float)interval
{
    [self ARDrone3DeviceController_SendPictureSettingsTimelapseSelection:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withEnabled:enabled ? 1 : 0 withInterval:interval];
}

- (void)userRequestedPictureSettingsAutorecordVideo:(BOOL)autorecordMode massStorage:(int)massStorageId
{
    [self ARDrone3DeviceController_SendPictureSettingsVideoAutorecordSelection:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withEnabled:autorecordMode ? 1 : 0 withMass_storage_id:massStorageId];
}

- (void)userRequestedDebugDrone2Battery:(BOOL)useDrone2Battery
{
    [self ARDrone3DeviceController_SendBatteryDebugSettingsUseDrone2Battery:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withDrone2BatteryUsed:useDrone2Battery ? 1 : 0 ];
}

- (void)gpsSettingsSetHome:(CLLocationCoordinate2D)home andAltitude:(float)altitude
{
    [self ARDrone3DeviceController_SendGPSSettingsSetHome:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withLatitude:home.latitude withLongitude:home.longitude withAltitude:altitude];
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
    cmdError = ARCOMMANDS_Generator_GenerateCommonControllerStateIsPilotingChanged(cmdbuf, sizeof(cmdbuf), &actualSize, (inHud ? 1 : 0));
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        sentStatus = [self sendData:cmdbuf withSize:actualSize onBufferWithId:[ARDrone3ARNetworkConfig c2dAckId]withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil];
    }
    if (!sentStatus)
    {
        ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Failed to send isPilotingChanged command.");
    }
}

- (BOOL)supportsVideoStreamingControl
{
    BOOL retval = NO;
    NSDictionary *nDict = [self notificationsDictionary];
    NSDictionary *vidEnDict = [nDict objectForKey:ARDrone3DeviceControllerMediaStreamingStateVideoEnableChangedNotification];
    if (vidEnDict == nil)
    {
        // The ARDrone3 sent no value at startup. The firmware does not support video streaming control.
        retval = NO;
    }
    else
    {
        retval = YES;
    }
    return retval;
}

- (BOOL)isVideoStreamingEnabled
{
    BOOL retval = YES;
    NSDictionary *nDict = [self notificationsDictionary];
    NSDictionary *vidEnDict = [nDict objectForKey:ARDrone3DeviceControllerMediaStreamingStateVideoEnableChangedNotification];
    if (vidEnDict != nil)
    {
        NSNumber *enNumber = [vidEnDict objectForKey:ARDrone3DeviceControllerMediaStreamingStateVideoEnableChangedNotificationEnabledKey];
        retval = enNumber.boolValue;
    }
    // NO ELSE: Keep the default value (YES).
    return retval;
}

- (void)enableVideoStreaming:(BOOL)enable
{
    [self ARDrone3DeviceController_SendMediaStreamingVideoEnable:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil withEnable:(enable ? 1 : 0)];
}

#pragma mark - Miscellaneous private methods.
- (void)initDroneState
{
    [_droneStateLock lock];
    _droneState.cameraData = (ARDrone3CameraData_t){ 0.0f, 0.0f };
    _droneState.pilotingData = (ARDrone3PilotingData_t){ NO, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f };
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
        [self registerARDrone3ARCommandsCallbacks];
        ARCOMMANDS_Decoder_SetARDrone3NetworkStateWifiScanListChangedCallback(ardrone3_networkstate_wifiscanlistchanged_callback, (__bridge void *)(self));
    
        ARCOMMANDS_Decoder_SetARDrone3NetworkStateWifiAuthChannelListChangedCallback(ardrone3_networkstate_wifiauthchannellistchanged_callback, (__bridge void *)(self));
        
#ifdef ARCOMMANDS_HAS_DEBUG_COMMANDS
        [self registerARDrone3DebugARCommandsCallbacks];
#endif
    }
    
    if (!failed && !_startCancelled)
    {
        NSDate *currentDate = [NSDate date];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
        [dateFormatter setLocale:[NSLocale systemLocale]];
        
        // Set date
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
        [self DeviceController_SendCommonCurrentDate:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withDate:(char *)[[dateFormatter stringFromDate:currentDate] cStringUsingEncoding:NSUTF8StringEncoding]];

        // Set time
        [dateFormatter setDateFormat:@"'T'HHmmssZZZ"];
        [self DeviceController_SendCommonCurrentTime:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withTime:(char *)[[dateFormatter stringFromDate:currentDate] cStringUsingEncoding:NSUTF8StringEncoding]];
    }
    
    if (!failed && !_startCancelled)
    {
        // Attempt to get initial settings
        [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerNotificationAllSettingsDidStart object:self userInfo:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stateAllSettingsChanged:) name:DeviceControllerSettingsStateAllSettingsChangedNotification object:nil];
        
        
        [_initialSettingsReceivedCondition lock];
        BOOL sent = [self DeviceController_SendSettingsAllSettings:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil];
        if(sent)
        {
            [_initialSettingsReceivedCondition wait];
        }
        
        if (!_initialSettingsReceived)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Initial settings retrieval timed out.");
            failed = YES;
        }
        [_initialSettingsReceivedCondition unlock];
    }
    
    if (!failed && !_startCancelled)
    {
        // Attempt to get initial states
        [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerNotificationAllStatesDidStart object:self userInfo:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stateAllStatesChanged:) name:DeviceControllerCommonStateAllStatesChangedNotification object:nil];
        
        [_initialStatesReceivedCondition lock];
        BOOL sent = [self DeviceController_SendCommonAllStates:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil];
        if(sent)
        {
            [_initialStatesReceivedCondition wait];
        }
        
        if (!_initialStatesReceived)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Initial states retrieval timed out.");
            failed = YES;
        }
        [_initialStatesReceivedCondition unlock];
    }

    if (!failed && !_startCancelled)
    {
        [self registerCurrentProduct];
        _videoRecordController = [[ARDrone3VideoRecordController alloc] init];
        _videoRecordController.deviceController = self;
        _photoRecordController = [[ARDrone3PhotoRecordController alloc] init];
        _photoRecordController.deviceController = self;
    }
    
    return (failed == NO);
}

- (void)privateStop
{
    _videoRecordController = nil;
    _photoRecordController = nil;
    [self unregisterARDrone3ARCommandsCallbacks];
#ifdef ARCOMMANDS_HAS_DEBUG_COMMANDS
    [self unregisterARDrone3DebugARCommandsCallbacks];
#endif
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

static void ardrone3_networkstate_wifiscanlistchanged_callback(char * ssid, int16_t rssi, eARCOMMANDS_ARDRONE3_NETWORKSTATE_WIFISCANLISTCHANGED_BAND band, uint8_t channel, void *custom)
{
    ARDrone3DeviceController *self = (__bridge ARDrone3DeviceController*)custom;
    if ([NSString stringWithCString:ssid encoding:NSUTF8StringEncoding] != nil)
    {
        
        NSDictionary* dict = [NSDictionary dictionaryWithObjects:@[[NSString stringWithCString:ssid encoding:NSUTF8StringEncoding], [NSNumber numberWithShort:rssi], [NSNumber numberWithInt:band], [NSNumber numberWithUnsignedChar:channel]] forKeys:@[ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotificationSsidKey, ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotificationRssiKey, ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotificationBandKey, ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotificationChannelKey]];
        NSMutableDictionary *listDictionary = [self.privateNotificationsDictionary objectForKey:ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotification];
        if(listDictionary == nil)
        {
            listDictionary = [NSMutableDictionary dictionary];
        }
        [listDictionary setObject:dict forKey:[NSNumber numberWithInt:[listDictionary count]]];
        dict = listDictionary;
        [self.privateNotificationsDictionary setObject:dict forKey:ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotification];
        [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerNotificationsDictionaryChanged object:self userInfo:[NSDictionary dictionaryWithObject:dict forKey:ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotification]];
        [[NSNotificationCenter defaultCenter] postNotificationName:ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotification object:self userInfo:dict];
    }
}

static void ardrone3_networkstate_wifiauthchannellistchanged_callback(eARCOMMANDS_ARDRONE3_NETWORKSTATE_WIFIAUTHCHANNELLISTCHANGED_BAND band, uint8_t channel, uint8_t in_or_out, void *custom)
{
    ARDrone3DeviceController *self = (__bridge ARDrone3DeviceController*)custom;
    NSDictionary* dict = [NSDictionary dictionaryWithObjects:@[[NSNumber numberWithInt:band], [NSNumber numberWithUnsignedChar:channel], [NSNumber numberWithUnsignedChar:in_or_out]] forKeys:@[ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotificationBandKey, ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotificationChannelKey, ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotificationIn_or_outKey]];
    NSMutableDictionary *listDictionary = [self.privateNotificationsDictionary objectForKey:ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotification];
    if(listDictionary == nil)
    {
        listDictionary = [NSMutableDictionary dictionary];
    }
    [listDictionary setObject:dict forKey:[NSNumber numberWithInt:[listDictionary count]]];
    dict = listDictionary;
    [self.privateNotificationsDictionary setObject:dict forKey:ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotification];
    [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerNotificationsDictionaryChanged object:self userInfo:[NSDictionary dictionaryWithObject:dict forKey:ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotification]];
    [[NSNotificationCenter defaultCenter] postNotificationName:ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotification object:self userInfo:dict];
}

- (void)ardrone3_networkstate_wifiscanlist_clean
{
    [self.privateNotificationsDictionary removeObjectForKey:ARDrone3DeviceControllerNetworkStateWifiScanListChangedNotification];
    [self.privateNotificationsDictionary removeObjectForKey:ARDrone3DeviceControllerNetworkStateAllWifiScanChangedNotification];
}

- (void)ardrone3_networkstate_wifiauthchannellist_clean
{
    [self.privateNotificationsDictionary removeObjectForKey:ARDrone3DeviceControllerNetworkStateWifiAuthChannelListChangedNotification];
    [self.privateNotificationsDictionary removeObjectForKey:ARDrone3DeviceControllerNetworkStateAllWifiAuthChannelChangedNotification];
}

@end

