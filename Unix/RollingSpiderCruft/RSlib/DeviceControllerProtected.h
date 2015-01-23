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
//  DeviceControllerProtected.h
//  ARFreeFlight
//
//  Created by Hugo Grostabussiat on 05/12/2013.
//  Copyright (c) 2013 Parrot SA. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <libARUtils/ARUtils.h>

#import "ARNetworkConfig.h"
#import "DeviceController.h"

/** startBaseController status code. */
typedef enum {
    BASE_DEVICE_CONTROLLER_START_RETVAL_OK = 0, /**< The controller started successfully. */
    BASE_DEVICE_CONTROLLER_START_RETVAL_CANCELLED, /**< The controller start was cancelled. */
    BASE_DEVICE_CONTROLLER_START_RETVAL_FAILED, /**< The controller failed to start because an error occurred. */
    BASE_DEVICE_CONTROLLER_START_RETVAL_MAX
} eBASE_DEVICE_CONTROLLER_START_RETVAL;

@protocol ARNetworkSendStatusDelegate <NSObject>
@optional
- (void)networkDidSendFrame:(DeviceControllerCompletionBlock)completion;
- (void)networkDidReceiveAck:(DeviceControllerCompletionBlock)completion;
- (void)networkTimeoutOccurred:(DeviceControllerCompletionBlock)completion;
- (void)networkDidCancelFrame:(DeviceControllerCompletionBlock)completion;
@end

/* Protected interface for the DeviceController class. */

@interface DeviceController () <ARNetworkSendStatusDelegate>
/** Controller loop interval in seconds. */
@property (atomic, assign) NSTimeInterval loopInterval;

- (id)initWithARNetworkConfig:(ARNetworkConfig*)netConfig withARService:(ARService*)service withBridgeDeviceController:(DeviceController *)bridgeDeviceController withLoopInterval:(NSTimeInterval)interval;

/** Start the base DeviceController.
 * @note This method wil block until the controller is started or fails to start.
 * @warning The video delegate will be reset to nil.
 * @return A status code indicating whether the base controller was started
 * successfully. OK indicates success, any other value gives the reason why the
 * base controller wasn't started.
 */
- (eBASE_DEVICE_CONTROLLER_START_RETVAL)startBaseController;

/** Stop the base DeviceController.
 * @note This method will block until the controller is stopped.
 */
- (void)stopBaseController;

/** Cancel the base DeviceController start.
 */
- (void)cancelBaseControllerStart;

/** Method called in a dedicated thread on a configurable interval.
 * @note This is an abstract method that you must override.
 */
- (void)controllerLoop;

/** Send raw data through ARNetwork.
 * Optionally notify about the delivery status.
 * @param data A pointer to the data to send.
 * @param size The size of the data chunk.
 * @param bufferId The ID of the IOBuffer on which to send the data.
 * @param policy The action that should be taken in case the sent frame is not
 * acknowledged by the remote party. Has no effect for unacknowledged IOBuffers.
 * @param delegate An optional delegate that will be called for each change in
 * the lifecycle of the frame to send.
 * @param userInfo Mandatory malloc()'ed structure that will be passed to the
 * delegate each time it is called. The data will automatically be free()'d at
 * the end of the frame lifecycle. This parameter SHALL be NULL if the delegate
 * parameter is nil.
 * @returns YES if the data was queued, NO if it could not.
 * @warning If you are using a DeviceController subclass as a delegate, you
 * MUST call the DeviceController implementation of the delegate. You MUST NOT
 * process events for which
 */
- (BOOL)sendData:(void*)data
        withSize:(size_t)size
        onBufferWithId:(int)bufferId
        withSendPolicy:(eARNETWORK_SEND_POLICY)policy
        withCompletionBlock:(DeviceControllerCompletionBlock)completion;

/** Gets the network bandwidth used by ARNetworkAL.
 * @param upload A pointer which will hold the upload value (in Bps).
 * @param download A pointer which will hold the download value (in Bps).
 * @return YES if the values were updated, NO otherwise.
 */
- (BOOL)getBandwidthForUpload:(uint32_t *)upload andDownload:(uint32_t *)download;

@end
