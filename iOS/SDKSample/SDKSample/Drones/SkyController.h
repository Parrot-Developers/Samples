//
//  SkyController.h
//  SDKSample
//

#import <Foundation/Foundation.h>
#import <libARController/ARController.h>
#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>

@class SkyController;

@protocol SkyControllerDelegate <NSObject>
@required
/**
 * Called when the connection to the skyController did change
 * Called on the main thread
 * @param sc the skyController concerned
 * @param state the state of the connection
 */
- (void)skyController:(SkyController*)sc scConnectionDidChange:(eARCONTROLLER_DEVICE_STATE)state;

/**
 * Called when the connection to the drone did change
 * Called on the main thread
 * @param sc the skyController concerned
 * @param state the state of the connection
 */
- (void)skyController:(SkyController*)sc droneConnectionDidChange:(eARCONTROLLER_DEVICE_STATE)state;

/**
 * Called when the skyController battery charge did change
 * Called on the main thread
 * @param sc the SkyController concerned
 * @param batteryPercent the battery remaining (in percent)
 */
- (void)skyController:(SkyController*)sc scBatteryDidChange:(int)batteryPercentage;

/**
 * Called when the drone battery charge did change
 * Called on the main thread
 * @param sc the SkyController concerned
 * @param batteryPercent the battery remaining (in percent)
 */
- (void)skyController:(SkyController*)sc droneBatteryDidChange:(int)batteryPercentage;

/**
 * Called when the piloting state did change
 * Called on the main thread
 * @param sc the SkyController concerned
 * @param batteryPercent the piloting state of the drone
 */
- (void)skyController:(SkyController*)sc flyingStateDidChange:(eARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE)state;

/**
 * Called when the video decoder should be configured
 * Called on separate thread
 * @param sc the SkyController concerned
 * @param codec the codec information about the stream
 * @return true if configuration went well, false otherwise
 */
- (BOOL)skyController:(SkyController*)sc configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec;

/**
 * Called when a frame has been received
 * Called on separate thread
 * @param sc the SkyController concerned
 * @param frame the frame received
 */
- (BOOL)skyController:(SkyController*)sc didReceiveFrame:(ARCONTROLLER_Frame_t*)frame;

/**
 * Called before medias will be downloaded
 * Called on the main thread
 * @param sc the SkyController concerned
 * @param nbMedias the number of medias that will be downloaded
 */
- (void)skyController:(SkyController*)sc didFoundMatchingMedias:(NSUInteger)nbMedias;

/**
 * Called each time the progress of a download changes
 * Called on the main thread
 * @param sc the SkyController concerned
 * @param mediaName the name of the media
 * @param progress the progress of its download (from 0 to 100)
 */
- (void)skyController:(SkyController*)sc media:(NSString*)mediaName downloadDidProgress:(int)progress;

/**
 * Called when a media download has ended
 * Called on the main thread
 * @param sc the SkyController concerned
 * @param mediaName the name of the media
 */
- (void)skyController:(SkyController*)sc mediaDownloadDidFinish:(NSString*)mediaName;

@end

@interface SkyController : NSObject

@property (nonatomic, weak) id<SkyControllerDelegate>delegate;

- (id)initWithService:(ARService*)service;
- (void)connect;
- (void)disconnect;
- (eARCONTROLLER_DEVICE_STATE)connectionState;
- (eARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE)flyingState;

- (void)emergency;
- (void)takeOff;
- (void)land;
- (void)takePicture;
- (void)downloadMedias;
- (void)cancelDownloadMedias;
@end
