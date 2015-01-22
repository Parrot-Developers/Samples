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
//  MiniDroneARNetworkConfig.m
//  ARFreeFlight
//
//  Created by Hugo Grostabussiat on 09/12/2013.
//  Copyright (c) 2013 Parrot SA. All rights reserved.
//
#import <libARNetwork/ARNetwork.h>
#import <libARNetworkAL/ARNetworkAL.h>
#import <libARStream/ARStream.h>
#import "MiniDroneARNetworkConfig.h"

static const int iobuffer_c2d_nack = 10;
static const int iobuffer_c2d_ack = 11;
static const int iobuffer_c2d_emergency = 12;
static const int iobuffer_d2c_navdata = (ARNETWORKAL_MANAGER_BLE_ID_MAX / 2) - 1;
static const int iobuffer_d2c_events = (ARNETWORKAL_MANAGER_BLE_ID_MAX / 2) - 2;

static int bleNotificationIDs[] = {
    iobuffer_d2c_navdata,
    iobuffer_d2c_events,
    (iobuffer_c2d_ack + (ARNETWORKAL_MANAGER_BLE_ID_MAX / 2)),
    (iobuffer_c2d_emergency + (ARNETWORKAL_MANAGER_BLE_ID_MAX / 2)),
};
static const size_t num_bleNotificationIDs = sizeof(bleNotificationIDs) / sizeof(int);

static ARNETWORK_IOBufferParam_t c2d_params[] = {
    {
        .ID = iobuffer_c2d_nack,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA,
        .sendingWaitTimeMs = 20,
        .ackTimeoutMs = -1,
        .numberOfRetry = -1,
        .numberOfCell = 1,
        .dataCopyMaxSize = ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
        .isOverwriting = 1,
    },
    {
        .ID = iobuffer_c2d_ack,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA_WITH_ACK,
        .sendingWaitTimeMs = 20,
        .ackTimeoutMs = 500,
        .numberOfRetry = 3,
        .numberOfCell = 20,
        .dataCopyMaxSize = ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
        .isOverwriting = 0,
    },
    {
        .ID = iobuffer_c2d_emergency,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA_WITH_ACK,
        .sendingWaitTimeMs = 1,
        .ackTimeoutMs = 100,
        .numberOfRetry = ARNETWORK_IOBUFFERPARAM_INFINITE_NUMBER,
        .numberOfCell = 1,
        .dataCopyMaxSize = ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
        .isOverwriting = 0,
    }
};
static const size_t num_c2d_params = sizeof(c2d_params) / sizeof(ARNETWORK_IOBufferParam_t);

static ARNETWORK_IOBufferParam_t d2c_params[] = {
    {
        .ID = iobuffer_d2c_navdata,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA,
        .sendingWaitTimeMs = 20,
        .ackTimeoutMs = -1,
        .numberOfRetry = -1,
        .numberOfCell = 20,
        .dataCopyMaxSize = ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
        .isOverwriting = 0,
    },
    {
        .ID = iobuffer_d2c_events,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA_WITH_ACK,
        .sendingWaitTimeMs = 20,
        .ackTimeoutMs = 500,
        .numberOfRetry = 3,
        .numberOfCell = 20,
        .dataCopyMaxSize = ARNETWORK_IOBUFFERPARAM_DATACOPYMAXSIZE_USE_MAX,
        .isOverwriting = 0,
    }
};
static const size_t num_d2c_params = sizeof(d2c_params) / sizeof(ARNETWORK_IOBufferParam_t);

static int commands_buffers[] = {
    iobuffer_d2c_navdata,
    iobuffer_d2c_events,
};
static const size_t num_commands_buffers = sizeof(commands_buffers) / sizeof(int);

@implementation MiniDroneARNetworkConfig

+ (int)c2dNackId
{
    return iobuffer_c2d_nack;
}

+ (int)c2dAckId
{
    return iobuffer_c2d_ack;
}

+ (int)c2dEmergencyId
{
    return iobuffer_c2d_emergency;
}

+ (int)d2cNavdataId
{
    return iobuffer_d2c_navdata;
}

+ (int)d2cEventsId
{
    return iobuffer_d2c_events;
}

- (id)init
{
    self = [super init];
    if (self != nil) {
    }
    return self;
}

- (BOOL)hasVideo
{
    return NO;
}

- (ARNETWORK_IOBufferParam_t*)c2dParams
{
    return c2d_params;
}

- (ARNETWORK_IOBufferParam_t*)d2cParams
{
    return d2c_params;
}

- (size_t)numC2dParams
{
    return num_c2d_params;
}

- (size_t)numD2cParams
{
    return num_d2c_params;
}

- (int*)commandsIOBuffers
{
    return commands_buffers;
}

- (size_t)numCommandsIOBuffers
{
    return num_commands_buffers;
}

- (int)videoDataIOBuffer
{
    return -1;
}

- (int)videoAckIOBuffer
{
    return -1;
}

- (int)commonCommandsAckedIOBuffer
{
    return iobuffer_c2d_ack;
}

- (int)inboundPort
{
    return -1;
}

- (int)outboundPort
{
    return -1;
}

- (int *)bleNotificationIDs
{
    return bleNotificationIDs;
}

- (size_t)numBLENotificationIDs
{
    return num_bleNotificationIDs;
}

- (int32_t)defaultVideoMaxAckInterval
{
    // This method makes no sense for the RollingSpider since video streaming isn't supported.
    return -1;
}

@end
