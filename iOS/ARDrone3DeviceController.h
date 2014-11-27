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
//  ARDrone3DeviceController.h
//  ARFreeFlight
//
//  Created by Hugo Grostabussiat on 09/12/2013.
//  Copyright (c) 2013 Parrot SA. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <libARCommands/ARCommands.h>
#import <CoreLocation/CoreLocation.h>
#import "DeviceController.h"

/* Notification posted when the Drone flying state changes.
 * userInfo keys:
 * - flyingState: Boolean encoded as a NSNumber containing the new flying state. */
extern NSString* ARDrone3DeviceControllerFlyingStateChangedNotification;
/* Notification posted when the Drone emergency state changes.
 * userInfo keys:
 * - emergencyState: Boolean encoded as a NSNumber containing the new emergency state. */
extern NSString* ARDrone3DeviceControllerEmergencyStateChangedNotification;

typedef struct ARDrone3PilotingData_t
{
    BOOL active;
    float roll;
    float pitch;
    float yaw;
    float gaz;
    float heading;
} ARDrone3PilotingData_t;

typedef struct _ARDrone3CameraData_t_
{
    float tilt;
    float pan;
} ARDrone3CameraData_t;

@class ARDrone3VideoRecordController;
@class ARDrone3PhotoRecordController;

@interface ARDrone3DeviceController : DeviceController <DeviceControllerVideoStreamControlProtocol>
@property (nonatomic, strong, readonly) ARDrone3VideoRecordController *videoRecordController;
@property (nonatomic, strong, readonly) ARDrone3PhotoRecordController *photoRecordController;

- (id)initWithService:(ARService*)service;
- (id)initWithService:(ARService*)service withBridgeDeviceController:(DeviceController*)bridgeService;

/* User-generated events. */
- (void)userCommandsActivationChanged:(BOOL)activated;
- (void)userRollChanged:(float)roll;
- (void)userPitchChanged:(float)pitch;
- (void)userYawChanged:(float)yaw;
- (void)userGazChanged:(float)gaz;
- (void)userHeadingChanged:(float)heading;
- (void)userRequestedTakeOff;
- (void)userRequestedLanding;
- (void)userRequestedEmergency;
- (void)userRequestedNavigateHome:(BOOL)start;
- (void)userRequestedFlatTrim;
- (void)userRequestedRecordPicture:(int)massStorageId;
- (void)userRequestedRecordVideoStart:(int)massStorageId;
- (void)userRequestedRecordVideoStop:(int)massStorageId;
- (void)userRequestFlip:(eARCOMMANDS_ARDRONE3_ANIMATIONS_FLIP_DIRECTION)flipDirection;
- (void)userCameraTiltChanged:(float)tilt;
- (void)userCameraPanChanged:(float)pan;
- (void)userRequestedSettingsReset;
- (void)userRequestedSettingsCountry:(NSString *)country;
- (void)userRequestedSettingsProductName:(NSString *)productName;
- (void)userRequestedPilotingSettingsMaxAltitude:(float)maxAltitude;
- (void)userRequestedPilotingSettingsMaxTilt:(float)maxTilt;
- (void)userRequestedPilotingSettingsAbsolutControl:(BOOL)on;
- (void)userRequestedSpeedSettingsMaxRotationSpeed:(float)maxRotationSpeed;
- (void)userRequestedSpeedSettingsMaxVerticalSpeed:(float)maxVerticalSpeed;
- (void)userRequestedSettingsNetworkWifiType:(eARCOMMANDS_ARDRONE3_NETWORKSETTINGS_WIFISELECTION_TYPE)type band:(eARCOMMANDS_ARDRONE3_NETWORKSETTINGS_WIFISELECTION_BAND)band channel:(int) channel;
- (void)userRequestedSettingsNetworkWifiScan:(eARCOMMANDS_ARDRONE3_NETWORK_WIFISCAN_BAND)band;
- (void)userRequestedSettingsNetworkWifiAuthChannel;
- (void)userRequestedSpeedSettingsHullProtection:(BOOL)present;
- (void)userRequestedSpeedSettingsOutdoor:(BOOL)outdoor;
- (void)userRequestedWithBalance;
- (void)ardrone3_networkstate_wifiscanlist_clean;
- (void)ardrone3_networkstate_wifiauthchannellist_clean;
- (void)userRequestedPictureSettingsPictureFormat:(eARCOMMANDS_ARDRONE3_PICTURESETTINGS_PICTUREFORMATSELECTION_TYPE)photoFormat;
- (void)userRequestedPictureSettingsWhiteBalance:(eARCOMMANDS_ARDRONE3_PICTURESETTINGS_AUTOWHITEBALANCESELECTION_TYPE)awbMode;
- (void)userRequestedPictureSettingsExposition:(float)expositionValue;
- (void)userRequestedPictureSettingsSaturation:(float)saturationValue;
- (void)userRequestedPictureSettingsTimelapseMode:(BOOL)enabled withInterval:(float)interval;
- (void)userRequestedPictureSettingsAutorecordVideo:(BOOL)autorecordMode massStorage:(int)massStorageId;
- (void)userRequestedDebugDrone2Battery:(BOOL)useDrone2Battery;
- (void)gpsSettingsSetHome:(CLLocationCoordinate2D)home andAltitude:(float)altitude;
@end
