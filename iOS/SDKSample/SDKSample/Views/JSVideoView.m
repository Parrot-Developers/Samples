//
//  JSVideoView.m
//  SDKSample
//

#import "JSVideoView.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface JSVideoView ()


@end
@implementation JSVideoView

- (id)init {
    self = [super init];
    if (self) {
        [self customInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self customInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self customInit];
    }
    return self;
}

- (void)customInit {
    [self setBackgroundColor:[UIColor blackColor]];
    [self setContentMode:UIViewContentModeScaleAspectFit];
}

- (BOOL)configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec {
    return YES;
}

- (BOOL)displayFrame:(ARCONTROLLER_Frame_t *)frame
{
    BOOL success = YES;
    NSData *imgData = [NSData dataWithBytes:frame->data length:frame->used];
    UIImage *image = [UIImage imageWithData:imgData];
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.image = image;
    });
    
    return success;
}

@end
