//
//  SDCardModule.h
//  SDKSample
//

#import <Foundation/Foundation.h>
#include <libARUtils/ARUtils.h>
#import <libARDiscovery/ARDISCOVERY_Device.h>

@class SDCardModule;

@protocol SDCardModuleDelegate <NSObject>
@required
/**
 * Called before medias will be downloaded
 * Called on the main thread
 * @param module the sdcard module
 * @param nbMedias the number of medias that will be downloaded
 */
- (void)sdcardModule:(SDCardModule*)module didFoundMatchingMedias:(NSUInteger)nbMedias;

/**
 * Called each time the progress of a download changes
 * Called on the main thread
 * @param module the sdcard module
 * @param mediaName the name of the media
 * @param progress the progress of its download (from 0 to 100)
 */
- (void)sdcardModule:(SDCardModule*)module media:(NSString*)mediaName downloadDidProgress:(int)progress;

/**
 * Called when a media download has ended
 * Called on the main thread
 * @param module the sdcard module
 * @param mediaName the name of the media
 */
- (void)sdcardModule:(SDCardModule*)module mediaDownloadDidFinish:(NSString*)mediaName;
@end

@interface SDCardModule : NSObject

@property (nonatomic, weak) id<SDCardModuleDelegate>delegate;

- (id)initWithDiscoveryDevice:(ARDISCOVERY_Device_t *)discoveryDevice;
- (void)getFlightMedias:(NSString*)runId;
- (void)getTodaysFlightMedias;
- (void)cancelGetMedias;

@end
