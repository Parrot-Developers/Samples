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
//  MiniDroneDeviceController.h
//  ARFreeFlight
//
//  Created by Hugo Grostabussiat on 09/12/2013.
//  Copyright (c) 2013 Parrot SA. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <libARCommands/ARCommands.h>
#import "DeviceController.h"

/* Notification posted when the Drone flying state changes.
 * userInfo keys:
 * - flyingState: Boolean encoded as a NSNumber containing the new flying state. */
extern NSString* MiniDroneDeviceControllerFlyingStateChangedNotification;
/* Notification posted when the Drone emergency state changes.
 * userInfo keys:
 * - emergencyState: Boolean encoded as a NSNumber containing the new emergency state. */
extern NSString* MiniDroneDeviceControllerEmergencyStateChangedNotification;
/* Notification posted when the MiniDrone receives debug command. */
extern NSString* MiniDroneDeviceControllerDebug1ReceivedNotification;
extern NSString* MiniDroneDeviceControllerDebug2ReceivedNotification;
extern NSString* MiniDroneDeviceControllerDebug3ReceivedNotification;

typedef struct MiniDronePilotingData_t
{
    BOOL active;
    float roll;
    float pitch;
    float yaw;
    float gaz;
    float heading;
} MiniDronePilotingData_t;

@class MiniDronePhotoRecordController;

@interface MiniDroneDeviceController : DeviceController
@property (nonatomic, strong, readonly) MiniDronePhotoRecordController *photoRecordController;

- (id)initWithService:(ARService*)service;

/* User-generated events. */
- (void)controllerLoop;
- (void)userCommandsActivationChanged:(BOOL)activated;
- (void)userRollChanged:(float)roll;
- (void)userPitchChanged:(float)pitch;
- (void)userYawChanged:(float)yaw;
- (void)userGazChanged:(float)gaz;
- (void)userHeadingChanged:(float)heading;
- (void)userRequestedTakeOff;
- (void)userRequestedLanding;
- (void)userRequestedEmergency;
- (void)userRequestedFlatTrim;
- (void)userRequestedRecordPicture:(int)massStorageId;
- (void)userRequestFlip:(eARCOMMANDS_MINIDRONE_ANIMATIONS_FLIP_DIRECTION)flipDirection;
- (void)userRequestCap:(int16_t)offset;
- (void)userRequestSetAutoTakeOffMode:(uint8_t)state;
- (BOOL)userSetDebug1Value:(int8_t)value;
- (BOOL)userSetDebug2Value:(int8_t)value;
- (BOOL)userSetDebug3Value:(int8_t)value;

- (void)userRequestedPilotingSettingsMaxAltitude:(float)maxAltitude;
- (void)userRequestedPilotingSettingsMaxTilt:(float)maxTilt;
- (void)userRequestedSpeedSettingsMaxRotationSpeed:(float)maxRotationSpeed;
- (void)userRequestedSpeedSettingsMaxVerticalSpeed:(float)maxVerticalSpeed;
- (void)userRequestedSpeedSettingsWheels:(BOOL)present;
- (void)userRequestedSpeedSettingsCutOut:(BOOL)enable;
- (void)userRequestedSettingsReset;
- (void)userRequestedSettingsProductName:(NSString *)productName;
@end
