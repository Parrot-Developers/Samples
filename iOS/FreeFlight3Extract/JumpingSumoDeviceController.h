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
//  JumpingSumoDeviceController.h
//  ARFreeFlight
//
//  Created by Hugo Grostabussiat on 06/12/2013.
//  Copyright (c) 2013 Parrot SA. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <libARCommands/ARCommands.h>
#import "DeviceController.h"

@class JumpingSumoVideoRecordController;
@class JumpingSumoPhotoRecordController;

@interface JumpingSumoDeviceController : DeviceController <DeviceControllerVideoStreamControlProtocol>
@property (atomic, readonly) eDEVICE_CONTROLLER_STATE state;
@property (nonatomic, strong, readonly) JumpingSumoVideoRecordController *videoRecordController;
@property (nonatomic, strong, readonly) JumpingSumoPhotoRecordController *photoRecordController;

- (id)initWithService:(ARService*)service;

- (void)userChangedScreenFlag:(BOOL)flag; // Thread-safe
- (void)userChangedSpeed:(float)speed; // Thread-safe
- (void)userChangedTurnRatio:(float)turnRatio; // Thread-safe
- (void)userChangedPosture:(eARCOMMANDS_JUMPINGSUMO_PILOTING_POSTURE_TYPE)posture; // Thread-safe

- (void)userRequestedJumpStop;
- (void)userRequestedJumpCancel; // Thread-safe
- (void)userRequestedJumpLoad; // Thread-safe
- (void)userRequestedLongJump; // Thread-safe
- (void)userRequestedHighJump; // Thread-safe

- (void)userRequestedRecordPicture:(int)massStorageId;
- (void)userRequestedRecordVideoStart:(int)massStorageId;
- (void)userRequestedRecordVideoStop:(int)massStorageId;

- (void)userRequestedSettingsReset;
- (void)userRequestedSettingsCountry:(NSString *)country;
- (void)userRequestedSettingsProductName:(NSString *)productName;
- (void)userRequestedSettingsNetworkWifiType:(eARCOMMANDS_JUMPINGSUMO_NETWORKSETTINGS_WIFISELECTION_TYPE)type band:(eARCOMMANDS_JUMPINGSUMO_NETWORKSETTINGS_WIFISELECTION_BAND)band channel:(int) channel;
- (void)userRequestedSettingsNetworkWifiScan:(eARCOMMANDS_JUMPINGSUMO_NETWORK_WIFISCAN_BAND)band;
- (void)userRequestedSettingsNetworkWifiAuthChannel; 
- (void)userRequestedSettingsAudioMasterVolume:(uint8_t)volume;
- (void)userRequestedSettingsAudioTheme:(eARCOMMANDS_JUMPINGSUMO_AUDIOSETTINGS_THEME_THEME)theme;

- (void)userUploadedScript:(NSUUID*)uuid withMd5:(NSString*)md5Hash;
- (void)userRequestedScriptDeletion:(NSUUID*)uuid;
- (void)userRequestedScriptListRefresh;
- (void)userTriggeredScriptWithUuid:(NSUUID*)uuid;

- (void)userTriggeredAnimation:(eARCOMMANDS_JUMPINGSUMO_ANIMATIONS_SIMPLEANIMATION_ID)animation; // Thread-safe

- (void)userTriggeredLeft90;
- (void)userTriggeredRight90;
- (void)userTriggeredLeftTurnback;
- (void)userTriggeredRightTurnback;

- (void)userTriggeredDefaultSound; // Thread-safe

- (void)jumpingsumo_networkstate_wifiscanlist_clean;
- (void)jumpingsumo_networkstate_wifiauthchannellist_clean;

@end
