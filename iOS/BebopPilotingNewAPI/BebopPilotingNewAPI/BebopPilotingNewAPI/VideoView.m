//
//  VideoView.m
//  BebopPilotingNewAPI
//
//  Created by Djavan Bertrand on 20/07/2015.
//  Copyright (c) 2015 Parrot. All rights reserved.
//

#import "VideoView.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface VideoView()

@property (nonatomic, retain) AVSampleBufferDisplayLayer *videoLayer;
@property (nonatomic, assign) CMVideoFormatDescriptionRef formatDesc;
@property (nonatomic, assign) int spsSize;
@property (nonatomic, assign) int ppsSize;
@property (nonatomic, assign) BOOL canDisplayVideo;
@property (nonatomic, assign) BOOL shouldWaitForIFrame;

@end

@implementation VideoView

- (id)init
{
    self = [super init];
    if (self)
    {
        [self customInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        [self customInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self)
    {
        [self customInit];
    }
    return self;
}

- (void)customInit
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enteredBackground:) name:UIApplicationDidEnterBackgroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterForeground:) name:UIApplicationWillEnterForegroundNotification object: nil];
    
    _canDisplayVideo = YES;
    _shouldWaitForIFrame = YES;
    
    // create CVSampleBufferDisplayLayer and add it to the view
    _videoLayer = [[AVSampleBufferDisplayLayer alloc] init];
    _videoLayer.frame = self.frame;
    _videoLayer.bounds = self.bounds;
    _videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    _videoLayer.backgroundColor = [[UIColor blackColor] CGColor];
    
    [[self layer] addSublayer:_videoLayer];
}

-(void)dealloc
{
    if (NULL != _formatDesc)
    {
        CFRelease(_formatDesc);
        _formatDesc = NULL;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name: UIApplicationDidEnterBackgroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name: UIApplicationWillEnterForegroundNotification object: nil];
}

- (void)layoutSubviews
{
    _videoLayer.frame = self.bounds;
}

- (BOOL)sps:(uint8_t *)spsBuffer spsSize:(int)spsSize pps:(uint8_t *)ppsBuffer ppsSize:(int) ppsSize
{
    OSStatus osstatus;
    NSError *error = nil;
    BOOL failed = NO;
    
    if (_canDisplayVideo)
    {
        
        uint8_t* props[] = {spsBuffer+4, ppsBuffer+4};
        
        size_t sizes[] = {spsSize-4, ppsSize-4};
        
        if (NULL != _formatDesc)
        {
            CFRelease(_formatDesc);
            _formatDesc = NULL;
        }
        
        osstatus = CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL, 2, (const uint8_t *const*)props, sizes, 4, &_formatDesc);
        if (osstatus != kCMBlockBufferNoErr)
        {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                        code:osstatus
                                    userInfo:nil];
            
            NSLog(@"Error creating the format description = %@", [error description]);
            [self cleanFormatDesc];
            failed = YES;
        }
    }
    
    return failed;
}

- (BOOL)displayFrame:(ARCONTROLLER_Frame_t *)frame
{
    BOOL failed = NO;
    
    if (_canDisplayVideo)
    {
        _shouldWaitForIFrame = NO;
        
        CMBlockBufferRef blockBufferRef = NULL;
        //CMSampleTimingInfo timing = kCMTimingInfoInvalid;
        CMSampleBufferRef sampleBufferRef = NULL;
        
        OSStatus osstatus;
        NSError *error = nil;
        
        // on error, flush the video layer and wait for the next iFrame
        if (!_videoLayer || [_videoLayer status] == AVQueuedSampleBufferRenderingStatusFailed)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, "PilotingViewController", "Video layer status is failed : flush and wait for next iFrame");
            [self cleanFormatDesc];
            failed = YES;
        }
    
        if (!failed)
        {
            osstatus  = CMBlockBufferCreateWithMemoryBlock(CFAllocatorGetDefault(), frame->data, frame->used, kCFAllocatorNull, NULL, 0, frame->used, 0, &blockBufferRef);
            if (osstatus != kCMBlockBufferNoErr)
            {
                error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                            code:osstatus
                                        userInfo:nil];
                
                NSLog(@"Error creating the block buffer = %@", [error description]);
                failed = YES;
            }
        }
        
        if (!failed)
        {
            const size_t sampleSize = frame->used;
            osstatus = CMSampleBufferCreate(kCFAllocatorDefault, blockBufferRef, true, NULL, NULL, _formatDesc, 1, 0, NULL, 1, &sampleSize, &sampleBufferRef);
            if (osstatus != noErr)
            {
                failed = YES;
                error = [NSError errorWithDomain:NSOSStatusErrorDomain
                                            code:osstatus
                                        userInfo:nil];
                
                NSLog(@"Error creating the sample buffer = %@", [error description]);
            }
        }
        
        if (!failed)
        {
            // add the attachment which says that sample should be displayed immediately
            CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBufferRef, YES);
            CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
            CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
        }
        
        if (!failed && [_videoLayer status] != AVQueuedSampleBufferRenderingStatusFailed && _videoLayer.isReadyForMoreMediaData)
        {
            dispatch_sync(dispatch_get_main_queue(), ^{
                if (_canDisplayVideo)
                {
                    [_videoLayer enqueueSampleBuffer:sampleBufferRef];
                }
            });
        }
        
        // free memory
        
        if (NULL != sampleBufferRef)
        {
            CMSampleBufferInvalidate(sampleBufferRef);
            CFRelease(sampleBufferRef);
            sampleBufferRef = NULL;
        }
        
        if (NULL != blockBufferRef)
        {
            CFRelease(blockBufferRef);
            blockBufferRef = NULL;
        }
    }
    
    return failed;
}

- (void)cleanFormatDesc
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (NULL != _formatDesc)
        {
            ARSAL_PRINT(ARSAL_PRINT_ERROR, "PilotingViewController", "hardware decode view : will flush and remove image");
            [_videoLayer flushAndRemoveImage];
            ARSAL_PRINT(ARSAL_PRINT_ERROR, "PilotingViewController", "hardware decode view : will release format desc");
            CFRelease(_formatDesc);
            _formatDesc = NULL;
        }
    });
}

#pragma mark - notifications
- (void)enteredBackground:(NSNotification*)notification
{
    NSLog(@"enteredBackground ... ");
    _canDisplayVideo = NO;
    _shouldWaitForIFrame = YES;
}

- (void)enterForeground:(NSNotification*)notification
{
    NSLog(@"enterForeground ... ");
    _canDisplayVideo = YES;
}


@end
