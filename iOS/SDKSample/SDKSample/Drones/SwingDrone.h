//
//  SwingDrone.h
//  SDKSample
//

#import <Foundation/Foundation.h>
#import <libARController/ARController.h>
#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>

@class SwingDrone;

@protocol SwingDroneDelegate <NSObject>
@required
/**
 * Called when the connection to the drone did change
 * Called on the main thread
 * @param swingDrone the drone concerned
 * @param state the state of the connection
 */
- (void)swingDrone:(SwingDrone*)swingDrone connectionDidChange:(eARCONTROLLER_DEVICE_STATE)state;

/**
 * Called when the battery charge did change
 * Called on the main thread
 * @param SwingDrone the drone concerned
 * @param batteryPercent the battery remaining (in percent)
 */
- (void)swingDrone:(SwingDrone*)swingDrone batteryDidChange:(int)batteryPercentage;

/**
 * Called when the piloting state did change
 * Called on the main thread
 * @param swingDrone the drone concerned
 * @param state the piloting state of the drone
 */
- (void)swingDrone:(SwingDrone*)swingDrone flyingStateDidChange:(eARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE)state;

/**
 * Called when the flying mode did change
 * Called on the main thread
 * @param swingDrone the drone concerned
 * @param mode the flying mode of the drone
 */
- (void)swingDrone:(SwingDrone*)swingDrone flyingModeDidChange:(eARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGMODECHANGED_MODE)mode;

/**
 * Called before medias will be downloaded
 * Called on the main thread
 * @param swingDrone the drone concerned
 * @param nbMedias the number of medias that will be downloaded
 */
- (void)swingDrone:(SwingDrone*)swingDrone didFoundMatchingMedias:(NSUInteger)nbMedias;

/**
 * Called each time the progress of a download changes
 * Called on the main thread
 * @param swingDrone the drone concerned
 * @param mediaName the name of the media
 * @param progress the progress of its download (from 0 to 100)
 */
- (void)swingDrone:(SwingDrone*)swingDrone media:(NSString*)mediaName downloadDidProgress:(int)progress;

/**
 * Called when a media download has ended
 * Called on the main thread
 * @param swingDrone the drone concerned
 * @param mediaName the name of the media
 */
- (void)swingDrone:(SwingDrone*)swingDrone mediaDownloadDidFinish:(NSString*)mediaName;

@end

@interface SwingDrone : NSObject

@property (nonatomic, weak) id<SwingDroneDelegate>delegate;

- (id)initWithService:(ARService*)service;
- (void)connect;
- (void)disconnect;
- (eARCONTROLLER_DEVICE_STATE)connectionState;
- (eARCOMMANDS_MINIDRONE_PILOTINGSTATE_FLYINGSTATECHANGED_STATE)flyingState;

- (void)emergency;
- (void)takeOff;
- (void)land;
- (void)takePicture;
- (void)changeFlyingMode:(eARCOMMANDS_MINIDRONE_PILOTING_FLYINGMODE_MODE)flyingMode;
- (void)setPitch:(uint8_t)pitch;
- (void)setRoll:(uint8_t)roll;
- (void)setYaw:(uint8_t)yaw;
- (void)setGaz:(uint8_t)gaz;
- (void)setFlag:(uint8_t)flag;
- (void)downloadMedias;
- (void)cancelDownloadMedias;
@end
