//
//  AudioStreamAUBackend.h
//

#import <Foundation/Foundation.h>

@class AudioStreamAUBackend;

@protocol AudioStreamAUBackendRecordDelegate <NSObject>
@required
- (void)audioStreamAUBackend:(AudioStreamAUBackend*)backend didAcquireNewBuffer:(uint8_t*)buf withSize:(size_t)size;
@end

/** Audio streaming backend using iOS Audio Unit API for both recording and playback.
 */
@interface AudioStreamAUBackend : NSObject
+ (AudioStreamAUBackend *)sharedInstance;
@property (readonly) int playbackSampleRate;
@property (readonly) int recordSampleRate;

- (void)queueBuffer:(void*)buf withSize:(size_t)size;

- (BOOL)startPlayingWithSampleRate:(int) sampleRate;
- (void)stopPlaying;

- (BOOL)startRecording:(id<AudioStreamAUBackendRecordDelegate>)recordDelegate withSampleRate:(int)sampleRate;
- (void)stopRecording;

@end
