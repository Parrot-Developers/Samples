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
//  RollingSpiderPiloting
//
//  Created by  20/01/2015.
//  Copyright (c) 2015 Parrot. All rights reserved.
//

#import "DeviceController.h"

#import <libARSAL/ARSAL.h>
#import <libARNetwork/ARNetwork.h>
#import <libARNetworkAL/ARNetworkAL.h>
#import <libARCommands/ARCommands.h>

static const char* TAG = "DeviceController";

static const int RS_NET_C2D_NONACK = 10;
static const int RS_NET_C2D_ACK = 11;
static const int RS_NET_C2D_EMERGENCY = 12;
static const int RS_NET_D2C_NAVDATA = (ARNETWORKAL_MANAGER_BLE_ID_MAX / 2) - 1;
static const int RS_NET_D2C_EVENTS = (ARNETWORKAL_MANAGER_BLE_ID_MAX / 2) - 2;

static int BLE_NOTIFICATION_IDS[] = {
    RS_NET_D2C_NAVDATA,
    RS_NET_D2C_EVENTS,
    (RS_NET_C2D_ACK + (ARNETWORKAL_MANAGER_BLE_ID_MAX / 2)),
    (RS_NET_C2D_EMERGENCY + (ARNETWORKAL_MANAGER_BLE_ID_MAX / 2)),
};
static const size_t NB_OF_BLE_NOTIFICATION_IDS = sizeof(BLE_NOTIFICATION_IDS) / sizeof(int);

static ARNETWORK_IOBufferParam_t C2D_PARAMS[] = {
    {
        .ID = RS_NET_C2D_NONACK,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA,
        .sendingWaitTimeMs = 20,
        .ackTimeoutMs = -1,
        .numberOfRetry = -1,
        .numberOfCell = 1,
        .dataCopyMaxSize = ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
        .isOverwriting = 1,
    },
    {
        .ID = RS_NET_C2D_ACK,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA_WITH_ACK,
        .sendingWaitTimeMs = 20,
        .ackTimeoutMs = 500,
        .numberOfRetry = 3,
        .numberOfCell = 20,
        .dataCopyMaxSize = ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
        .isOverwriting = 0,
    },
    {
        .ID = RS_NET_C2D_EMERGENCY,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA_WITH_ACK,
        .sendingWaitTimeMs = 1,
        .ackTimeoutMs = 100,
        .numberOfRetry = ARNETWORK_IOBUFFERPARAM_INFINITE_NUMBER,
        .numberOfCell = 1,
        .dataCopyMaxSize = ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
        .isOverwriting = 0,
    }
};
static const size_t NUM_OF_C2D_PARAMS = sizeof(C2D_PARAMS) / sizeof(ARNETWORK_IOBufferParam_t);

static ARNETWORK_IOBufferParam_t D2C_PARAMS[] = {
    {
        .ID = RS_NET_D2C_NAVDATA,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA,
        .sendingWaitTimeMs = 20,
        .ackTimeoutMs = -1,
        .numberOfRetry = -1,
        .numberOfCell = 20,
        .dataCopyMaxSize = ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
        .isOverwriting = 0,
    },
    {
        .ID = RS_NET_D2C_EVENTS,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA_WITH_ACK,
        .sendingWaitTimeMs = 20,
        .ackTimeoutMs = 500,
        .numberOfRetry = 3,
        .numberOfCell = 20,
        .dataCopyMaxSize = ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
        .isOverwriting = 0,
    }
};
static const size_t NUM_OF_D2C_PARAMS = sizeof(D2C_PARAMS) / sizeof(ARNETWORK_IOBufferParam_t);

static int COMMAND_BUFFER_IDS[] = {
    RS_NET_D2C_NAVDATA,
    RS_NET_D2C_EVENTS,
};
static const size_t NUM_OF_COMMANDS_BUFFER_IDS = sizeof(COMMAND_BUFFER_IDS) / sizeof(int);

@interface DeviceController ()

@property (nonatomic, assign) ARNETWORKAL_Manager_t *alManager;
@property (nonatomic, assign) ARNETWORK_Manager_t *netManager;
@property (nonatomic) ARSAL_Thread_t rxThread;
@property (nonatomic) ARSAL_Thread_t txThread;
@property (nonatomic) int c2dPort;
@property (nonatomic) int d2cPort;

@property (nonatomic) ARSAL_Thread_t looperThread;
@property (nonatomic) ARSAL_Thread_t *readerThreads;
@property (nonatomic) READER_THREAD_DATA_t *readerThreadsData;

@property (nonatomic) BOOL run;
@property (nonatomic) BOOL alManagerInitialized;

@property (nonatomic) RS_PCMD_t dataPCMD;

@end

@implementation DeviceController

- (id)init
{
    self = [super init];
    if (self)
    {
        _service = nil;
        _peripheral = nil;
        
        // initialize deviceManager
        _alManager = NULL;
        _netManager = NULL;
        _rxThread = NULL;
        _txThread = NULL;
        
        _looperThread = NULL;
        _readerThreads = NULL;
        _readerThreadsData = NULL;
        
        _run = YES;
        _alManagerInitialized = NO;
        
        _dataPCMD.flag = 0;
        _dataPCMD.roll = 0;
        _dataPCMD.pitch = 0;
        _dataPCMD.yaw = 0;
        _dataPCMD.gaz = 0;
        _dataPCMD.psi = 0;

        [[NSNotificationCenter defaultCenter]
          addObserver:self
          selector:@selector(receiveDroneNotification:)
          name:kARDiscoveryNotificationServicesDevicesListUpdated
          object:nil];

	_ARD = [ARDiscovery sharedInstance];
        [_ARD start]; //Start discovery

	NSLog(@"Searching for a Rolling Spider...");
    }
   
    return self;
}

- (void)dealloc
{

}

- (void) receiveDroneNotification:(NSNotification *)notification
{
  ARDiscovery *ARD = notification.object;
  
  for (ARService *obj in [ARD getCurrentListOfDevicesServices]) {
    NSLog(@"Found Something!");
    if ([obj.service isKindOfClass:[ARBLEService class]]) {
      ARBLEService *serviceIdx = (ARBLEService *)obj.service;
      NSLog(@"Found %@", serviceIdx.peripheral.name);

      if(ARDISCOVERY_getProductID(obj.product) == ARDISCOVERY_getProductID(ARDISCOVERY_PRODUCT_MINIDRONE)) {
	NSLog(@"Device is a Rolling Spider");
	_service = obj;
	_peripheral = ((ARBLEService *) _service.service).peripheral;

	[[NSNotificationCenter defaultCenter] removeObserver:self];	
	[ARD stop];
	break;
      }
    }
  }
}

- (BOOL)start
{
    ARBLEService *serviceIdx = (ARBLEService *)_service.service;
    NSLog(@"Connecting to Rolling Spider %@...", serviceIdx.peripheral.name);
    
    BOOL failed = NO;
    
    [self registerARCommandsCallbacks];
    
    failed = [self startNetwork];
    
    if (!failed)
    {
        // Create and start looper thread.
        if (ARSAL_Thread_Create(&(_looperThread), looperRun, (__bridge void *)self) != 0)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Creation of looper thread failed.");
            failed = YES;
        }
    }
    
    if (!failed)
    {
        // allocate reader thread array.
        _readerThreads = calloc(NUM_OF_COMMANDS_BUFFER_IDS, sizeof(ARSAL_Thread_t));
        
        if (_readerThreads == NULL)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Allocation of reader threads failed.");
            failed = YES;
        }
    }
    
    if (!failed)
    {
        // allocate reader thread data array.
        _readerThreadsData = calloc(NUM_OF_COMMANDS_BUFFER_IDS, sizeof(READER_THREAD_DATA_t));
        
        if (_readerThreadsData == NULL)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Allocation of reader threads data failed.");
            failed = YES;
        }
    }
    
    if (!failed)
    {
        // Create and start reader threads.
        int readerThreadIndex = 0;
        for (readerThreadIndex = 0 ; readerThreadIndex < NUM_OF_COMMANDS_BUFFER_IDS ; readerThreadIndex++)
        {
            // initialize reader thread data
            _readerThreadsData[readerThreadIndex].deviceController = (__bridge void *)self;
            _readerThreadsData[readerThreadIndex].readerBufferId = COMMAND_BUFFER_IDS[readerThreadIndex];
            
            if (ARSAL_Thread_Create(&(_readerThreads[readerThreadIndex]), readerRun, &(_readerThreadsData[readerThreadIndex])) != 0)
            {
                ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Creation of reader thread failed.");
                failed = YES;
            }
        }
    }
    
    return failed;
}

- (BOOL)startNetwork
{
    BOOL failed = NO;
    eARNETWORK_ERROR netError = ARNETWORK_OK;
    eARNETWORKAL_ERROR netAlError = ARNETWORKAL_OK;
    int pingDelay = 0; // 0 means default, -1 means no ping
    
    ARSAL_PRINT(ARSAL_PRINT_INFO, TAG, "- Start ARNetwork");
    
    // Create the ARNetworkALManager
    _alManager = ARNETWORKAL_Manager_New(&netAlError);
    if (netAlError != ARNETWORKAL_OK)
    {
        failed = YES;
    }
    
    if (!failed)
    {
      if ([_service.service isKindOfClass:[ARBLEService class]]) {
	// Setup ARNetworkAL for BLE.
	ARBLEService* bleService = _service.service;
        netAlError = ARNETWORKAL_Manager_InitBLENetwork(_alManager, (__bridge ARNETWORKAL_BLEDeviceManager_t)(bleService.centralManager), (__bridge ARNETWORKAL_BLEDevice_t)(bleService.peripheral), 1, BLE_NOTIFICATION_IDS,NB_OF_BLE_NOTIFICATION_IDS);
        if (netAlError != ARNETWORKAL_OK)
	  {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "ARNETWORKAL_Manager_InitBLENetwork() failed. %s", ARNETWORKAL_Error_ToString(netAlError));
            failed = YES;
	  }
        else
	  {
            _alManagerInitialized = YES;
            pingDelay = -1; // Disable ping for BLE networks
	  }
      } else {
	failed = YES;
      }
    }

    if (!failed)
    {
        // Create the ARNetworkManager.
        _netManager = ARNETWORK_Manager_New(_alManager, NUM_OF_C2D_PARAMS, C2D_PARAMS, NUM_OF_D2C_PARAMS, D2C_PARAMS, pingDelay, onDisconnectNetwork, (__bridge void *)self, &netError);
        if (netError != ARNETWORK_OK)
        {
            failed = YES;
        }
    }
    
    if (!failed)
    {
        // Create and start Tx and Rx threads.
        if (ARSAL_Thread_Create(&(_rxThread), ARNETWORK_Manager_ReceivingThreadRun, _netManager) != 0)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Creation of Rx thread failed.");
            failed = YES;
        }
        
        if (ARSAL_Thread_Create(&(_txThread), ARNETWORK_Manager_SendingThreadRun, _netManager) != 0)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "Creation of Tx thread failed.");
            failed = YES;
        }
    }
    
    // Print net error
    if (failed)
    {
        if (netAlError != ARNETWORKAL_OK)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "ARNetWorkAL Error : %s", ARNETWORKAL_Error_ToString(netAlError));
        }
        
        if (netError != ARNETWORK_OK)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "ARNetWork Error : %s", ARNETWORK_Error_ToString(netError));
        }
    } else {
      //Send date and time, necessary for reconnect
      NSLog(@"Sending Current Date");
      [self sendCurrentDate];
      NSLog(@"Sending Current Time");
      [self sendCurrentTime];
    }
    
    return failed;
}

- (void)stop
{
    NSLog(@"stop ...");
    
    _run = NO; // break threads loops
    
    [self unregisterARCommandsCallbacks];
    
    // Stop looper Thread
    if (_looperThread != NULL)
    {
        ARSAL_Thread_Join(_looperThread, NULL);
        ARSAL_Thread_Destroy(&(_looperThread));
        _looperThread = NULL;
    }
    
    if (_readerThreads != NULL)
    {
        // Stop reader Threads
        int readerThreadIndex = 0;
        for (readerThreadIndex = 0 ; readerThreadIndex < NUM_OF_D2C_PARAMS ; readerThreadIndex++)
        {
            if (_readerThreads[readerThreadIndex] != NULL)
            {
                ARSAL_Thread_Join(_readerThreads[readerThreadIndex], NULL);
                ARSAL_Thread_Destroy(&(_readerThreads[readerThreadIndex]));
                _readerThreads[readerThreadIndex] = NULL;
            }
        }
        
        // free reader thread array
        free (_readerThreads);
        _readerThreads = NULL;
    }
    
    if (_readerThreadsData != NULL)
    {
        // free reader thread data array
        free (_readerThreadsData);
        _readerThreadsData = NULL;
    }
    
    // Stop Network
    [self stopNetwork];
}

- (void)stopNetwork
{
    ARSAL_PRINT(ARSAL_PRINT_INFO, TAG, "- Stop ARNetwork");
    
    // ARNetwork cleanup
    if (_netManager != NULL)
    {
        ARNETWORK_Manager_Stop(_netManager);
        if (_rxThread != NULL)
        {
            ARSAL_Thread_Join(_rxThread, NULL);
            ARSAL_Thread_Destroy(&(_rxThread));
            _rxThread = NULL;
        }
        
        if (_txThread != NULL)
        {
            ARSAL_Thread_Join(_txThread, NULL);
            ARSAL_Thread_Destroy(&(_txThread));
            _txThread = NULL;
        }
    }
    
    if ((_alManager != NULL) && (_alManagerInitialized == YES))
    {
        ARNETWORKAL_Manager_Unlock(_alManager);
        
        ARNETWORKAL_Manager_CloseBLENetwork(_alManager);
    }
    
    ARNETWORK_Manager_Delete(&(_netManager));
    ARNETWORKAL_Manager_Delete(&(_alManager));
}

- (BOOL) sendPCMD
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    /*
      NSLog(@"====> %d, %d, %d, %d, %d, %f",
	  (uint8_t)(_dataPCMD.flag),
	  (int8_t)(_dataPCMD.roll * 100.f),
	  (int8_t)(_dataPCMD.pitch * 100.f),
	  (int8_t)(_dataPCMD.yaw * 100.f),
	  (int8_t)(_dataPCMD.gaz * 100.f),
	  _dataPCMD.psi);
    */
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDronePilotingPCMD(cmdBuffer, sizeof(cmdBuffer), &cmdSize, _dataPCMD.flag, _dataPCMD.roll*100.f, _dataPCMD.pitch*100.f, _dataPCMD.yaw*100.f, _dataPCMD.gaz*100.f, _dataPCMD.psi);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
      {
	// The commands sent in loop should be sent to a buffer not acknowledged ; here JS_NET_CD_NONACK_ID
	netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_NONACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
      }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
      {
	sentStatus = NO;
      }

    return sentStatus;
}

- (BOOL) sendFlatTrim
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDronePilotingFlatTrim(cmdBuffer, sizeof(cmdBuffer), &cmdSize);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendAutoTakeoff:(uint8_t)state
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDronePilotingAutoTakeOffMode(cmdBuffer, sizeof(cmdBuffer), &cmdSize, state);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendTakeoff
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDronePilotingTakeOff(cmdBuffer, sizeof(cmdBuffer), &cmdSize);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendLanding
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDronePilotingLanding(cmdBuffer, sizeof(cmdBuffer), &cmdSize);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendEmergency
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDronePilotingEmergency(cmdBuffer, sizeof(cmdBuffer), &cmdSize);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The command emergency should be sent to its own buffer acknowledged  ; here RS_NET_C2D_EMERGENCY
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_EMERGENCY, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendAnimationsFlip:(eARCOMMANDS_MINIDRONE_ANIMATIONS_FLIP_DIRECTION)direction
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDroneAnimationsFlip(cmdBuffer, sizeof(cmdBuffer), &cmdSize, direction);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendAnimationsCap:(int16_t)offset
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDroneAnimationsCap(cmdBuffer, sizeof(cmdBuffer), &cmdSize, offset);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendMediaRecordPicture:(uint8_t)mass_storage_id
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDroneMediaRecordPicture(cmdBuffer, sizeof(cmdBuffer), &cmdSize, mass_storage_id);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendMaxAltitude:(float)current
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDronePilotingSettingsMaxAltitude(cmdBuffer, sizeof(cmdBuffer), &cmdSize, current);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendMaxTilt:(float)current
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDronePilotingSettingsMaxTilt(cmdBuffer, sizeof(cmdBuffer), &cmdSize, current);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendMaxVerticalSpeed:(float)current
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDroneSpeedSettingsMaxVerticalSpeed(cmdBuffer, sizeof(cmdBuffer), &cmdSize, current);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendMaxRotationSpeed:(float)current
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDroneSpeedSettingsMaxRotationSpeed(cmdBuffer, sizeof(cmdBuffer), &cmdSize, current);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendWheelsOn:(uint8_t)present
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDroneSpeedSettingsWheels(cmdBuffer, sizeof(cmdBuffer), &cmdSize, present);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendCutOutMode:(uint8_t)enable
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;
    
    // Send Posture command
    cmdError = ARCOMMANDS_Generator_GenerateMiniDroneSettingsCutOutMode(cmdBuffer, sizeof(cmdBuffer), &cmdSize, enable);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendCurrentDate
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;

    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    [dateFormatter setLocale:[NSLocale systemLocale]];
    // Set date
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    
    // Send Date command
    cmdError = ARCOMMANDS_Generator_GenerateCommonCommonCurrentDate(cmdBuffer, sizeof(cmdBuffer), &cmdSize, (char *)[[dateFormatter stringFromDate:currentDate] cStringUsingEncoding:NSUTF8StringEncoding]);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}

- (BOOL) sendCurrentTime
{
    BOOL sentStatus = YES;
    u_int8_t cmdBuffer[128];
    int32_t cmdSize = 0;
    eARCOMMANDS_GENERATOR_ERROR cmdError;
    eARNETWORK_ERROR netError = ARNETWORK_ERROR;

    NSDate *currentDate = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    [dateFormatter setLocale:[NSLocale systemLocale]];
    // Set time
    [dateFormatter setDateFormat:@"'T'HHmmssZZZ"];
    
    // Send Time command
    cmdError = ARCOMMANDS_Generator_GenerateCommonCommonCurrentTime(cmdBuffer, sizeof(cmdBuffer), &cmdSize, (char *)[[dateFormatter stringFromDate:currentDate] cStringUsingEncoding:NSUTF8StringEncoding]);
    if (cmdError == ARCOMMANDS_GENERATOR_OK)
    {
        // The commands sent by event should be sent to an buffer acknowledged  ; here RS_NET_C2D_ACK
        netError = ARNETWORK_Manager_SendData(_netManager, RS_NET_C2D_ACK, cmdBuffer, cmdSize, NULL, &(arnetworkCmdCallback), 1);
    }
    
    if ((cmdError != ARCOMMANDS_GENERATOR_OK) || (netError != ARNETWORK_OK))
    {
        sentStatus = NO;
    }
    
    return sentStatus;
}
 
-(void) registerARCommandsCallbacks
{
    ARCOMMANDS_Decoder_SetCommonCommonStateBatteryStateChangedCallback(batteryStateChangedCallback, (__bridge void *)self);
}

-(void) unregisterARCommandsCallbacks
{
    ARCOMMANDS_Decoder_SetCommonCommonStateBatteryStateChangedCallback (NULL, NULL);
}

/**
 * @brief fuction called on disconnect
 * @param manager The manager
 */
void onDisconnectNetwork (ARNETWORK_Manager_t *manager, ARNETWORKAL_Manager_t *alManager, void *customData)
{
    if(customData != NULL) {
      DeviceController *deviceController = (__bridge DeviceController*)customData;
    
      NSLog(@"onDisconnectNetwork ... %@ : %@", deviceController, [deviceController delegate]);
      
      if ((deviceController != nil) && (deviceController.delegate != nil))
	{
	  [deviceController.delegate onDisconnectNetwork:deviceController];
	}

      [deviceController stop];
    }
}

void *looperRun (void* data)
{
    //DEVICE_MANAGER_t *deviceManager = (DEVICE_MANAGER_t *)data;
    DeviceController *deviceController = (__bridge DeviceController*)data;
    
    if(deviceController != NULL)
    {
        while (deviceController.run)
        {
            [deviceController sendPCMD];
	    usleep(50000);
        }
    }
    
    return NULL;
}

void *readerRun (void* data)
{
    DeviceController *deviceController = NULL;
    int bufferId = 0;
    int failed = 0;
    
    // Allocate some space for incoming data.
    const size_t maxLength = 128 * 1024;
    void *readData = malloc (maxLength);
    if (readData == NULL)
    {
        failed = 1;
    }
    
    if (!failed)
    {
        // get thread data.
        if (data != NULL)
        {
            bufferId = ((READER_THREAD_DATA_t *)data)->readerBufferId;
            deviceController = (__bridge DeviceController*)((READER_THREAD_DATA_t *)data)->deviceController;
            
            if (deviceController == NULL)
            {
                failed = 1;
            }
        }
        else
        {
            failed = 1;
        }
    }
    
    if (!failed)
    {
        while (deviceController.run)
        {
            eARNETWORK_ERROR netError = ARNETWORK_OK;
            int length = 0;
            int skip = 0;
            
            // read data
            netError = ARNETWORK_Manager_ReadDataWithTimeout (deviceController.netManager, bufferId, readData, maxLength, &length, 1000);
            if (netError != ARNETWORK_OK)
            {
                if (netError != ARNETWORK_ERROR_BUFFER_EMPTY)
                {
                    ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "ARNETWORK_Manager_ReadDataWithTimeout () failed : %s", ARNETWORK_Error_ToString(netError));
                }
                skip = 1;
            }
            
            if (!skip)
            {
                // Forward data to the CommandsManager
                eARCOMMANDS_DECODER_ERROR cmdError = ARCOMMANDS_DECODER_OK;
                cmdError = ARCOMMANDS_Decoder_DecodeBuffer ((uint8_t *)readData, length);
                if ((cmdError != ARCOMMANDS_DECODER_OK) && (cmdError != ARCOMMANDS_DECODER_ERROR_NO_CALLBACK))
                {
                    char msg[128];
                    ARCOMMANDS_Decoder_DescribeBuffer ((uint8_t *)readData, length, msg, sizeof(msg));
                    ARSAL_PRINT(ARSAL_PRINT_ERROR, TAG, "ARCOMMANDS_Decoder_DecodeBuffer () failed : %d %s", cmdError, msg);
                }
            }
        }
    }
    
    if (readData != NULL)
    {
        free (readData);
        readData = NULL;
    }
    
    return NULL;
}

eARNETWORK_MANAGER_CALLBACK_RETURN arnetworkCmdCallback(int buffer_id, uint8_t *data, void *custom, eARNETWORK_MANAGER_CALLBACK_STATUS cause)
{
    eARNETWORK_MANAGER_CALLBACK_RETURN retval = ARNETWORK_MANAGER_CALLBACK_RETURN_DEFAULT;
    
    if (cause == ARNETWORK_MANAGER_CALLBACK_STATUS_TIMEOUT)
    {
        retval = ARNETWORK_MANAGER_CALLBACK_RETURN_DATA_POP;
    }
    
    return retval;
}

void batteryStateChangedCallback (uint8_t percent, void *custom)
{
    // callback of changing of battery level
    DeviceController *deviceController = (__bridge DeviceController*)custom;
    
    NSLog(@"batteryStateChangedCallback ... %d  ; %@ : %@", percent, deviceController, [deviceController delegate]);
    
    if ((deviceController != nil) && (deviceController.delegate != nil))
    {
        [deviceController.delegate onUpdateBattery:deviceController batteryLevel:percent];
    }
}

- (void) setRoll:(float)roll
{
    _dataPCMD.roll = roll;
}

- (void) setPitch:(float)pitch
{
    _dataPCMD.pitch = pitch;
}

- (void) setYaw:(float)yaw
{
    _dataPCMD.yaw = yaw;
}

- (void) setGaz:(float)gaz
{
    _dataPCMD.gaz = gaz;
}

- (void) setFlag:(uint8_t)flag
{
    _dataPCMD.flag = flag;
}

@end
