//
//  JSVideoView.h
//  SDKSample
//

#import <UIKit/UIKit.h>
#import <libARController/ARController.h>

@interface JSVideoView : UIImageView

- (BOOL)configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec;
- (BOOL)displayFrame:(ARCONTROLLER_Frame_t *)frame;

@end
