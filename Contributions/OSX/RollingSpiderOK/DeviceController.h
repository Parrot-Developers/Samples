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
//  RollingSpiderPiloting
//
//  Created on 20/01/2015.
//  Copyright (c) 2015 Parrot. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libARSAL/ARSAL.h>
#import <libARDiscovery/ARDiscovery.h>
#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>
#import <libARCommands/ARCommands.h>
#import <libARNetwork/ARNetwork.h>
#import <libARNetworkAL/ARNetworkAL.h>

typedef struct
{
    uint8_t flag; // [0;1] flag to activate roll/pitch movement
    float roll; // [-1;1]
    float pitch; // [-1;1]
    float yaw; // [-1;1]
    float gaz; // [-1;1]
    float psi; // [-360;360]
}RS_PCMD_t;

typedef struct
{
    void *deviceController;
    int readerBufferId;
}READER_THREAD_DATA_t;



@class DeviceController;

@protocol DeviceControllerDelegate <NSObject>
- (void)onDisconnectNetwork:(DeviceController *)deviceController;
- (void)onUpdateBattery:(DeviceController *)deviceController batteryLevel:(uint8_t)percent;
@end


@interface DeviceController : NSObject

@property (nonatomic, weak) id <DeviceControllerDelegate> delegate;
/** Get the ARService instance associated with this controller. */
@property (readonly, nonatomic, strong) ARService* service;
@property (readonly, nonatomic, strong) CBPeripheral* peripheral;
@property (readonly, nonatomic, strong) ARDiscovery *ARD;
					
- (id)init;
- (BOOL)start;
- (void)stop;

- (BOOL) sendFlatTrim;
- (BOOL) sendAutoTakeoff:(uint8_t)state;
- (BOOL) sendTakeoff;
- (BOOL) sendLanding;
- (BOOL) sendEmergency;
- (BOOL) sendAnimationsFlip:(eARCOMMANDS_MINIDRONE_ANIMATIONS_FLIP_DIRECTION)direction;
- (BOOL) sendAnimationsCap:(int16_t)offset;
- (BOOL) sendMediaRecordPicture:(uint8_t)mass_storage_id;
- (BOOL) sendMaxAltitude:(float)current;
- (BOOL) sendMaxTilt:(float)current;
- (BOOL) sendMaxVerticalSpeed:(float)current;
- (BOOL) sendMaxRotationSpeed:(float)current;
- (BOOL) sendWheelsOn:(uint8_t)present;
- (BOOL) sendCutOutMode:(uint8_t)enable;
					
- (void) setRoll:(float)roll;
- (void) setPitch:(float)pitch;
- (void) setYaw:(float)yaw;
- (void) setGaz:(float)gaz;
- (void) setFlag:(uint8_t)flag;

@end

