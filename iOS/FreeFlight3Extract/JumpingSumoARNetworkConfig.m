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
//  JumpingSumoARNetworkConfig.m
//  ARFreeFlight
//
//  Created by Hugo Grostabussiat on 06/12/2013.
//  Copyright (c) 2013 Parrot SA. All rights reserved.
//
#import <libARNetwork/ARNetwork.h>
#import <libARNetworkAL/ARNetworkAL.h>
#import <libARStream/ARStream.h>
#import "JumpingSumoARNetworkConfig.h"

static const int iobuffer_c2d_nack = 10;
static const int iobuffer_c2d_ack = 11;
static const int iobuffer_c2d_arstream_ack = 13;
static const int iobuffer_d2c_nack = (ARNETWORKAL_MANAGER_WIFI_ID_MAX / 2) - 1;
static const int iobuffer_d2c_ack = (ARNETWORKAL_MANAGER_WIFI_ID_MAX / 2) - 2;
static const int iobuffer_d2c_arstream_data = (ARNETWORKAL_MANAGER_WIFI_ID_MAX / 2) - 3;

static const int inbound_port = 54321;
static const int outbound_port = 43210;

static ARNETWORK_IOBufferParam_t c2d_params[] = {
    {
        .ID = iobuffer_c2d_nack,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA,
        .sendingWaitTimeMs = 5,
        .ackTimeoutMs = -1,
        .numberOfRetry = -1,
        .numberOfCell = 10,
        .dataCopyMaxSize = 128,
        .isOverwriting = 0,
    },
    {
        .ID = iobuffer_c2d_ack,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA_WITH_ACK,
        .sendingWaitTimeMs = 20,
        .ackTimeoutMs = 500,
        .numberOfRetry = 3,
        .numberOfCell = 20,
        .dataCopyMaxSize = 128,
        .isOverwriting = 0,
    },
    {
        .ID = iobuffer_c2d_arstream_ack,
        .dataType = ARNETWORKAL_FRAME_TYPE_UNINITIALIZED,
        .sendingWaitTimeMs = 0,
        .ackTimeoutMs = 0,
        .numberOfRetry = 0,
        .numberOfCell = 0,
        .dataCopyMaxSize = 0,
        .isOverwriting = 0,
    }
};
static const size_t num_c2d_params = sizeof(c2d_params) / sizeof(ARNETWORK_IOBufferParam_t);

static ARNETWORK_IOBufferParam_t d2c_params[] = {
    {
        .ID = iobuffer_d2c_nack,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA,
        .sendingWaitTimeMs = 20,
        .ackTimeoutMs = -1,
        .numberOfRetry = -1,
        .numberOfCell = 10,
        .dataCopyMaxSize = 128,
        .isOverwriting = 0,
    },
    {
        .ID = iobuffer_d2c_ack,
        .dataType = ARNETWORKAL_FRAME_TYPE_DATA_WITH_ACK,
        .sendingWaitTimeMs = 20,
        .ackTimeoutMs = 500,
        .numberOfRetry = 3,
        .numberOfCell = 20,
        .dataCopyMaxSize = 128,
        .isOverwriting = 0,
    },
    {
        .ID = iobuffer_d2c_arstream_data,
        .dataType = ARNETWORKAL_FRAME_TYPE_UNINITIALIZED,
        .sendingWaitTimeMs = 0,
        .ackTimeoutMs = 0,
        .numberOfRetry = 0,
        .numberOfCell = 0,
        .dataCopyMaxSize = 0,
        .isOverwriting = 0,
    }
};
static const size_t num_d2c_params = sizeof(d2c_params) / sizeof(ARNETWORK_IOBufferParam_t);

static int commands_buffers[] = {
    iobuffer_d2c_nack,
    iobuffer_d2c_ack,
};
static const size_t num_commands_buffers = sizeof(commands_buffers) / sizeof(int);

static int idToIndex(ARNETWORK_IOBufferParam_t* params, size_t num_params, int id)
{
    for (int i = 0; i < num_params; i ++) {
        if (params[i].ID == id) {
            return i;
        }
    }
    return -1;
}



@interface JumpingSumoARNetworkConfig ()
@end

@implementation JumpingSumoARNetworkConfig

+ (int)c2dNackId
{
    return iobuffer_c2d_nack;
}

+ (int)c2dAckId
{
    return iobuffer_c2d_ack;
}

+ (int)c2dArstreamAckId
{
    return iobuffer_c2d_arstream_ack;
}

+ (int)d2cNackId
{
    return iobuffer_d2c_nack;
}

+ (int)d2cAckId
{
    return iobuffer_d2c_ack;
}

+ (int)d2cArstreamDataId
{
    return iobuffer_d2c_arstream_data;
}

- (BOOL)hasVideo
{
    return YES;
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
    return iobuffer_d2c_arstream_data;
}

- (int)videoAckIOBuffer
{
    return iobuffer_c2d_arstream_ack;
}

- (int)commonCommandsAckedIOBuffer
{
    return iobuffer_c2d_ack;
}

- (int)inboundPort
{
    return inbound_port;
}

- (int)outboundPort
{
    return outbound_port;
}

- (BOOL) initStreamReadIOBuffer:(int) maxFragmentSize maxNumberOfFragment:(int) maxNumberOfFragment
{
    BOOL successful = YES;
    if ((idToIndex(c2d_params, num_c2d_params, iobuffer_c2d_arstream_ack) != -1) &&
        (idToIndex(d2c_params, num_d2c_params, iobuffer_d2c_arstream_data) != -1))
    {
        /* Initialize ARStream IOBuffers. */
        ARSTREAM_Reader_InitStreamAckBuffer(&c2d_params[idToIndex(c2d_params, num_c2d_params, iobuffer_c2d_arstream_ack)], iobuffer_c2d_arstream_ack);
        ARSTREAM_Reader_InitStreamDataBuffer(&d2c_params[idToIndex(d2c_params, num_d2c_params, iobuffer_d2c_arstream_data)], iobuffer_d2c_arstream_data, maxFragmentSize, maxNumberOfFragment);
    }
    else
    {
        successful = NO;
    }
    
    return successful;
}

- (int *)bleNotificationIDs
{
    return NULL;
}

- (size_t)numBLENotificationIDs
{
    return -1;
}

- (int32_t)defaultVideoMaxAckInterval
{
    // Disable all ARStream ACKs if no value given when connecting.
    return -1;
}

@end
