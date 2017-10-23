//
//  BebopDrone.m
//  SDKSample
//

#import "SkyController.h"
#import "SDCardModule.h"

@interface SkyController ()<SDCardModuleDelegate>

@property (nonatomic, assign) ARCONTROLLER_Device_t *deviceController;
@property (nonatomic, assign) ARService *service;
@property (nonatomic, strong) SDCardModule *sdCardModule;
@property (nonatomic, assign) eARCONTROLLER_DEVICE_STATE connectionState;
@property (nonatomic, assign) eARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE flyingState;
@property (nonatomic, strong) NSString *currentRunId;
@property (nonatomic, assign) ARDISCOVERY_Device_t *discoveryDevice;
@end

@implementation SkyController

-(id)initWithService:(ARService *)service {
    self = [super init];
    if (self) {
        _service = service;
        _flyingState = ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_LANDED;
    }
    return self;
}

- (void)dealloc
{
    if (_deviceController) {
        ARCONTROLLER_Device_Delete(&_deviceController);
    }

    // release the sdCardModule before releasing the discovery device
    _sdCardModule = nil;
    if (_discoveryDevice) {
        ARDISCOVERY_Device_Delete (&_discoveryDevice);
    }
}

- (void)connect {
    
    if (!_deviceController) {
        // call createDeviceControllerWithService in background
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // if the product type of the service matches with the supported types
            eARDISCOVERY_PRODUCT product = _service.product;
            eARDISCOVERY_PRODUCT_FAMILY family = ARDISCOVERY_getProductFamily(product);
            if (family == ARDISCOVERY_PRODUCT_FAMILY_SKYCONTROLLER) {
                // create the device controller
                [self createDeviceControllerWithService:_service];
                [self createSDCardModule];
            }
        });
    } else {
        ARCONTROLLER_Device_Start (_deviceController);
    }
}

- (void)disconnect {
    ARCONTROLLER_Device_Stop (_deviceController);
}

- (eARCONTROLLER_DEVICE_STATE)connectionState {
    return _connectionState;
}

- (eARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE)flyingState {
    return _flyingState;
}

- (void)createDeviceControllerWithService:(ARService*)service {
    // first get a discovery device
    _discoveryDevice = [self createDiscoveryDeviceWithService:service];
    
    if (_discoveryDevice != NULL) {
        eARCONTROLLER_ERROR error = ARCONTROLLER_OK;
        
        // create the device controller
        _deviceController = ARCONTROLLER_Device_New (_discoveryDevice, &error);

        // add the state change callback to be informed when the device controller starts, stops...
        if (error == ARCONTROLLER_OK) {
            error = ARCONTROLLER_Device_AddStateChangedCallback(_deviceController, stateChanged, (__bridge void *)(self));
        }
        
        // add the command received callback to be informed when a command has been received from the device
        if (error == ARCONTROLLER_OK) {
            error = ARCONTROLLER_Device_AddCommandReceivedCallback(_deviceController, onCommandReceived, (__bridge void *)(self));
        }
        
        // add the received frame callback to be informed when a frame should be displayed
        if (error == ARCONTROLLER_OK) {
            error = ARCONTROLLER_Device_SetVideoStreamMP4Compliant(_deviceController, 1);
        }
        
        // add the received frame callback to be informed when a frame should be displayed
        if (error == ARCONTROLLER_OK) {
            error = ARCONTROLLER_Device_SetVideoStreamCallbacks(_deviceController, configDecoderCallback,
                                                                didReceiveFrameCallback, NULL , (__bridge void *)(self));
        }
        
        // add the extension state callback to be informed when a drone is connected to the SkyController
        if (error == ARCONTROLLER_OK) {
            error = ARCONTROLLER_Device_AddExtensionStateChangedCallback(_deviceController, extensionStateChanged, (__bridge void *)(self));
        }
        
        // start the device controller (the callback stateChanged should be called soon)
        if (error == ARCONTROLLER_OK) {
            error = ARCONTROLLER_Device_Start (_deviceController);
        }
        
        // if an error occured, inform the delegate that the state is stopped
        if (error != ARCONTROLLER_OK) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate skyController:self scConnectionDidChange:ARCONTROLLER_DEVICE_STATE_STOPPED];
            });
        }
    } else {
        // if an error occured, inform the delegate that the state is stopped
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate skyController:self scConnectionDidChange:ARCONTROLLER_DEVICE_STATE_STOPPED];
        });
    }
}

- (ARDISCOVERY_Device_t *)createDiscoveryDeviceWithService:(ARService*)service {
    ARDISCOVERY_Device_t *device = NULL;
    eARDISCOVERY_ERROR errorDiscovery = ARDISCOVERY_OK;
    
    device = [service createDevice:&errorDiscovery];
    
    if (errorDiscovery != ARDISCOVERY_OK)
        NSLog(@"Discovery error :%s", ARDISCOVERY_Error_ToString(errorDiscovery));
    
    return device;
}

- (void)createSDCardModule {
    if (_discoveryDevice) {
        _sdCardModule = [[SDCardModule alloc] initWithDiscoveryDevice:_discoveryDevice];
        _sdCardModule.delegate = self;
    }
}

#pragma mark commands
- (void)emergency {
    if (_deviceController &&
        (ARCONTROLLER_Device_GetExtensionState(_deviceController, NULL) == ARCONTROLLER_DEVICE_STATE_RUNNING) &&
        (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->aRDrone3->sendPilotingEmergency(_deviceController->aRDrone3);
    }
}

- (void)takeOff {
    if (_deviceController &&
        (ARCONTROLLER_Device_GetExtensionState(_deviceController, NULL) == ARCONTROLLER_DEVICE_STATE_RUNNING) &&
        (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->aRDrone3->sendPilotingTakeOff(_deviceController->aRDrone3);
    }
}

- (void)land {
    if (_deviceController &&
        (ARCONTROLLER_Device_GetExtensionState(_deviceController, NULL) == ARCONTROLLER_DEVICE_STATE_RUNNING) &&
        (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->aRDrone3->sendPilotingLanding(_deviceController->aRDrone3);
    }
}

- (void)takePicture {
    if (_deviceController &&
        (ARCONTROLLER_Device_GetExtensionState(_deviceController, NULL) == ARCONTROLLER_DEVICE_STATE_RUNNING) &&
        (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->aRDrone3->sendMediaRecordPictureV2(_deviceController->aRDrone3);
    }
}

-(void)downloadMedias {
    if (_currentRunId && ![_currentRunId isEqualToString:@""]) {
        [_sdCardModule getFlightMedias:_currentRunId];
    } else {
        [_sdCardModule getTodaysFlightMedias];
    }
    
}

- (void)cancelDownloadMedias {
    [_sdCardModule cancelGetMedias];
}

#pragma mark Device controller callbacks
// called when the state of the device controller has changed
static void stateChanged (eARCONTROLLER_DEVICE_STATE newState, eARCONTROLLER_ERROR error, void *customData) {
    SkyController *sc = (__bridge SkyController*)customData;
    if (sc != nil) {
        switch (newState) {
            case ARCONTROLLER_DEVICE_STATE_RUNNING:
                break;
            case ARCONTROLLER_DEVICE_STATE_STOPPED:
                break;
            default:
                break;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            sc.connectionState = newState;
            [sc.delegate skyController:sc scConnectionDidChange:newState];
        });
    }
}

static void extensionStateChanged (eARCONTROLLER_DEVICE_STATE newState, eARDISCOVERY_PRODUCT product,
                                   const char *name, eARCONTROLLER_ERROR error, void *customData) {
    SkyController *sc = (__bridge SkyController*)customData;
    if (sc != nil) {
        switch (newState) {
            case ARCONTROLLER_DEVICE_STATE_RUNNING:
                ARCONTROLLER_Device_StartVideoStream(sc.deviceController);
                break;
            case ARCONTROLLER_DEVICE_STATE_STOPPED:
                break;
            default:
                break;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [sc.delegate skyController:sc droneConnectionDidChange:newState];
        });
    }
}

// called when a command has been received from the drone
static void onCommandReceived (eARCONTROLLER_DICTIONARY_KEY commandKey, ARCONTROLLER_DICTIONARY_ELEMENT_t *elementDictionary, void *customData) {
    SkyController *sc = (__bridge SkyController*)customData;
    
    // if the command received is a battery state changed
    if ((commandKey == ARCONTROLLER_DICTIONARY_KEY_COMMON_COMMONSTATE_BATTERYSTATECHANGED) &&
        (elementDictionary != NULL)) {
        ARCONTROLLER_DICTIONARY_ARG_t *arg = NULL;
        ARCONTROLLER_DICTIONARY_ELEMENT_t *element = NULL;
        
        HASH_FIND_STR (elementDictionary, ARCONTROLLER_DICTIONARY_SINGLE_KEY, element);
        if (element != NULL) {
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_COMMON_COMMONSTATE_BATTERYSTATECHANGED_PERCENT, arg);
            if (arg != NULL) {
                uint8_t battery = arg->value.U8;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [sc.delegate skyController:sc droneBatteryDidChange:battery];
                });
            }
        }
    }
    // if the command received is a battery state changed
    else if ((commandKey == ARCONTROLLER_DICTIONARY_KEY_SKYCONTROLLER_SKYCONTROLLERSTATE_BATTERYCHANGED) &&
        (elementDictionary != NULL)) {
        ARCONTROLLER_DICTIONARY_ARG_t *arg = NULL;
        ARCONTROLLER_DICTIONARY_ELEMENT_t *element = NULL;
        
        HASH_FIND_STR (elementDictionary, ARCONTROLLER_DICTIONARY_SINGLE_KEY, element);
        if (element != NULL) {
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_SKYCONTROLLER_SKYCONTROLLERSTATE_BATTERYCHANGED_PERCENT, arg);
            if (arg != NULL) {
                uint8_t battery = arg->value.U8;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [sc.delegate skyController:sc scBatteryDidChange:battery];
                });
            }
        }
    }
    // if the command received is a battery state changed
    else if ((commandKey == ARCONTROLLER_DICTIONARY_KEY_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED) &&
        (elementDictionary != NULL)) {
        ARCONTROLLER_DICTIONARY_ARG_t *arg = NULL;
        ARCONTROLLER_DICTIONARY_ELEMENT_t *element = NULL;
        
        HASH_FIND_STR (elementDictionary, ARCONTROLLER_DICTIONARY_SINGLE_KEY, element);
        if (element != NULL) {
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE, arg);
            if (arg != NULL) {
                sc.flyingState = arg->value.I32;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [sc.delegate skyController:sc flyingStateDidChange:sc.flyingState];
                });
            }
        }
    }
    // if the command received is a run id changed
    else if ((commandKey == ARCONTROLLER_DICTIONARY_KEY_COMMON_RUNSTATE_RUNIDCHANGED) &&
             (elementDictionary != NULL)) {
        ARCONTROLLER_DICTIONARY_ARG_t *arg = NULL;
        ARCONTROLLER_DICTIONARY_ELEMENT_t *element = NULL;
        
        HASH_FIND_STR (elementDictionary, ARCONTROLLER_DICTIONARY_SINGLE_KEY, element);
        if (element != NULL) {
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_COMMON_RUNSTATE_RUNIDCHANGED_RUNID, arg);
            if (arg != NULL) {
                char * runId = arg->value.String;
                if (runId != NULL) {
                    sc.currentRunId = [NSString stringWithUTF8String:runId];
                }
            }
        }
    }
}

static eARCONTROLLER_ERROR configDecoderCallback (ARCONTROLLER_Stream_Codec_t codec, void *customData) {
    SkyController *sc = (__bridge SkyController*)customData;
    
    BOOL success = [sc.delegate skyController:sc configureDecoder:codec];
    
    return (success) ? ARCONTROLLER_OK : ARCONTROLLER_ERROR;
}

static eARCONTROLLER_ERROR didReceiveFrameCallback (ARCONTROLLER_Frame_t *frame, void *customData) {
    SkyController *sc = (__bridge SkyController*)customData;
    
    BOOL success = [sc.delegate skyController:sc didReceiveFrame:frame];
    
    return (success) ? ARCONTROLLER_OK : ARCONTROLLER_ERROR;
}


#pragma mark SDCardModuleDelegate
- (void)sdcardModule:(SDCardModule*)module didFoundMatchingMedias:(NSUInteger)nbMedias {
    [_delegate skyController:self didFoundMatchingMedias:nbMedias];
}

- (void)sdcardModule:(SDCardModule*)module media:(NSString*)mediaName downloadDidProgress:(int)progress {
    [_delegate skyController:self media:mediaName downloadDidProgress:progress];
}

- (void)sdcardModule:(SDCardModule*)module mediaDownloadDidFinish:(NSString*)mediaName {
    [_delegate skyController:self mediaDownloadDidFinish:mediaName];
}

@end
