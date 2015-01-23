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
//  DeviceController.h
//  ARFreeFlight
//
//  Created by Hugo Grostabussiat on 05/12/2013.
//  Copyright (c) 2013 Parrot SA. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <libARDiscovery/ARDiscovery.h>
#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>
#import <libARCommands/ARCommands.h>

//#import <libARUtils/ARFrame.h>

typedef struct ARFrame {
  int nothing;
} ARFrame;

/** ARNetwork sending policy. */
typedef enum
{
    /** Drop the packet if the retry threshold is exceeded. */
    ARNETWORK_SEND_POLICY_DROP,
    /** Retry regardless of the current retry count. */
    ARNETWORK_SEND_POLICY_RETRY,
    /** Drop all pending frames from all the IOBuffers. */
    ARNETWORK_SEND_POLICY_FLUSH
} eARNETWORK_SEND_POLICY;

typedef enum
{
    DEVICE_CONTROLLER_STATE_STOPPED = 0,
    DEVICE_CONTROLLER_STATE_STARTED,
    DEVICE_CONTROLLER_STATE_STARTING,
    DEVICE_CONTROLLER_STATE_STOPPING
} eDEVICE_CONTROLLER_STATE;

/*
 * User defaults key to get list of product serial number was connected
 */
extern NSString *const DeviceControllerConnectedProductsKey; // Get NSDictionary from UserDefaults
extern NSString *const DeviceControllerConnectedProductIdsKey; // Get NSNumber from dictionary
extern NSString *const DeviceControllerConnectedProductSerialsKey; // Get NSString from dictionary

extern NSString *const DeviceControllerProductFirmwaresCheckedKey; // Get NSDictionary from UserDefaults
extern NSString *const DeviceControllerProductFirmwaresIdsKey; // Get NSNumber from dictionary
extern NSString *const DeviceControllerProductFirmwaresSerialsKey; // Get NSString from dictionary

/* ==== DeviceController state change notifications ====
 * Notifies that the state of the device controller changed.
 */
extern NSString *const DeviceControllerWillStartNotification;
extern NSString *const DeviceControllerDidStartNotification;
extern NSString *const DeviceControllerDidStopNotification;
extern NSString *const DeviceControllerWillStopNotification;
extern NSString *const DeviceControllerDidFailNotification;
extern NSString *const DeviceControllerNotificationsDictionaryChanged;
extern NSString *const DeviceControllerNotificationAllSettingsDidStart;
extern NSString *const DeviceControllerNotificationAllStatesDidStart;

/** Define Completion block for acknowledged command */
typedef void (^DeviceControllerCompletionBlock)(void);

@protocol DeviceControllerVideoStreamDelegate <NSObject>
@required
/** Method called for each newly-received frame. */
- (void)didReceiveFrame:(ARFrame *)frame;
@optional
/** Method called when no video frame is received for a device-specific time. */
- (void)didTimedOutReceivingFrame;
@end

@class DeviceController;

/** A protocol that should be implemented by the device controllers whose
 * devices support live video streaming enable/disable control.
 */
@protocol DeviceControllerVideoStreamControlProtocol <NSObject>
@required
/** Return whether the device supports enabling/disabling live video streaming. */
- (BOOL)supportsVideoStreamingControl;

/** Get whether live video streaming is currently enabled.
 *
 * For devices with an old firmware that does not support live video streaming
 * control, the returned value will always be YES.
 */
- (BOOL)isVideoStreamingEnabled;

/** Enable/disable live video streaming.
 * This will send a command no matter whether the device supports it or not.
 */
- (void)enableVideoStreaming:(BOOL)enable;
@end

@protocol DeviceControllerDelegate <NSObject>
@required
@property (nonatomic, strong) DeviceController *deviceController;
@end

@interface DeviceController : NSObject
/** Get/set the video delegate object. New video frames will be forwarded to it. */
@property (nonatomic, weak) id<DeviceControllerVideoStreamDelegate> videoStreamDelegate;

/** Set by device controller. DO NOT USE DIRECTLY - USE notificationDictionary to have a copy. */
@property (nonatomic, strong) NSMutableDictionary *privateNotificationsDictionary;

/** Get the notifications dictionary associated with this controller. */
@property (readonly, nonatomic, strong) NSDictionary *notificationsDictionary;

/** Get the ARService instance associated with this controller. */
@property (readonly, nonatomic, strong) ARService* service;

/** Get the ARService instance used like bridge. */
@property (readonly, nonatomic, strong) DeviceController* bridgeDeviceController;

/** Get the SkyController software version. */
@property (readonly, nonatomic, strong) NSString* skyControllerSoftVersion;

@property (nonatomic, assign) BOOL fastReconnection;

/** Request a stopped controller to start.
 * @note This is an abstract method.
 */
- (void)start;

/** Request a started controller to stop.
 * @note This is an abstract method.
 */
- (void)stop;

- (void)pause:(BOOL)pause;

/** Get the current state of the controller.
 * @note This is an abstract method.
 */
- (eDEVICE_CONTROLLER_STATE)state;

/** Call this method when the product is really connected.
 * @note This method register product to get it later.
 */
- (void)registerCurrentProduct;

/** Ask reboot to product.
 * @note This is an abstract method.
 */
- (void)userRequestedReboot;

/** Ask reset to product.
 * @note This is an abstract method.
 */
- (void)userRequestedSettingsReset;

/** Set AutoCountry Mode.
 * @note This is an abstract method.
 */
- (void)userRequestAutoCountry:(int)automatic;

/** Set outdoor wifi
 */
- (void)userRequestedOutdoorWifi:(BOOL)outdoor;

/** Notify the drone that we entered/left the piloting HUD.
 * @arg inHud YES when entering the HUD, NO when leaving the HUD.
 * @note This is an abstract method.
 */
- (void)userEnteredPilotingHud:(BOOL)inHud;

- (void)userRequestMavlinkPlay:(NSString*)filename type:(eARCOMMANDS_COMMON_MAVLINK_START_TYPE)type;
- (void)userRequestMavlinkPause;
- (void)userRequestMavlinkStop;

- (void)userRequestedCalibrate:(BOOL)startProcess;
@end
