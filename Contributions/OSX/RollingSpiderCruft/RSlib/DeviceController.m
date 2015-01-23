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
//  DeviceController.m
//  ARFreeFlight
//
//  Created by Hugo Grostabussiat on 05/12/2013.
//  Copyright (c) 2013 Parrot SA. All rights reserved.
//
#import <libARSAL/ARSAL.h>
#import <libARNetwork/ARNetwork.h>
#import <libARNetworkAL/ARNetworkAL.h>
#import <libARCommands/ARCommands.h>

#import <libARUtils/ARUtils.h>
#import "DeviceControllerProtected.h"
#import "DeviceController+libARCommands.h"

typedef struct ARStreamManager {
  int nothing;
} ARStreamManager;

//#import "ARStreamManager.h"
//#import "ARThread.h"

static const int kDefaultVideoFragmentSize = 1000;
static const int kDefaultVideoFragmentMaximumNumber = 128;

static const char* TAG = "DeviceController";

NSString *const DeviceControllerConnectedProductsKey = @"DeviceControllerConnectedProductsKey";
NSString *const DeviceControllerConnectedProductIdsKey = @"DeviceControllerConnectedProductIdsKey";
NSString *const DeviceControllerConnectedProductSerialsKey = @"DeviceControllerConnectedProductSerialsKey";

NSString *const DeviceControllerProductFirmwaresCheckedKey = @"DeviceControllerProductFirmwaresCheckedKey";
NSString *const DeviceControllerProductFirmwaresIdsKey = @"DeviceControllerProductFirmwaresIdsKey";
NSString *const DeviceControllerProductFirmwaresSerialsKey = @"DeviceControllerProductFirmwaresSerialsKey";


NSString *const DeviceControllerWillStartNotification = @"DeviceControllerWillStartNotification";
NSString *const DeviceControllerDidStartNotification = @"DeviceControllerDidStartNotification";
NSString *const DeviceControllerDidStopNotification = @"DeviceControllerDidStopNotification";
NSString *const DeviceControllerWillStopNotification = @"DeviceControllerWillStopNotification";
NSString *const DeviceControllerDidFailNotification = @"DeviceControllerDidFailNotification";
NSString *const DeviceControllerNotificationsDictionaryChanged = @"DeviceControllerNotificationsDictionaryChanged";
NSString *const DeviceControllerNotificationAllSettingsDidStart = @"DeviceControllerNotificationAllSettingsDidStart";
NSString *const DeviceControllerNotificationAllStatesDidStart = @"DeviceControllerNotificationAllStatesDidStart";

// Metadata sent with each acknowledged command.
typedef struct ARNetworkSendInfo {
    BOOL is_acknowledged; // FIXME: This should not exist but is needed in order to know on which event the NetworkManagerSendInfo data should be free'd.
    eARNETWORK_SEND_POLICY sending_policy;
    void* completionBlock;
    void* device_controller;
} ARNetworkSendInfo;

static eARNETWORK_MANAGER_CALLBACK_RETURN base_network_manager_arnetwork_c_callback(int buffer_id, uint8_t *data, void *custom, eARNETWORK_MANAGER_CALLBACK_STATUS cause);

static eARDISCOVERY_ERROR ARDISCOVERY_Connection_SendJsonCallback (uint8_t *dataTx, uint32_t *dataTxSize, void *customData);
static eARDISCOVERY_ERROR ARDISCOVERY_Connection_ReceiveJsonCallback (uint8_t *dataRx, uint32_t dataRxSize, char *ip, void *customData);

@interface DeviceController ()
@property (atomic, assign) BOOL baseControllerStarted;
@property (atomic, assign) BOOL baseControllerStartCancelled;
@property (atomic, assign) BOOL allowCommands;
@property (nonatomic, retain) ARNetworkConfig *netConfig;
@property (nonatomic, assign) ARNETWORKAL_Manager_t *alManager;
@property (nonatomic, assign) ARNETWORK_Manager_t *netManager;
//@property (nonatomic, retain) ARThread *looperThread;
//@property (nonatomic, retain) ARThread *videoThread;
@property (atomic, retain) NSMutableArray *readerThreads;
@property (nonatomic) dispatch_semaphore_t resolveSemaphore;
@property (nonatomic) dispatch_semaphore_t discoverSemaphore;
@property (nonatomic) ARDISCOVERY_Connection_ConnectionData_t *discoveryData;
@property (nonatomic, strong) NSString *ip;
@property (nonatomic) int discoveryPort;
@property (nonatomic) int c2dPort;
@property (nonatomic) int d2cPort;
@property (nonatomic) int videoFragmentSize;
@property (nonatomic) int maximumNumberOfFragment;
@property (nonatomic) int videoMaxAckInterval;
// Base controller initialization state.
@property (nonatomic) ARSAL_Thread_t rxThread;
@property (nonatomic) ARSAL_Thread_t txThread;
@property (nonatomic) BOOL rxThreadCreated;
@property (nonatomic) BOOL txThreadCreated;
#if ENABLE_ARNETWORKAL_BANDWIDTH_MEASURE
@property (nonatomic) ARSAL_Thread_t bwThread;
@property (nonatomic) BOOL bwThreadCreated;
#endif
@property (nonatomic) BOOL networkInitialized;
// Variables used when sending the final disconnect command.
@property (nonatomic) NSCondition *disconnectSentCondition;
@property (atomic) BOOL disconnectSent;
@end

@implementation DeviceController
@synthesize notificationsDictionary = _notificationsDictionary;
@synthesize privateNotificationsDictionary = _privateNotificationsDictionary;
@synthesize videoStreamDelegate = _videoStreamDelegate;
@synthesize fastReconnection = _fastReconnection;

#pragma mark - Public and protected methods implementations.
- (id)initWithARNetworkConfig:(ARNetworkConfig*)netConfig withARService:(ARService*)service withBridgeDeviceController:(DeviceController *)bridgeDeviceController withLoopInterval:(NSTimeInterval)interval
{
    self = [super init];
    if (self)
    {
        _baseControllerStarted = NO;
        _baseControllerStartCancelled = NO;
        _allowCommands = NO;
        _fastReconnection = NO;
        _netConfig = netConfig;
        _service = service;
        _bridgeDeviceController = bridgeDeviceController;
        _loopInterval = interval;
        _videoFragmentSize = kDefaultVideoFragmentSize;
        _maximumNumberOfFragment = kDefaultVideoFragmentMaximumNumber;
        _videoMaxAckInterval = [netConfig defaultVideoMaxAckInterval];
        _rxThreadCreated = _txThreadCreated = NO;
#if ENABLE_ARNETWORKAL_BANDWIDTH_MEASURE
        _bwThreadCreated = NO;
#endif
        _readerThreads = [[NSMutableArray alloc] init];
        _networkInitialized = NO;
        _disconnectSentCondition = [[NSCondition alloc] init];
        _privateNotificationsDictionary = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (void)dealloc
{
    _privateNotificationsDictionary = nil;
}

- (void)registerCurrentProduct
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if([userDefaults objectForKey:DeviceControllerConnectedProductsKey] == nil)
    {
        [userDefaults setObject:[NSDictionary dictionary] forKey:DeviceControllerConnectedProductsKey];
        [userDefaults synchronize];
    }

    NSDictionary *dictionary = [self notificationsDictionary];
    if(dictionary != nil)
    {
        if(([dictionary objectForKey:DeviceControllerSettingsStateProductSerialHighChangedNotification] != nil) &&
           ([dictionary objectForKey:DeviceControllerSettingsStateProductSerialLowChangedNotification] != nil))
        {
            NSDictionary *settingsStateProductSerialLowChangedNotification = [dictionary objectForKey:DeviceControllerSettingsStateProductSerialLowChangedNotification];
            NSDictionary *settingsStateProductSerialHighChangedNotification = [dictionary objectForKey:DeviceControllerSettingsStateProductSerialHighChangedNotification];
            
            NSString *lowSerial = [settingsStateProductSerialLowChangedNotification objectForKey:DeviceControllerSettingsStateProductSerialLowChangedNotificationLowKey];
            NSString *highSerial = [settingsStateProductSerialHighChangedNotification objectForKey:DeviceControllerSettingsStateProductSerialHighChangedNotificationHighKey];
            NSString *serial = [NSString stringWithFormat:@"%@%@", highSerial, lowSerial];
            NSMutableDictionary *connectedProductsDictionary = [NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)[userDefaults objectForKey:DeviceControllerConnectedProductsKey]];
            if([connectedProductsDictionary objectForKey:serial] == nil)
            {
                [connectedProductsDictionary setObject:[NSDictionary dictionaryWithObjectsAndKeys:serial, DeviceControllerConnectedProductSerialsKey, [NSNumber numberWithInt:ARDISCOVERY_getProductID(_service.product)], DeviceControllerConnectedProductIdsKey, nil] forKey:serial];
                [userDefaults setObject:connectedProductsDictionary forKey:DeviceControllerConnectedProductsKey];
                [userDefaults synchronize];
            }
        }
    }
}

- (eBASE_DEVICE_CONTROLLER_START_RETVAL)startBaseController
{
    BOOL failed = NO;
    
    if (_baseControllerStarted)
    {
        return NO;
    }
    _baseControllerStartCancelled = NO;
    
    if(_baseControllerStartCancelled == NO)
    {
        if(_bridgeDeviceController == nil)
        {
            failed = [self startNetwork];
        }
        //else use bridge
    }
    
    if ((failed == NO) && (_baseControllerStartCancelled == NO) && (_bridgeDeviceController == nil))
    {
        [self startReaderThreads];
    }
    
    if ((failed == NO) && (_baseControllerStartCancelled == NO) && (_bridgeDeviceController == nil))
    {
        [self startVideoThread];
    }
    
    if ((failed == NO) && (_baseControllerStartCancelled == NO))
    {
      //[self startLooperThread];
    }
    
    if(!failed && !_baseControllerStartCancelled)
    {
        [self registerCommonARCommandsCallbacks];
    }
    
    /* Failed to start. Rolling back to a clean state. */
    if (failed || _baseControllerStartCancelled)
    {
        [self stopBaseController];
    }
    else
    {
        _baseControllerStarted = YES;
        _allowCommands = YES;
    }
    
    eBASE_DEVICE_CONTROLLER_START_RETVAL retval = BASE_DEVICE_CONTROLLER_START_RETVAL_OK;
    if (failed)
    {
        retval = BASE_DEVICE_CONTROLLER_START_RETVAL_FAILED;
    }
    else if (_baseControllerStartCancelled)
    {
        retval = BASE_DEVICE_CONTROLLER_START_RETVAL_CANCELLED;
    }
    
    return retval;
}

- (BOOL) startNetwork
{
    eARNETWORK_ERROR netError = ARNETWORK_OK;
    eARNETWORKAL_ERROR netAlError = ARNETWORKAL_OK;
    int pingDelay = 0; // 0 means default, -1 means no ping
    BOOL failed = NO;
    
    // Create the ARNetworkALManager
    _alManager = ARNETWORKAL_Manager_New(&netAlError);
    if (netAlError != ARNETWORKAL_OK)
    {
        ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "ARNETWORKAL_Manager_New() failed.");
        failed = YES;
    }
    
    if ((!failed) && (!_baseControllerStartCancelled))
    {
        if ([_service.service isKindOfClass:[NSNetService class]])
        {
            BOOL resolveSucceeded = [self resolveService];
            if (!resolveSucceeded)
            {
                ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "resolveService failed.");
                failed = YES;
            }
            
            if ((!failed) && (!_baseControllerStartCancelled))
            {
                failed = ![self ardiscoveryConnect];
            }
            
            if ((!failed) && (!_baseControllerStartCancelled))
            {
                [_netConfig initStreamReadIOBuffer:_videoFragmentSize maxNumberOfFragment:_maximumNumberOfFragment];
                
                // Setup ARNetworkAL for Wifi.
                netAlError = ARNETWORKAL_OK;
                if (_ip != nil)
                {
                    netAlError = ARNETWORKAL_Manager_InitWifiNetwork(_alManager, [_ip UTF8String], _c2dPort, _d2cPort, 1);
                }
                
                if ((_ip == nil) || (netAlError != ARNETWORKAL_OK))
                {
                    if (_ip == nil)
                    {
                        ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Unable to resolve name to an IP address.");
                    }
                    else
                    {
                        ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "ARNETWORKAL_Manager_InitWifiNetwork() failed. %s", ARNETWORKAL_Error_ToString(netAlError));
                    }
                    failed = YES;
                }
                else
                {
                    _networkInitialized = YES;
                }
            }
            
        }
        else if ([_service.service isKindOfClass:[ARBLEService class]])
        {
            // Setup ARNetworkAL for BLE.
            ARBLEService* bleService = _service.service;
            netAlError = ARNETWORKAL_Manager_InitBLENetwork(_alManager, (__bridge ARNETWORKAL_BLEDeviceManager_t)(bleService.centralManager), (__bridge ARNETWORKAL_BLEDevice_t)(bleService.peripheral), 1, [_netConfig bleNotificationIDs], [_netConfig numBLENotificationIDs]);
            if (netAlError != ARNETWORKAL_OK)
            {
                ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "ARNETWORKAL_Manager_InitBLENetwork() failed. %s", ARNETWORKAL_Error_ToString(netAlError));
                failed = YES;
            }
            else
            {
                _networkInitialized = YES;
                pingDelay = -1; // Disable ping for BLE networks
            }
        }
        else
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Unknown network media type.");
            failed = YES;
        }
    }
    
#if ENABLE_ARNETWORKAL_BANDWIDTH_MEASURE
    if (!failed && !_baseControllerStartCancelled)
    {
        // Create and start the bandwidth thread for ARNetworkAL
        if (ARSAL_Thread_Create(&_bwThread, ARNETWORKAL_Manager_BandwidthThread, _alManager) != 0)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Creation of Bw thread failed.");
            failed = YES;
        }
        else
        {
            _bwThreadCreated = YES;
        }
    }
#endif
    if (!failed && !_baseControllerStartCancelled)
    {
        // Create the ARNetworkManager.
        _netManager = ARNETWORK_Manager_New(_alManager, _netConfig.numC2dParams, (ARNETWORK_IOBufferParam_t*)_netConfig.c2dParams, _netConfig.numD2cParams, (ARNETWORK_IOBufferParam_t*)_netConfig.d2cParams, pingDelay, onDisconnectNetwork, (__bridge void*)self, &netError);
        if (netError != ARNETWORK_OK)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "ARNETWORK_Manager_New() failed. %s", ARNETWORK_Error_ToString(netError));
            failed = YES;
        } else {
	  NSLog(@"Initialized ARNetwork");
	}
    }
    
    if (!failed && !_baseControllerStartCancelled)
    {
        // Create and start Tx and Rx threads.
        if (ARSAL_Thread_Create(&_rxThread, ARNETWORK_Manager_ReceivingThreadRun, _netManager) != 0)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Creation of Rx thread failed.");
            failed = YES;
        }
        else
        {
            _rxThreadCreated = YES;
        }
        
        if (ARSAL_Thread_Create(&_txThread, ARNETWORK_Manager_SendingThreadRun, _netManager) != 0)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Creation of Tx thread failed.");
            failed = YES;
        }
        else
        {
            _txThreadCreated = YES;
        }
    }
    
    return failed;
}

- (void) startReaderThreads
{
    // Create the reader threads.
    for (int i = 0; i < _netConfig.numCommandsIOBuffers; i ++)
    {
        int bufferId = _netConfig.commandsIOBuffers[i];
        NSNumber* bufferIdNumber = [[NSNumber alloc] initWithInt:bufferId];
        //ARThread* readerThread = [[ARThread alloc] initWithTarget:self selector:@selector(readerThreadRoutine:) object:(id)bufferIdNumber];
        //[_readerThreads addObject:readerThread];
    }
    
    if (!_baseControllerStartCancelled)
    {
        // Start all the reader threads at once.
        [_readerThreads enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop)
         {
             if (!_baseControllerStartCancelled)
             {
	       //ARThread* thread = obj;
	       //[thread start];
             }
         }];
    }
}

- (void) startVideoThread
{
    /* Create an ARStreamManager and create the video thread if target supports video streaming. */
    if ((_netConfig.hasVideo) && !_baseControllerStartCancelled)
    {
        _videoStreamDelegate = nil; // Reset the video delegate to prevent forwarding frames to it before we return from this method.
        //_streamManager = [[ARStreamManager alloc] initWithARNetworkManager:_netManager dataBufferId:_netConfig.videoDataIOBuffer ackBufferId:_netConfig.videoAckIOBuffer fragmentSize:_videoFragmentSize andMaxAckInterval:_videoMaxAckInterval];
        // Create the video thread.
        //_videoThread = [[ARThread alloc] initWithTarget:self selector:@selector(videoThreadRoutine:) object:_streamManager];
    }
    
    if (!_baseControllerStartCancelled)
    {
        // Start the video thread.
        if (_netConfig.hasVideo)
        {
	  //[_videoThread setThreadPriority:1.0];
	  //[_videoThread start];
        }
    }
}

- (void)startLooperThread
{
    // Create the looper thread
  //_looperThread = [[ARThread alloc] initWithTarget:self selector:@selector(looperThreadRoutine:) object:nil];

    if (!_baseControllerStartCancelled)
    {
        // Start the looper thread.
      //        [_looperThread start];
    }
}

- (void)stopBaseController
{
    _baseControllerStarted = NO;
    
    [self unregisterCommonARCommandsCallbacks];
    
    // Cancel the looper thread and block until it is stopped.
    [self stopLooperThread];
    _allowCommands = NO;
    
    // Cancel all reader threads and block until they are all stopped.
    [self stopReaderThreads];
    
    // Cancel the video thre;ad and wait for it to terminate.
    [self stopVideoThread];
    
    
    // ARNetwork cleanup
    [self stopNetwork];
}

- (void)stopLooperThread
{
    // Cancel the looper thread and block until it is stopped.
  //if([_looperThread isRunning])
  //{
  //[_looperThread stop];
  //[_looperThread join];
  //}
}

- (void)stopReaderThreads
{
    // Cancel all reader threads and block until they are all stopped.
    [_readerThreads enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        //ARThread* thread = obj;
        //if([thread isRunning])
        //{
	  //[thread stop];
	//[thread join];
	//}
    }];
    [_readerThreads removeAllObjects];
}

- (void)stopVideoThread
{
    // Cancel the video thread and wait for it to terminate.
    if (_netConfig.hasVideo)
    {
      //if([_videoThread isRunning])
      //{
      //[_videoThread stop];
      //[_videoThread join];
      //}
    }
    
    // Stop the video streamer.
    //if (_streamManager != nil)
    //{
      //[_streamManager stopStream];
      //_streamManager = nil;
    //}
}

- (void) stopNetwork
{
    // ARNetwork cleanup
    if (_netManager != NULL)
    {
        ARNETWORK_Manager_Stop(_netManager);
        if (_rxThreadCreated)
        {
            ARSAL_Thread_Join(_rxThread, NULL);
            ARSAL_Thread_Destroy(&_rxThread);
        }
        
        if (_txThreadCreated)
        {
            ARSAL_Thread_Join(_txThread, NULL);
            ARSAL_Thread_Destroy(&_txThread);
        }
    }
    if (_networkInitialized && _alManager != NULL)
    {
        ARNETWORKAL_Manager_Unlock(_alManager);
        if ([_service.service isKindOfClass:[NSNetService class]])
        {
            ARNETWORKAL_Manager_CloseWifiNetwork(_alManager);
        }
        else if ([_service.service isKindOfClass:[ARBLEService class]])
        {
            ARNETWORKAL_Manager_CloseBLENetwork(_alManager);
        }
    }
    
#if ENABLE_ARNETWORKAL_BANDWIDTH_MEASURE
    if (_alManager != NULL)
    {
        if (_bwThreadCreated)
        {
            ARSAL_Thread_Join(_bwThread, NULL);
            ARSAL_Thread_Destroy(&_bwThread);
        }
    }
#endif
    
    _networkInitialized = NO;
    _txThreadCreated = NO;
    _rxThreadCreated = NO;
    ARNETWORK_Manager_Delete(&_netManager);
    ARNETWORKAL_Manager_Delete(&_alManager);
}

- (void) setVideoStreamDelegate:(id<DeviceControllerVideoStreamDelegate>)videoStreamDelegate
{
    if(_bridgeDeviceController != nil)
    {
        [_bridgeDeviceController setVideoStreamDelegate:videoStreamDelegate];
    }
    else
    {
        _videoStreamDelegate = videoStreamDelegate;
    }
}

- (void)cancelBaseControllerStart
{
    if (!_baseControllerStartCancelled)
    {
        _baseControllerStartCancelled = YES;
        
        if ([_service.service isKindOfClass:[NSNetService class]])
        {
            if(_discoveryData != NULL)
            {
                ARDISCOVERY_Connection_ControllerConnectionAbort(_discoveryData);
            }
            
            ARNETWORKAL_Manager_CancelWifiNetwork (_alManager);
        }
        else if ([_service.service isKindOfClass:[ARBLEService class]])
        {
            ARNETWORKAL_Manager_CancelBLENetwork (_alManager);
        }
        else
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Unknown network media type.");
        }
    }
}

- (BOOL)sendData:(void *)data withSize:(size_t)size onBufferWithId:(int)bufferId withSendPolicy:(eARNETWORK_SEND_POLICY)policy withCompletionBlock:(DeviceControllerCompletionBlock)completion
{
    if (!_allowCommands)
    {
        ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Cannot send data: Base controller is not started.");
        return NO;
    }
    
    BOOL retval = YES;
    
    if(_bridgeDeviceController != nil)
    {
        retval = [_bridgeDeviceController sendData:data withSize:size onBufferWithId:bufferId withSendPolicy:policy withCompletionBlock:completion];
    }
    else
    {
    
        // Prepare metadata.
        ARNetworkSendInfo* sendInfo = malloc(sizeof(ARNetworkSendInfo));
        if (sendInfo == NULL)
        {
            retval = NO;
        }
        
        /* FIXME: Temporary workaround to know the sendInfo struct should be free'd. */
        int i;
        for (i = 0; i < _netConfig.numC2dParams && retval != NO; i ++)
        {
            if (_netConfig.c2dParams[i].ID == bufferId)
            {
                sendInfo->is_acknowledged = (_netConfig.c2dParams[i].dataType == ARNETWORKAL_FRAME_TYPE_DATA_WITH_ACK) ? YES : NO;
                break;
            }
            if (i >= _netConfig.numC2dParams)
            {
                NSLog(@"Error: Invalid ARNetwork buffer ID.");
                abort(); // Fail miserably.
            }
        }
        
        if (retval == YES)
        {
            sendInfo->device_controller = (__bridge void*)self;
            sendInfo->sending_policy = policy;
            sendInfo->completionBlock = (__bridge void*)completion;
        }
        
        // Send data with ARNetwork.
        if (retval == YES)
        {
            eARNETWORK_ERROR netError = ARNETWORK_Manager_SendData(_netManager, bufferId, (uint8_t*)data, size, sendInfo, base_network_manager_arnetwork_c_callback, 1);
            if (netError != ARNETWORK_OK)
            {
                ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "ARNETWORK_Manager_SendData() failed. %s", ARNETWORK_Error_ToString(netError));
                retval = NO;
            }
        }
        
        if (retval == NO)
        {
            free(sendInfo);
            sendInfo = NULL;
        }
    }
    
    return retval;
}

- (BOOL)getBandwidthForUpload:(uint32_t *)upload andDownload:(uint32_t *)download
{
    eARNETWORKAL_ERROR err = ARNETWORKAL_Manager_GetBandwidth(_alManager, upload, download);
    return (err == ARNETWORKAL_OK);
}


#pragma mark -- Abstract methods.

- (void)controllerLoop
{
    //AbstractMethodRaiseException;
}

- (void)start
{
    //AbstractMethodRaiseException;
}

- (void)stop
{
    //AbstractMethodRaiseException;
}

- (void)pause:(BOOL)pause
{
    //AbstractMethodRaiseException;
}

- (eDEVICE_CONTROLLER_STATE)state
{
    //AbstractMethodRaiseException;
    return DEVICE_CONTROLLER_STATE_STOPPED;
}

- (void)userRequestedReboot
{
    //AbstractMethodRaiseException;
}

- (void)userRequestedSettingsReset
{
    //AbstractMethodRaiseException;
}

- (void)userRequestAutoCountry:(int)automatic
{
    //AbstractMethodRaiseException;
}

- (void)userEnteredPilotingHud:(BOOL)inHud
{
    //AbstractMethodRaiseException;
}

- (void)userRequestedOutdoorWifi:(BOOL)outdoor
{
    uint8_t outdoorInt = (outdoor) ? 1 : 0;
    //[self DeviceController_SendWifiSettingsOutdoorSetting:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withOutdoor:outdoorInt];
}

- (void)userRequestMavlinkPlay:(NSString *)filename type:(eARCOMMANDS_COMMON_MAVLINK_START_TYPE)type
{
    char* filenameChar = strdup([filename UTF8String]);
    //[self DeviceController_SendMavlinkStart:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withFilepath:filenameChar withType:type];
}

- (void)userRequestMavlinkPause
{
  //[self DeviceController_SendMavlinkPause:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestMavlinkStop
{
  //[self DeviceController_SendMavlinkStop:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil];
}

- (void)userRequestedCalibrate:(BOOL)startProcess
{
    uint8_t calibrate = (startProcess) ? 1 : 0;
    //[self DeviceController_SendCalibrationMagnetoCalibration:[ARDrone3ARNetworkConfig c2dAckId] withSendPolicy:ARNETWORK_SEND_POLICY_DROP withCompletionBlock:nil withCalibrate:calibrate];
}

#pragma mark - Thread routines.

- (void)videoThreadRoutine:(ARStreamManager*)streamManager
{
  //[streamManager startStream];
    
    while (![NSThread currentThread].isCancelled)
    {
        /* We need the autorelease pool here to prevent a memory leak in the
         * video delegate.
         * TODO: This is kinda old code. Make sure it is still needed. */
        @autoreleasepool
        {
	  ARFrame* frame = nil;//[streamManager getFrameWithTimeout:500];
            if (frame != nil)
            {
                if (_videoStreamDelegate != nil && [_videoStreamDelegate respondsToSelector:@selector(didReceiveFrame:)])
                {
                    [_videoStreamDelegate didReceiveFrame:frame];
                }
                //[streamManager freeFrame:frame];
            }
            else
            {
                if (_videoStreamDelegate != nil && [_videoStreamDelegate respondsToSelector:@selector(didTimedOutReceivingFrame)])
                {
                    [_videoStreamDelegate didTimedOutReceivingFrame];
                }
            }
        }
    }
    
    //[streamManager stopStream];
}

- (void)looperThreadRoutine:(id)userData
{
    NSTimeInterval lastInterval = [NSDate timeIntervalSinceReferenceDate];
    
    while (![NSThread currentThread].isCancelled)
    {
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceReferenceDate:lastInterval + _loopInterval]];
        lastInterval = [NSDate timeIntervalSinceReferenceDate];
        
        [self controllerLoop];
    }
}

- (void)readerThreadRoutine:(NSNumber*)bufferIdNumber
{
    int bufferId = bufferIdNumber.intValue;
    BOOL failed = FALSE;
    
    // Allocate some space for incoming data.
    const size_t maxLength = 128 * 1024;
    void* data = malloc(maxLength);
    if (data == NULL)
    {
        ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "malloc() failed.");
        failed = YES;
    }
    
    while ([NSThread currentThread].isCancelled == NO && failed == NO)
    {
        BOOL skip = NO;
        eARNETWORK_ERROR netError = ARNETWORK_OK;
        int length;
        
        // Read data
        netError = ARNETWORK_Manager_ReadDataWithTimeout(_netManager, bufferId, data, maxLength, &length, 1000);
        if (netError != ARNETWORK_OK)
        {
            if (netError != ARNETWORK_ERROR_BUFFER_EMPTY)
            {
                ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "ARNETWORK_Manager_ReadDataWithTimeout() failed. %s", ARNETWORK_Error_ToString(netError));
            }
            skip = YES;
        }
        
        if (skip == NO && failed == NO)
        {
            // Forward data to the CommandsManager
            @synchronized(self)
            {
                eARCOMMANDS_DECODER_ERROR cmdError = ARCOMMANDS_DECODER_OK;
                cmdError = ARCOMMANDS_Decoder_DecodeBuffer((uint8_t*)data, length);
                if (cmdError != ARCOMMANDS_DECODER_OK && cmdError != ARCOMMANDS_DECODER_ERROR_NO_CALLBACK)
                {
                    char msg[128];
                    ARCOMMANDS_Decoder_DescribeBuffer((uint8_t*)data, length, msg, sizeof(msg));
                    ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "ARCOMMANDS_Decoder_DecodeBuffer() failed. %d, %s", cmdError, msg);
                }
            }
        }
    }
    
    free(data);
}

#pragma mark - Discovery private methods.

- (void)discoveryDidResolve:(NSNotification *)notification
{
    _service = (ARService *)[[notification userInfo] objectForKey:kARDiscoveryServiceResolved];
    dispatch_semaphore_signal(_resolveSemaphore);
}

- (void)discoveryDidNotResolve:(NSNotification *)notification
{
    _service = nil;
    dispatch_semaphore_signal(_resolveSemaphore);
}

- (BOOL)resolveService
{
    BOOL retval = NO;
    _resolveSemaphore = dispatch_semaphore_create(0);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoveryDidResolve:) name:kARDiscoveryNotificationServiceResolved object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoveryDidNotResolve:) name:kARDiscoveryNotificationServiceNotResolved object:nil];
    
    [[ARDiscovery sharedInstance] resolveService:_service];
    
    dispatch_semaphore_wait(_resolveSemaphore, dispatch_time(DISPATCH_TIME_NOW, 10000000000));
    
    if (_service)
    {
        _ip = [[ARDiscovery sharedInstance] convertNSNetServiceToIp:_service];
        if (_ip != nil)
        {
            _discoveryPort = [(NSNetService *)_service.service port];
            retval = YES;
        }
    }

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kARDiscoveryNotificationServiceResolved object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kARDiscoveryNotificationServiceNotResolved object:nil];
    _resolveSemaphore = nil;
    return retval;
}

- (BOOL)ardiscoveryConnect
{
    _discoverSemaphore = dispatch_semaphore_create(0);

    BOOL ok = YES;

    _d2cPort = _netConfig.inboundPort;

    eARDISCOVERY_ERROR err = ARDISCOVERY_OK;
    _discoveryData = ARDISCOVERY_Connection_New (ARDISCOVERY_Connection_SendJsonCallback, ARDISCOVERY_Connection_ReceiveJsonCallback, (__bridge void *)self, &err);
    if (_discoveryData == NULL || err != ARDISCOVERY_OK)
    {
        ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Error while creating discoveryData : %s", ARDISCOVERY_Error_ToString(err));
        ok = NO;
    }

    if (ok)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            eARDISCOVERY_ERROR err = ARDISCOVERY_Connection_ControllerConnection(_discoveryData, _discoveryPort, [_ip UTF8String]);
            if (err != ARDISCOVERY_OK)
            {
                ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Error while opening discovery connection : %s", ARDISCOVERY_Error_ToString(err));
            }
            
            dispatch_semaphore_signal(_discoverSemaphore);
        });
    }

    if (ok)
    {
        dispatch_semaphore_wait(_discoverSemaphore, DISPATCH_TIME_FOREVER);
    }
    
    ARDISCOVERY_Connection_Delete(&_discoveryData);
    _discoverSemaphore = nil;
    
    return (err == ARDISCOVERY_OK);
}

- (void)ARDiscoveryDidReceiveResponse:(NSString *)json
{
    NSError *err;
    id jsonobj = nil;
    
    if (json != nil)
    {
        jsonobj = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:&err];
    }
    else
    {
        NSLog(@"error json = nil");
    }
    
    NSDictionary *jsonDict = (NSDictionary *)jsonobj;
    NSNumber *c2dPortData = [jsonDict objectForKey:[NSString stringWithCString:ARDISCOVERY_CONNECTION_JSON_C2DPORT_KEY encoding:NSUTF8StringEncoding]];
    _c2dPort = c2dPortData.intValue;
    NSNumber *videoFragmentSizeData = [jsonDict objectForKey:[NSString stringWithCString:ARDISCOVERY_CONNECTION_JSON_ARSTREAM_FRAGMENT_SIZE_KEY encoding:NSUTF8StringEncoding]];
    if (videoFragmentSizeData != nil)
    {
        _videoFragmentSize = videoFragmentSizeData.intValue;
    } // Else leave it to the default value.
    
    NSNumber *maximumNumberOfFragment = [jsonDict objectForKey:[NSString stringWithCString:ARDISCOVERY_CONNECTION_JSON_ARSTREAM_FRAGMENT_MAXIMUM_NUMBER_KEY encoding:NSUTF8StringEncoding]];
    if (maximumNumberOfFragment != nil)
    {
        _maximumNumberOfFragment = maximumNumberOfFragment.intValue;
    } // Else leave it to the default value.
    
    NSNumber *maxAckIntervalNumber = [jsonDict objectForKey:[NSString stringWithCString:ARDISCOVERY_CONNECTION_JSON_ARSTREAM_MAX_ACK_INTERVAL_KEY encoding:NSUTF8StringEncoding]];
    if (maxAckIntervalNumber != nil)
    {
        _videoMaxAckInterval = maxAckIntervalNumber.intValue;
    } // Else use the default value from the network config for the device.
    
    NSString *skyControllerVersionNumber = [jsonDict objectForKey:[NSString stringWithCString:ARDISCOVERY_CONNECTION_JSON_SKYCONTROLLER_VERSION encoding:NSUTF8StringEncoding]];
    if (maxAckIntervalNumber != nil)
    {
        _skyControllerSoftVersion = skyControllerVersionNumber;
    } // Else use the default value
}

#pragma mark - Commands-sending methods.
- (void)networkDidSendFrame:(DeviceControllerCompletionBlock)completion
{

}

- (void)networkDidReceiveAck:(DeviceControllerCompletionBlock)completion
{
    if(completion != nil)
        completion();
}

- (void)networkTimeoutOccurred:(DeviceControllerCompletionBlock)completion
{
}

- (void)networkDidCancelFrame:(DeviceControllerCompletionBlock)completion
{
    if(completion != nil)
        completion();
}

- (NSMutableDictionary *)notificationsDictionary
{
    return [_privateNotificationsDictionary copy];
}

/**
 * @brief fuction called on disconnect
 * @param manager The manager
 */
void onDisconnectNetwork (ARNETWORK_Manager_t *manager, ARNETWORKAL_Manager_t *alManager, void *customData)
{
    NSLog(@"onDisconnectNetwork ...");
        
    if (customData != NULL)
    {
        DeviceController *dc = (__bridge DeviceController*)customData;
    
        [dc stop];
    }
}

@end

#pragma mark -- ARNetwork callback
/* The C part of the ARNetwork callback */
static eARNETWORK_MANAGER_CALLBACK_RETURN base_network_manager_arnetwork_c_callback(int buffer_id, uint8_t *data, void *custom, eARNETWORK_MANAGER_CALLBACK_STATUS cause)
{
    int retval = ARNETWORK_MANAGER_CALLBACK_RETURN_DEFAULT;
    ARNetworkSendInfo* sendInfo = (ARNetworkSendInfo*)custom;
    DeviceController* dc = nil;
    
    /* get device_controller */
    if (sendInfo != NULL)
    {
        dc = (__bridge DeviceController*)sendInfo->device_controller;
    }
    
    switch (cause)
    {
        case ARNETWORK_MANAGER_CALLBACK_STATUS_SENT:
            /* Send notification if requested to. */
            if (sendInfo->device_controller != NULL)
            {
                id<ARNetworkSendStatusDelegate> delegate = nil;
                delegate = (__bridge id<ARNetworkSendStatusDelegate>)sendInfo->device_controller;
                if ([delegate respondsToSelector:@selector(networkDidSendFrame:)])
                {
                    [delegate networkDidSendFrame:(__bridge void (^)(void))sendInfo->completionBlock];
                }
            }
            break;
            
        case ARNETWORK_MANAGER_CALLBACK_STATUS_ACK_RECEIVED:
#ifdef DEBUG
            assert(sendInfo->is_acknowledged == YES);
#endif //DEBUG
            /* Send notification if requested to. */
            if (sendInfo->device_controller != NULL)
            {
                id<ARNetworkSendStatusDelegate> delegate = nil;
                delegate = (__bridge id<ARNetworkSendStatusDelegate>)sendInfo->device_controller;
                if ([delegate respondsToSelector:@selector(networkDidReceiveAck:)])
                {
                    [delegate networkDidReceiveAck:(__bridge void (^)(void))sendInfo->completionBlock];
                }
            }
            break;
            
        case ARNETWORK_MANAGER_CALLBACK_STATUS_TIMEOUT:
#ifdef DEBUG
            assert(sendInfo->is_acknowledged == YES);
#endif
            /* Send notification if requested. */
            if (sendInfo->device_controller != NULL)
            {
                id<ARNetworkSendStatusDelegate> delegate = nil;
                delegate = (__bridge id<ARNetworkSendStatusDelegate>)sendInfo->device_controller;
                if ([delegate respondsToSelector:@selector(networkTimeoutOccurred:)])
                {
                    [delegate networkTimeoutOccurred:(__bridge void (^)(void))sendInfo->completionBlock];
                }
            }
            
            /* Apply sending policy. */
            switch (sendInfo->sending_policy)
            {
                case ARNETWORK_SEND_POLICY_DROP:
                    retval = ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP;
                    break;
                    
                case ARNETWORK_SEND_POLICY_RETRY:
                    retval = ARNETWORK_MANAGER_CALLBACK_RETURN_RETRY;
                    break;
                    
                case ARNETWORK_SEND_POLICY_FLUSH:
                    retval = ARNETWORK_MANAGER_CALLBACK_RETURN_FLUSH; // FIXME: Check this works as intended (= flush this and only this buffer).
                    break;
                    
                default:
                    break;
            }
            break;
            
        case ARNETWORK_MANAGER_CALLBACK_STATUS_CANCEL:
            /* Send notification if requested to. */
            if (sendInfo->device_controller != NULL)
            {
                id<ARNetworkSendStatusDelegate> delegate = nil;
                delegate = (__bridge id<ARNetworkSendStatusDelegate>)sendInfo->device_controller;
                if ([delegate respondsToSelector:@selector(networkDidCancelFrame:)])
                {
                    [delegate networkDidCancelFrame:(__bridge void (^)(void))sendInfo->completionBlock];
                }
            }
            break;
            
        case ARNETWORK_MANAGER_CALLBACK_STATUS_DONE:
            
            /* Free the metadata */
            free(sendInfo);
            sendInfo = NULL;
            break;
            
        case ARNETWORK_MANAGER_CALLBACK_STATUS_FREE: // Case already handled at the beginning.
            free(data);
            
            break;
        default:
            
            break;
    }
    
    return retval;
}

static eARDISCOVERY_ERROR ARDISCOVERY_Connection_SendJsonCallback (uint8_t *dataTx, uint32_t *dataTxSize, void *customData)
{
    DeviceController *deviceController = (__bridge DeviceController *)customData;
    eARDISCOVERY_ERROR err = ARDISCOVERY_OK;
    
    if (dataTx != NULL && dataTxSize != NULL)
    {
        NSString *controllerName = [[NSBundle mainBundle] bundleIdentifier];
        NSString *controllerType = @"fett";//[[UIDevice currentDevice] localizedModel];
        *dataTxSize = sprintf((char *)dataTx, "{ \"%s\": %d,\n \"%s\": \"%s\",\n \"%s\": \"%s\" }",
                             ARDISCOVERY_CONNECTION_JSON_D2CPORT_KEY, deviceController.netConfig.inboundPort,
                             ARDISCOVERY_CONNECTION_JSON_CONTROLLER_NAME_KEY, [controllerName cStringUsingEncoding:NSUTF8StringEncoding],
                             ARDISCOVERY_CONNECTION_JSON_CONTROLLER_TYPE_KEY, [controllerType cStringUsingEncoding:NSUTF8StringEncoding]) + 1;
    }
    else
    {
        err = ARDISCOVERY_ERROR;
    }
    
    return err;
}

static eARDISCOVERY_ERROR ARDISCOVERY_Connection_ReceiveJsonCallback (uint8_t *dataRx, uint32_t dataRxSize, char *ip, void *customData)
{
    DeviceController *deviceController = (__bridge DeviceController *)customData;
    eARDISCOVERY_ERROR err = ARDISCOVERY_OK;
    
    if (dataRx != NULL && dataRxSize != 0)
    {
        char *json = malloc(dataRxSize + 1);
        strncpy(json, (char *)dataRx, dataRxSize);
        json[dataRxSize] = '\0';
        
        NSString *strResponse = [NSString stringWithCString:(const char *)json encoding:NSUTF8StringEncoding];
        free(json);
        
        [deviceController ARDiscoveryDidReceiveResponse:strResponse];
        
    }
    else
    {
        err = ARDISCOVERY_ERROR;
    }
    
    return err;
}
