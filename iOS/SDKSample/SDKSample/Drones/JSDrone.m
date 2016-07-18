//
//  JSDrone.m
//  SDKSample
//

#import "JSDrone.h"
#import "SDCardModule.h"

#define FTP_PORT 21

@interface JSDrone ()<SDCardModuleDelegate>

@property (nonatomic, assign) ARCONTROLLER_Device_t *deviceController;
@property (nonatomic, assign) ARService *service;
@property (nonatomic, strong) SDCardModule *sdCardModule;
@property (nonatomic, assign) eARCONTROLLER_DEVICE_STATE connectionState;
@property (nonatomic, strong) NSString *currentRunId;
@property (nonatomic) dispatch_semaphore_t resolveSemaphore;
@end

@implementation JSDrone

-(id)initWithService:(ARService *)service {
    self = [super init];
    if (self) {
        _service = service;
    }
    return self;
}

- (void)dealloc
{
    if (_deviceController) {
        ARCONTROLLER_Device_Delete(&_deviceController);
    }
}

- (void)connect {
    
    if (!_deviceController) {
        // call createDeviceControllerWithService in background
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            // if the product type of the service matches with the supported types
            eARDISCOVERY_PRODUCT product = _service.product;
            eARDISCOVERY_PRODUCT_FAMILY family = ARDISCOVERY_getProductFamily(product);
            if (family == ARDISCOVERY_PRODUCT_FAMILY_JS) {
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

- (void)createDeviceControllerWithService:(ARService*)service {
    // first get a discovery device
    ARDISCOVERY_Device_t *discoveryDevice = [self createDiscoveryDeviceWithService:service];
    
    if (discoveryDevice != NULL) {
        eARCONTROLLER_ERROR error = ARCONTROLLER_OK;
        
        // create the device controller
        _deviceController = ARCONTROLLER_Device_New (discoveryDevice, &error);
        
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
            error = ARCONTROLLER_Device_SetVideoStreamCallbacks(_deviceController, configDecoderCallback,
                                                                didReceiveFrameCallback, NULL , (__bridge void *)(self));
        }
        
        // add the received audio frame callback to be informed when a frame should be displayed
        if (error == ARCONTROLLER_OK) {
            error = ARCONTROLLER_Device_SetAudioStreamCallbacks(_deviceController, configAudioDecoderCallback,
                                                                didReceiveAudioFrameCallback, NULL , (__bridge void *)(self));
            if (error == ARCONTROLLER_ERROR_NO_AUDIO) {
                /* This device has no audio stream */
                error = ARCONTROLLER_OK;
            }
        }
        
        // start the device controller (the callback stateChanged should be called soon)
        if (error == ARCONTROLLER_OK) {
            error = ARCONTROLLER_Device_Start (_deviceController);
        }
        
        // we don't need the discovery device anymore
        ARDISCOVERY_Device_Delete (&discoveryDevice);
        
        // if an error occured, inform the delegate that the state is stopped
        if (error != ARCONTROLLER_OK) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_delegate jsDrone:self connectionDidChange:ARCONTROLLER_DEVICE_STATE_STOPPED];
            });
        }
    } else {
        // if an error occured, inform the delegate that the state is stopped
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate jsDrone:self connectionDidChange:ARCONTROLLER_DEVICE_STATE_STOPPED];
        });
    }
}

- (ARDISCOVERY_Device_t *)createDiscoveryDeviceWithService:(ARService*)service {
    ARDISCOVERY_Device_t *device = NULL;
    eARDISCOVERY_ERROR errorDiscovery = ARDISCOVERY_OK;
    
    device = ARDISCOVERY_Device_New (&errorDiscovery);
    
    if (errorDiscovery == ARDISCOVERY_OK) {
        // need to resolve service to get the IP
        BOOL resolveSucceeded = [self resolveService:service];
        
        if (resolveSucceeded) {
            NSString *ip = [[ARDiscovery sharedInstance] convertNSNetServiceToIp:service];
            int port = (int)[(NSNetService *)service.service port];
            
            if (ip) {
                // create a Wifi discovery device
                errorDiscovery = ARDISCOVERY_Device_InitWifi (device, service.product, [service.name UTF8String], [ip UTF8String], port);
            } else {
                NSLog(@"ip is null");
                errorDiscovery = ARDISCOVERY_ERROR;
            }
        } else {
            NSLog(@"Resolve error");
            errorDiscovery = ARDISCOVERY_ERROR;
        }
        
        if (errorDiscovery != ARDISCOVERY_OK) {
            NSLog(@"Discovery error :%s", ARDISCOVERY_Error_ToString(errorDiscovery));
            ARDISCOVERY_Device_Delete(&device);
        }
    }
    
    return device;
}

- (void)createSDCardModule {
    eARUTILS_ERROR ftpError = ARUTILS_OK;
    ARUTILS_Manager_t *ftpListManager = NULL;
    ARUTILS_Manager_t *ftpQueueManager = NULL;
    NSString *ip = [[ARDiscovery sharedInstance] convertNSNetServiceToIp:_service];
    
    ftpListManager = ARUTILS_Manager_New(&ftpError);
    if(ftpError == ARUTILS_OK) {
        ftpQueueManager = ARUTILS_Manager_New(&ftpError);
    }
    
    if (ip) {
        if(ftpError == ARUTILS_OK) {
            ftpError = ARUTILS_Manager_InitWifiFtp(ftpListManager, [ip UTF8String], FTP_PORT, ARUTILS_FTP_ANONYMOUS, "");
        }
        
        if(ftpError == ARUTILS_OK) {
            ftpError = ARUTILS_Manager_InitWifiFtp(ftpQueueManager, [ip UTF8String], FTP_PORT, ARUTILS_FTP_ANONYMOUS, "");
        }
    }
    
    _sdCardModule = [[SDCardModule alloc] initWithFtpListManager:ftpListManager andFtpQueueManager:ftpQueueManager];
    _sdCardModule.delegate = self;
}

#pragma mark commands
- (void)takePicture {
    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        // JumpingSumo (not evo) are still using old deprecated command
        if (_service.product == ARDISCOVERY_PRODUCT_JS) {
            _deviceController->jumpingSumo->sendMediaRecordPicture(_deviceController->jumpingSumo, 0);
        } else {
            _deviceController->jumpingSumo->sendMediaRecordPictureV2(_deviceController->jumpingSumo);
        }
    }
}

- (void)setTurn:(uint8_t)turn {
    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->jumpingSumo->setPilotingPCMDTurn(_deviceController->jumpingSumo, turn);
    }
}

- (void)setSpeed:(uint8_t)speed {
    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->jumpingSumo->setPilotingPCMDSpeed(_deviceController->jumpingSumo, speed);
    }
}

- (void)setFlag:(uint8_t)flag {
    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->jumpingSumo->setPilotingPCMDFlag(_deviceController->jumpingSumo, flag);
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
    JSDrone *jsDrone = (__bridge JSDrone*)customData;
    if (jsDrone != nil) {
        switch (newState) {
            case ARCONTROLLER_DEVICE_STATE_RUNNING:
                jsDrone.deviceController->jumpingSumo->sendMediaStreamingVideoEnable(jsDrone.deviceController->jumpingSumo, 1);
                break;
            case ARCONTROLLER_DEVICE_STATE_STOPPED:
                break;
            default:
                break;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            jsDrone.connectionState = newState;
            [jsDrone.delegate jsDrone:jsDrone connectionDidChange:newState];
        });
    }
}

// called when a command has been received from the drone
static void onCommandReceived (eARCONTROLLER_DICTIONARY_KEY commandKey, ARCONTROLLER_DICTIONARY_ELEMENT_t *elementDictionary, void *customData) {
    JSDrone *jsDrone = (__bridge JSDrone*)customData;
    
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
                    [jsDrone.delegate jsDrone:jsDrone batteryDidChange:battery];
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
                    jsDrone.currentRunId = [NSString stringWithUTF8String:runId];
                }
            }
        }
    }
    // if the command received is audio state changed
    else if ((commandKey == ARCONTROLLER_DICTIONARY_KEY_COMMON_AUDIOSTATE_AUDIOSTREAMINGRUNNING) &&
             (elementDictionary != NULL)) {
        ARCONTROLLER_DICTIONARY_ARG_t *arg = NULL;
        ARCONTROLLER_DICTIONARY_ELEMENT_t *element = NULL;
        
        HASH_FIND_STR (elementDictionary, ARCONTROLLER_DICTIONARY_SINGLE_KEY, element);
        if (element != NULL) {
            HASH_FIND_STR (element->arguments, ARCONTROLLER_DICTIONARY_KEY_COMMON_AUDIOSTATE_AUDIOSTREAMINGRUNNING_RUNNING, arg);
            if (arg != NULL) {
                uint8_t state = arg->value.U8;
                BOOL inputEnabled = (state & 0X01) != 0;
                BOOL outputEnabled = (state & 0X02) != 0;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [jsDrone.delegate jsDrone:jsDrone audioStateDidChangeWithInput:inputEnabled output:outputEnabled];
                });

            }
        }
    }
}

static eARCONTROLLER_ERROR configDecoderCallback (ARCONTROLLER_Stream_Codec_t codec, void *customData) {
    JSDrone *jsDrone = (__bridge JSDrone*)customData;
    
    BOOL success = [jsDrone.delegate jsDrone:jsDrone configureDecoder:codec];
    
    return (success) ? ARCONTROLLER_OK : ARCONTROLLER_ERROR;
}

static eARCONTROLLER_ERROR didReceiveFrameCallback (ARCONTROLLER_Frame_t *frame, void *customData) {
    JSDrone *jsDrone = (__bridge JSDrone*)customData;
    
    BOOL success = [jsDrone.delegate jsDrone:jsDrone didReceiveFrame:frame];
    
    return (success) ? ARCONTROLLER_OK : ARCONTROLLER_ERROR;
}

static eARCONTROLLER_ERROR configAudioDecoderCallback (ARCONTROLLER_Stream_Codec_t codec, void *customData) {
    JSDrone *jsDrone = (__bridge JSDrone*)customData;
    
    BOOL success = [jsDrone.delegate jsDrone:jsDrone configureAudioDecoder:codec];
    
    return (success) ? ARCONTROLLER_OK : ARCONTROLLER_ERROR;
}

static eARCONTROLLER_ERROR didReceiveAudioFrameCallback (ARCONTROLLER_Frame_t *frame, void *customData) {
    JSDrone *jsDrone = (__bridge JSDrone*)customData;

    BOOL success = [jsDrone.delegate jsDrone:jsDrone didReceiveAudioFrame:frame];

    return (success) ? ARCONTROLLER_OK : ARCONTROLLER_ERROR;
}

#pragma mark resolveService
- (BOOL)resolveService:(ARService*)service {
    BOOL retval = NO;
    _resolveSemaphore = dispatch_semaphore_create(0);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoveryDidResolve:) name:kARDiscoveryNotificationServiceResolved object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoveryDidNotResolve:) name:kARDiscoveryNotificationServiceNotResolved object:nil];
    
    [[ARDiscovery sharedInstance] resolveService:service];
    
    // this semaphore will be signaled in discoveryDidResolve or discoveryDidNotResolve
    dispatch_semaphore_wait(_resolveSemaphore, DISPATCH_TIME_FOREVER);
    
    NSString *ip = [[ARDiscovery sharedInstance] convertNSNetServiceToIp:service];
    if (ip != nil)
    {
        retval = YES;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kARDiscoveryNotificationServiceResolved object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kARDiscoveryNotificationServiceNotResolved object:nil];
    _resolveSemaphore = nil;
    return retval;
}

- (void)discoveryDidResolve:(NSNotification *)notification {
    dispatch_semaphore_signal(_resolveSemaphore);
}

- (void)discoveryDidNotResolve:(NSNotification *)notification {
    NSLog(@"Resolve failed");
    dispatch_semaphore_signal(_resolveSemaphore);
}

#pragma mark SDCardModuleDelegate
- (void)sdcardModule:(SDCardModule*)module didFoundMatchingMedias:(NSUInteger)nbMedias {
    [_delegate jsDrone:self didFoundMatchingMedias:nbMedias];
}

- (void)sdcardModule:(SDCardModule*)module media:(NSString*)mediaName downloadDidProgress:(int)progress {
    [_delegate jsDrone:self media:mediaName downloadDidProgress:progress];
}

- (void)sdcardModule:(SDCardModule*)module mediaDownloadDidFinish:(NSString*)mediaName {
    [_delegate jsDrone:self mediaDownloadDidFinish:mediaName];
}

- (void)setAudioStreamEnabledWithInput:(BOOL)input output:(BOOL)output {
    int val = (input ? 1 : 0) | (output ? 2 : 0);

    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        _deviceController->common->sendAudioControllerReadyForStreaming(_deviceController->common, val);
    }
}

- (void)sendAudioStreamFrame:(uint8_t*)data withSize:(size_t)size {
    if (_deviceController && (_connectionState == ARCONTROLLER_DEVICE_STATE_RUNNING)) {
        ARCONTROLLER_Device_SendStreamFrame(_deviceController, data, (int)size);
    }
}

- (BOOL)hasInputAudioStream {
    int res = 0;

    if (_deviceController) {
        res = ARCONTROLLER_Device_HasInputAudioStream(_deviceController, NULL);
    }

    return (res != 0);
}

- (BOOL)hasOutputAudioStream {
    int res = 0;

    if (_deviceController) {
        res = ARCONTROLLER_Device_HasOutputAudioStream(_deviceController, NULL);
    }

    return (res != 0);
}

@end
