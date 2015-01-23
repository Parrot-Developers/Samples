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
//  ARNetworkConfig.h
//  ARFreeFlight
//
//  Created by Hugo Grostabussiat on 05/12/2013.
//  Copyright (c) 2013 Parrot SA. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <libARNetwork/ARNetwork.h>

@interface ARNetworkConfig : NSObject

/** Return a boolean indicating whether the device supports video streaming. */
- (BOOL)hasVideo;

/** Get the controller to device parameters.
 * @note The data shall not be modified nor freed by the user.
 */
- (ARNETWORK_IOBufferParam_t*)c2dParams;

/** Get the device to controller parameters.
 * @note The data shall not be modified nor freed by the user.
 */
- (ARNETWORK_IOBufferParam_t*)d2cParams;

/** Get the number of elements in the array returned by c2dParams. */
- (size_t)numC2dParams;

/** Get the number of elements in the array returned by d2cParams. */
- (size_t)numD2cParams;

/** Get an array of buffer IDs from which to read commands. */
- (int*)commandsIOBuffers;

/** Get the number of commands buffer IDs in the array returned by commandsIOBuffers. */
- (size_t)numCommandsIOBuffers;

/** Get the buffer ID of the video stream data channel. */
- (int)videoDataIOBuffer;

/** Get the buffer ID of the video stream acknowledgement channel. */
- (int)videoAckIOBuffer;

/** Get the buffer ID of the acknowledged channel on which all the common commands will be sent.
 * @warning I insist that it MUST be the ID of an acknowledged IOBuffer. Returning an ID for an
 * unacknowledged IOBuffer will cause the controller to wait for a notification that will never
 * come.
 */
- (int)commonCommandsAckedIOBuffer;

/** Return the inbound port number for WiFi devices.
 * @fixme Remove this and use ARDISCOVERY_Connection instead.
 */
- (int)inboundPort;

/** Return the outbound port number for WiFi devices.
 * @fixme Remove this and use ARDISCOVERY_Connection instead.
 */
- (int)outboundPort;

/** initialize the StreamRead IOBuffers
 * @return YES if successful otherwise NO
 */
- (BOOL) initStreamReadIOBuffer:(int) maxFragmentSize maxNumberOfFragment:(int) maxNumberOfFragment;

/** Get the ID of BLE characteristics to notify. */
- (int *) bleNotificationIDs;

/** Get the number of elements in the array returned by bleNotificationIDs. */
- (size_t)numBLENotificationIDs;

/** Get the default ARStream maxAckInteval value to use if the remote device does not specify one. */
- (int32_t)defaultVideoMaxAckInterval;

@end
