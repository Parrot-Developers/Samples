//
//  BebopVideoView.h
//  SDKSample
//

#import <UIKit/UIKit.h>
#import <libARController/ARController.h>

@interface H264VideoView : UIView

- (BOOL)configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec;
- (BOOL)displayFrame:(ARCONTROLLER_Frame_t *)frame;

@end
