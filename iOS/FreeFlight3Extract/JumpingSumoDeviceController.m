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
//  JumpingSumoDeviceController.m
//  ARFreeFlight
//
//  Created by Hugo Grostabussiat on 06/12/2013.
//  Copyright (c) 2013 Parrot SA. All rights reserved.
//
#import <libARSAL/ARSAL.h>
#import <libARCommands/ARCommands.h>
#import "JumpingSumoDeviceController+libARCommands.h"
#import "JumpingSumoDeviceController+libARCommandsDebug.h"
#import "JumpingSumoARNetworkConfig.h"
#import "DeviceControllerProtected.h"
#import "JumpingSumoVideoRecordController.h"
#import "JumpingSumoPhotoRecordController.h"

static const char* TAG = "JumpingSumoDeviceController";
static const NSTimeInterval LOOP_INTERVAL = 0.05;

typedef struct
{
    // Screen flag state.
    BOOL screenFlag;
    
    // Target speed and turn ratio. Sent each loop.
    float speed;
    float turnRatio;
    
    // Local state we want to set to the remote device.
    // Nothing yet...
    
} JSData_t;

@interface JumpingSumoDeviceController () <ARNetworkSendStatusDelegate>
@property (nonatomic) NSRecursiveLock *stateLock;
@property (nonatomic) JSData_t jsState;
@property (nonatomic) NSRecursiveLock *jsStateLock;
@property (atomic) BOOL startCancelled;
@property (nonatomic) BOOL initialSettingsReceived;
@property (nonatomic) NSCondition *initialSettingsReceivedCondition;
@property (nonatomic) BOOL initialStatesReceived;
@property (nonatomic) NSCondition *initialStatesReceivedCondition;
@end

@implementation JumpingSumoDeviceController
#pragma mark - Public methods implementation.
- (id)initWithService:(ARService *)service
{
    JumpingSumoARNetworkConfig *netConfig = [[JumpingSumoARNetworkConfig alloc] init];
    self = [super initWithARNetworkConfig:netConfig withARService:service withBridgeDeviceController:nil withLoopInterval:LOOP_INTERVAL];
    if (self != nil) {
        _stateLock = [[NSRecursiveLock alloc] init];
        _state = DEVICE_CONTROLLER_STATE_STOPPED;
        _jsStateLock = [[NSRecursiveLock alloc] init];
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
    JSData_t localState;
    
    [_stateLock lock];
    currentState = _state;
    [_stateLock unlock];
    
    switch(currentState)
    {
        case DEVICE_CONTROLLER_STATE_STARTED:
            // Make a copy of the JS state.
            [_jsStateLock lock];
            localState = _jsState;
            [_jsStateLock unlock];
            
            [self JumpingSumoDeviceController_SendPilotingPCMD:[JumpingSumoARNetworkConfig c2dNackId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withFlag:localState.screenFlag withSpeed:(int8_t)(localState.speed * 100.f) withTurn:(int8_t)(localState.turnRatio * 100.f)];
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
- (void)userChangedSpeed:(float)speed
{
    [_jsStateLock lock];
    _jsState.speed = speed;
    [_jsStateLock unlock];
}

- (void)userChangedTurnRatio:(float)turnRatio
{
    [_jsStateLock lock];
    _jsState.turnRatio = turnRatio;
    [_jsStateLock unlock];
}

- (void)userChangedScreenFlag:(BOOL)flag
{
    [_jsStateLock lock];
    _jsState.screenFlag = flag;
    [_jsStateLock unlock];
}

- (void)userChangedPosture:(eARCOMMANDS_JUMPINGSUMO_PILOTING_POSTURE_TYPE)posture
{
    /* Send a command immediately. */
    [self JumpingSumoDeviceController_SendPilotingPosture:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withType:posture];
}

- (void)userRequestedHighJump
{
    [self JumpingSumoDeviceController_SendAnimationsJump:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withType:ARCOMMANDS_JUMPINGSUMO_ANIMATIONS_JUMP_TYPE_HIGH];
}

- (void)userRequestedLongJump
{
    [self JumpingSumoDeviceController_SendAnimationsJump:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withType:ARCOMMANDS_JUMPINGSUMO_ANIMATIONS_JUMP_TYPE_LONG];
}

- (void)userRequestedJumpStop
{
    [self JumpingSumoDeviceController_SendAnimationsJumpStop:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestedJumpCancel
{
    [self JumpingSumoDeviceController_SendAnimationsJumpCancel:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestedJumpLoad
{
    [self JumpingSumoDeviceController_SendAnimationsJumpLoad:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userTriggeredAnimation:(eARCOMMANDS_JUMPINGSUMO_ANIMATIONS_SIMPLEANIMATION_ID)animation
{
    [self JumpingSumoDeviceController_SendAnimationsSimpleAnimation:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withId:(uint16_t)animation];
}

- (void)userTriggeredDefaultSound
{
    [self JumpingSumoDeviceController_SendAudioPlaySoundWithName:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withFilename:"default_sound.wav"];
}

- (void)userTriggeredLeft90
{
    [self JumpingSumoDeviceController_SendAnimationAddCapOffset:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withOffset:-M_PI_2];
}

- (void)userTriggeredRight90
{
    [self JumpingSumoDeviceController_SendAnimationAddCapOffset:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withOffset:M_PI_2];
}

- (void)userTriggeredLeftTurnback
{
    [self JumpingSumoDeviceController_SendAnimationAddCapOffset:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withOffset:M_PI];
}

- (void)userTriggeredRightTurnback
{
    [self JumpingSumoDeviceController_SendAnimationAddCapOffset:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withOffset:-M_PI];
}

- (void)userRequestedRecordPicture:(int)massStorageId
{
    [self JumpingSumoDeviceController_SendMediaRecordPicture:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withMass_storage_id:massStorageId];
}

- (void)userRequestedRecordVideoStart:(int)massStorageId
{
    [self JumpingSumoDeviceController_SendMediaRecordVideo:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withRecord:ARCOMMANDS_JUMPINGSUMO_MEDIARECORD_VIDEO_RECORD_START withMass_storage_id:massStorageId];
}

- (void)userRequestedRecordVideoStop:(int)massStorageId
{
    [self JumpingSumoDeviceController_SendMediaRecordVideo:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withRecord:ARCOMMANDS_JUMPINGSUMO_MEDIARECORD_VIDEO_RECORD_STOP withMass_storage_id:massStorageId];
}

- (void)userRequestedScriptListRefresh
{
    [self JumpingSumoDeviceController_SendRoadPlanAllScriptsMetadata:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil];
}

- (void)userUploadedScript:(NSUUID *)uuid withMd5:(NSString *)md5Hash
{
    char* cUuid = strdup([[uuid UUIDString].lowercaseString cStringUsingEncoding:NSUTF8StringEncoding]);
    char* cMd5 = strdup([md5Hash cStringUsingEncoding:NSUTF8StringEncoding]);
    [self JumpingSumoDeviceController_SendRoadPlanScriptUploaded:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil withUuid:cUuid withMd5Hash:cMd5];
    free(cUuid);
    free(cMd5);
}

- (void)userRequestedScriptDeletion:(NSUUID*)uuid
{
    char* cUuid = strdup([[uuid UUIDString].lowercaseString cStringUsingEncoding:NSUTF8StringEncoding]);
    [self JumpingSumoDeviceController_SendRoadPlanScriptDelete:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil withUuid:cUuid];
    free(cUuid);
}

- (void)userTriggeredScriptWithUuid:(NSUUID *)uuid
{
    char* uuidStr = strdup([[uuid UUIDString].lowercaseString cStringUsingEncoding:NSUTF8StringEncoding]);
    [self JumpingSumoDeviceController_SendRoadPlanPlayScript:[JumpingSumoARNetworkConfig c2dNackId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withUuid:uuidStr];
    free(uuidStr);
}

- (void)userRequestedSettingsProductName:(NSString *)productName
{
    [self DeviceController_SendSettingsProductName:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withName:(char *)[productName cStringUsingEncoding:NSUTF8StringEncoding]];
}

- (void)userRequestedSettingsReset
{
    [self DeviceController_SendSettingsReset:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestedSettingsCountry:(NSString *)country
{
    char* countryChar = strdup([country cStringUsingEncoding:NSUTF8StringEncoding]);
    [self DeviceController_SendSettingsCountry:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withCode:countryChar];
}

- (void)userRequestedSettingsNetworkWifiType:(eARCOMMANDS_JUMPINGSUMO_NETWORKSETTINGS_WIFISELECTION_TYPE)type band:(eARCOMMANDS_JUMPINGSUMO_NETWORKSETTINGS_WIFISELECTION_BAND)band channel:(int)channel
{
    [self JumpingSumoDeviceController_SendNetworkSettingsWifiSelection:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withType:type withBand:band withChannel:channel];
}

- (void)userRequestedSettingsNetworkWifiScan:(eARCOMMANDS_JUMPINGSUMO_NETWORK_WIFISCAN_BAND)band
{
    [self JumpingSumoDeviceController_SendNetworkWifiScan:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withBand:band];
}

- (void)userRequestedSettingsNetworkWifiAuthChannel
{
    [self JumpingSumoDeviceController_SendNetworkWifiAuthChannel:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestedSettingsAudioMasterVolume:(uint8_t)volume
{
    if ((volume >= 0) && (volume <= 100))
    {
        [self JumpingSumoDeviceController_SendAudioSettingsMasterVolume:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withVolume:volume];
    }
    // NO ELSE: Fail silently.
}


- (void)userRequestedSettingsAudioTheme:(eARCOMMANDS_JUMPINGSUMO_AUDIOSETTINGS_THEME_THEME)theme
{
    [self JumpingSumoDeviceController_SendAudioSettingsTheme:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withTheme:theme];
}

- (void)userRequestedReboot
{
    [self DeviceController_SendCommonReboot:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}


- (void)userRequestAutoCountry:(int)automatic
{
    [self DeviceController_SendSettingsAutoCountry:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withAutomatic:automatic];
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
        sentStatus = [self sendData:cmdbuf withSize:actualSize onBufferWithId:[JumpingSumoARNetworkConfig c2dAckId]withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil];
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
    NSDictionary *vidEnDict = [nDict objectForKey:JumpingSumoDeviceControllerMediaStreamingStateVideoEnableChangedNotification];
    if (vidEnDict == nil)
    {
        // The JS sent no value at startup. The firmware does not support video streaming control.
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
    NSDictionary *vidEnDict = [nDict objectForKey:JumpingSumoDeviceControllerMediaStreamingStateVideoEnableChangedNotification];
    if (vidEnDict != nil)
    {
        NSNumber *enNumber = [vidEnDict objectForKey:JumpingSumoDeviceControllerMediaStreamingStateVideoEnableChangedNotificationEnabledKey];
        retval = enNumber.boolValue;
    }
    // NO ELSE: Keep the default value (YES).
    return retval;
}

- (void)enableVideoStreaming:(BOOL)enable
{
    [self JumpingSumoDeviceController_SendMediaStreamingVideoEnable:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil withEnable:(enable ? 1 : 0)];
}

#pragma mark - Miscellaneous private methods.

- (void)initJsState
{
    [_jsStateLock lock];
    _jsState.screenFlag = NO;
    _jsState.speed = 0.0f;
    _jsState.turnRatio = 0.0f;
    [_jsStateLock unlock];
}

- (BOOL)privateStart
{
    BOOL failed = NO;
    
    /* Initialize initial commands state. */
    [self initJsState];
    
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
        [self registerJumpingSumoARCommandsCallbacks];
        // Command class NetworkState
        ARCOMMANDS_Decoder_SetJumpingSumoNetworkStateWifiScanListChangedCallback(jumpingsumo_networkstate_wifiscanlistchanged_callback, (__bridge void *)(self));
        ARCOMMANDS_Decoder_SetJumpingSumoNetworkStateWifiAuthChannelListChangedCallback(jumpingsumo_networkstate_wifiauthchannellistchanged_callback, (__bridge void *)(self));
        
        ARCOMMANDS_Decoder_SetJumpingSumoNetworkStateAllWifiAuthChannelChangedCallback(jumpingsumo_networkstate_allwifiauthchannelchanged_callback, (__bridge void *)(self));
        
#ifdef ARCOMMANDS_HAS_DEBUG_COMMANDS
        [self registerJumpingSumoDebugARCommandsCallbacks];
#endif
    }

    if (!failed && !_startCancelled)
    {
        NSDate *currentDate = [NSDate date];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
        [dateFormatter setLocale:[NSLocale systemLocale]];
        
        // Set Date
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
        [self DeviceController_SendCommonCurrentDate:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil withDate:(char *)[[dateFormatter stringFromDate:currentDate] cStringUsingEncoding:NSUTF8StringEncoding]];
        
        // Set time
        [dateFormatter setDateFormat:@"'T'HHmmssZZZ"];
        [self DeviceController_SendCommonCurrentTime:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil withTime:(char *)[[dateFormatter stringFromDate:currentDate] cStringUsingEncoding:NSUTF8StringEncoding]];
    }
    
    if (!failed && !_startCancelled)
    {
        // Attempt to get initial settings
        [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerNotificationAllSettingsDidStart object:self userInfo:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stateAllSettingsChanged:) name:DeviceControllerSettingsStateAllSettingsChangedNotification object:nil];
        [self DeviceController_SendSettingsAllSettings:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil];
        [_initialSettingsReceivedCondition lock];
        [_initialSettingsReceivedCondition wait];
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
        [self DeviceController_SendCommonAllStates:[JumpingSumoARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_RETRY withCompletionBlock:nil];
        [_initialStatesReceivedCondition lock];
        [_initialStatesReceivedCondition wait];
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
        _videoRecordController = [[JumpingSumoVideoRecordController alloc] init];
        _videoRecordController.deviceController = self;
        _photoRecordController = [[JumpingSumoPhotoRecordController alloc] init];
        _photoRecordController.deviceController = self;
    }

    return (failed == NO);
}

- (void)privateStop
{
    _videoRecordController = nil;
    _photoRecordController = nil;
    [self unregisterJumpingSumoARCommandsCallbacks];
#ifdef ARCOMMANDS_HAS_DEBUG_COMMANDS
    [self unregisterJumpingSumoDebugARCommandsCallbacks];
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


- (void)jumpingsumo_networkstate_wifiscanlist_clean
{
    [self.privateNotificationsDictionary removeObjectForKey:JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotification];
    [self.privateNotificationsDictionary removeObjectForKey:JumpingSumoDeviceControllerNetworkStateAllWifiScanChangedNotification];
}

- (void)jumpingsumo_networkstate_wifiauthchannellist_clean
{
    [self.privateNotificationsDictionary removeObjectForKey:JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotification];
    [self.privateNotificationsDictionary removeObjectForKey:JumpingSumoDeviceControllerNetworkStateAllWifiAuthChannelChangedNotification];
}

static void jumpingsumo_networkstate_wifiscanlistchanged_callback(char * ssid, int16_t rssi, eARCOMMANDS_JUMPINGSUMO_NETWORKSTATE_WIFISCANLISTCHANGED_BAND band, uint8_t channel, void *custom)
{
    JumpingSumoDeviceController *self = (__bridge JumpingSumoDeviceController*)custom;
    if ([NSString stringWithCString:ssid encoding:NSUTF8StringEncoding] != nil)
    {
        NSDictionary* dict = [NSDictionary dictionaryWithObjects:@[[NSString stringWithCString:ssid encoding:NSUTF8StringEncoding], [NSNumber numberWithShort:rssi], [NSNumber numberWithInt:band], [NSNumber numberWithUnsignedChar:channel]] forKeys:@[JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotificationSsidKey, JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotificationRssiKey, JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotificationBandKey, JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotificationChannelKey]];
        NSMutableDictionary *listDictionary = [self.privateNotificationsDictionary objectForKey:JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotification];
        if(listDictionary == nil)
        {
            listDictionary = [NSMutableDictionary dictionary];
        }
        [listDictionary setObject:dict forKey:[NSNumber numberWithInt:[listDictionary count]]];
        dict = listDictionary;
        [self.privateNotificationsDictionary setObject:dict forKey:JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotification];
        [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerNotificationsDictionaryChanged object:self userInfo:[NSDictionary dictionaryWithObject:dict forKey:JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotification]];
        [[NSNotificationCenter defaultCenter] postNotificationName:JumpingSumoDeviceControllerNetworkStateWifiScanListChangedNotification object:self userInfo:dict];
    }
}

static void jumpingsumo_networkstate_wifiauthchannellistchanged_callback(eARCOMMANDS_JUMPINGSUMO_NETWORKSTATE_WIFIAUTHCHANNELLISTCHANGED_BAND band, uint8_t channel, uint8_t in_or_out, void *custom)
{
    JumpingSumoDeviceController *self = (__bridge JumpingSumoDeviceController*)custom;
    NSDictionary* dict = [NSDictionary dictionaryWithObjects:@[[NSNumber numberWithInt:band], [NSNumber numberWithUnsignedChar:channel], [NSNumber numberWithUnsignedChar:in_or_out]] forKeys:@[JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotificationBandKey, JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotificationChannelKey, JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotificationIn_or_outKey]];
    NSMutableDictionary *listDictionary = [self.privateNotificationsDictionary objectForKey:JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotification];
    if(listDictionary == nil)
    {
        listDictionary = [NSMutableDictionary dictionary];
    }
    [listDictionary setObject:dict forKey:[NSNumber numberWithInt:[listDictionary count]]];
    dict = listDictionary;
    [self.privateNotificationsDictionary setObject:dict forKey:JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotification];
    [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerNotificationsDictionaryChanged object:self userInfo:[NSDictionary dictionaryWithObject:dict forKey:JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotification]];
    [[NSNotificationCenter defaultCenter] postNotificationName:JumpingSumoDeviceControllerNetworkStateWifiAuthChannelListChangedNotification object:self userInfo:dict];
}

static void jumpingsumo_networkstate_allwifiauthchannelchanged_callback(void *custom)
{
    JumpingSumoDeviceController *self = (__bridge JumpingSumoDeviceController*)custom;
    NSDictionary* dict = [NSDictionary dictionary];
    [self.privateNotificationsDictionary setObject:dict forKey:JumpingSumoDeviceControllerNetworkStateAllWifiAuthChannelChangedNotification];
    [[NSNotificationCenter defaultCenter] postNotificationName:DeviceControllerNotificationsDictionaryChanged object:self userInfo:[NSDictionary dictionaryWithObject:dict forKey:JumpingSumoDeviceControllerNetworkStateAllWifiAuthChannelChangedNotification]];
}

@end


