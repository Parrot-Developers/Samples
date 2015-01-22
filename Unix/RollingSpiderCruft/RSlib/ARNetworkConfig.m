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
//  ARNetworkConfig.m
//  ARFreeFlight
//
//  Created by Hugo Grostabussiat on 05/12/2013.
//  Copyright (c) 2013 Parrot SA. All rights reserved.
//
#import <libARUtils/ARUtils.h>
#import "ARNetworkConfig.h"

@implementation ARNetworkConfig

- (BOOL)hasVideo
{
    //AbstractMethodRaiseException;
    return NO;
}

- (ARNETWORK_IOBufferParam_t*)c2dParams
{
    //AbstractMethodRaiseException;
    return NULL;
}

- (ARNETWORK_IOBufferParam_t*)d2cParams
{
    //AbstractMethodRaiseException;
    return NULL;
}

- (size_t)numC2dParams
{
    //AbstractMethodRaiseException;
    return 0;
}

- (size_t)numD2cParams
{
    //AbstractMethodRaiseException;
    return 0;
}

- (int*)commandsIOBuffers
{
    //AbstractMethodRaiseException;
    return NULL;
}

- (size_t)numCommandsIOBuffers
{
    //AbstractMethodRaiseException;
    return 0;
}

- (int)videoDataIOBuffer
{
    //AbstractMethodRaiseException;
    return -1;
}

- (int)videoAckIOBuffer
{
    //AbstractMethodRaiseException;
    return -1;
}

- (int)commonCommandsAckedIOBuffer
{
    //AbstractMethodRaiseException;
    return -1;
}

- (int)inboundPort
{
    //AbstractMethodRaiseException;
    return -1;
}

- (int)outboundPort
{
    //AbstractMethodRaiseException;
    return -1;
}

- (BOOL) initStreamReadIOBuffer:(int) maxFragmentSize maxNumberOfFragment:(int) maxNumberOfFragment
{
    //AbstractMethodRaiseException;
    return NO;
}

- (int *) bleNotificationIDs
{
    //AbstractMethodRaiseException;
    return NULL;
}

- (size_t)numBLENotificationIDs
{
    //AbstractMethodRaiseException;
    return -1;
}

- (int32_t)defaultVideoMaxAckInterval
{
    //AbstractMethodRaiseException;
    return -1;
}

@end
