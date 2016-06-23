//
//  JSDrone.h
//  SDKSample
//

#import <Foundation/Foundation.h>
#import <libARController/ARController.h>
#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>

@class JSDrone;

@protocol JSDroneDelegate <NSObject>
@required
/**
 * Called when the connection to the drone did change
 * Called on the main thread
 * @param jumpingDrone the drone concerned
 * @param state the state of the connection
 */
- (void)jsDrone:(JSDrone*)jsDrone connectionDidChange:(eARCONTROLLER_DEVICE_STATE)state;

/**
 * Called when the battery charge did change
 * Called on the main thread
 * @param jumpingDrone the drone concerned
 * @param batteryPercent the battery remaining (in percent)
 */
- (void)jsDrone:(JSDrone*)jsDrone batteryDidChange:(int)batteryPercentage;

/**
 * Called when the video decoder should be configured
 * Called on separate thread
 * @param jumpingDrone the drone concerned
 * @param codec the codec information about the stream
 * @return true if configuration went well, false otherwise
 */
- (BOOL)jsDrone:(JSDrone*)jsDrone configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec;

/**
 * Called when a frame has been received
 * Called on separate thread
 * @param jumpingDrone the drone concerned
 * @param frame the frame received
 */
- (BOOL)jsDrone:(JSDrone*)jsDrone didReceiveFrame:(ARCONTROLLER_Frame_t*)frame;

/**
 * Called when the audio decoder should be configured
 * Called on separate thread
 * @param jumpingDrone the drone concerned
 * @param codec the codec information about the stream
 * @return true if configuration went well, false otherwise
 */
- (BOOL)jsDrone:(JSDrone*)jsDrone configureAudioDecoder:(ARCONTROLLER_Stream_Codec_t)codec;

/**
 * Called when a audio frame has been received
 * Called on separate thread
 * @param jumpingDrone the drone concerned
 * @param frame the frame received
 */
- (BOOL)jsDrone:(JSDrone*)jsDrone didReceiveAudioFrame:(ARCONTROLLER_Frame_t*)frame;

/**
 * Called before medias will be downloaded
 * Called on the main thread
 * @param jumpingDrone the drone concerned
 * @param nbMedias the number of medias that will be downloaded
 */
- (void)jsDrone:(JSDrone*)jsDrone didFoundMatchingMedias:(NSUInteger)nbMedias;

/**
 * Called each time the progress of a download changes
 * Called on the main thread
 * @param jumpingDrone the drone concerned
 * @param mediaName the name of the media
 * @param progress the progress of its download (from 0 to 100)
 */
- (void)jsDrone:(JSDrone*)jsDrone media:(NSString*)mediaName downloadDidProgress:(int)progress;

/**
 * Called when a media download has ended
 * Called on the main thread
 * @param jumpingDrone the drone concerned
 * @param mediaName the name of the media
 */
- (void)jsDrone:(JSDrone*)jsDrone mediaDownloadDidFinish:(NSString*)mediaName;


/**
 * Called when the audio state did change
 * Called on the main thread
 * @param jumpingDrone the drone concerned
 * @param state the state of the audio
 */
- (void)jsDrone:(JSDrone*)jsDrone audioStateDidChangeWithInput:(BOOL)inputEnabled output:(BOOL)outputEnabled;

@end

@interface JSDrone : NSObject

@property (nonatomic, weak) id<JSDroneDelegate>delegate;

- (id)initWithService:(ARService*)service;
- (void)connect;
- (void)disconnect;
- (eARCONTROLLER_DEVICE_STATE)connectionState;

- (void)takePicture;
- (void)setTurn:(uint8_t)turn;
- (void)setSpeed:(uint8_t)speed;
- (void)setFlag:(uint8_t)flag;
- (void)downloadMedias;
- (void)cancelDownloadMedias;
- (void)setAudioStreamEnabledWithInput:(BOOL)inputEnabled output:(BOOL)outputEnabled;
- (void)sendAudioStreamFrame:(uint8_t*)data withSize:(size_t)size;
- (BOOL)hasInputAudioStream;
- (BOOL)hasOutputAudioStream;
@end
