//
//  MiniDrone.h
//  SDKSample
//

#import <Foundation/Foundation.h>
#import <libARController/ARController.h>
#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>

@class MiniDrone;

@protocol MiniDroneDelegate <NSObject>
@required
/**
 * Called when the connection to the drone did change
 * Called on the main thread
 * @param miniDrone the drone concerned
 * @param state the state of the connection
 */
- (void)miniDrone:(MiniDrone*)miniDrone connectionDidChange:(eARCONTROLLER_DEVICE_STATE)state;

/**
 * Called when the battery charge did change
 * Called on the main thread
 * @param MiniDrone the drone concerned
 * @param batteryPercent the battery remaining (in percent)
 */
- (void)miniDrone:(MiniDrone*)miniDrone batteryDidChange:(int)batteryPercentage;

/**
 * Called when the piloting state did change
 * Called on the main thread
 * @param miniDrone the drone concerned
 * @param batteryPercent the piloting state of the drone
 */
- (void)miniDrone:(MiniDrone*)miniDrone flyingStateDidChange:(eARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE)state;

/**
 * Called before medias will be downloaded
 * Called on the main thread
 * @param miniDrone the drone concerned
 * @param nbMedias the number of medias that will be downloaded
 */
- (void)miniDrone:(MiniDrone*)miniDrone didFoundMatchingMedias:(NSUInteger)nbMedias;

/**
 * Called each time the progress of a download changes
 * Called on the main thread
 * @param miniDrone the drone concerned
 * @param mediaName the name of the media
 * @param progress the progress of its download (from 0 to 100)
 */
- (void)miniDrone:(MiniDrone*)miniDrone media:(NSString*)mediaName downloadDidProgress:(int)progress;

/**
 * Called when a media download has ended
 * Called on the main thread
 * @param miniDrone the drone concerned
 * @param mediaName the name of the media
 */
- (void)miniDrone:(MiniDrone*)miniDrone mediaDownloadDidFinish:(NSString*)mediaName;

@end

@interface MiniDrone : NSObject

@property (nonatomic, weak) id<MiniDroneDelegate>delegate;

- (id)initWithService:(ARService*)service;
- (void)connect;
- (void)disconnect;
- (eARCONTROLLER_DEVICE_STATE)connectionState;
- (eARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE)flyingState;

- (void)emergency;
- (void)takeOff;
- (void)land;
- (void)takePicture;
- (void)setPitch:(uint8_t)pitch;
- (void)setRoll:(uint8_t)roll;
- (void)setYaw:(uint8_t)yaw;
- (void)setGaz:(uint8_t)gaz;
- (void)setFlag:(uint8_t)flag;
- (void)downloadMedias;
- (void)cancelDownloadMedias;
@end
