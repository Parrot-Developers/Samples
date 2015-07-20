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


- (void)displayFrame:(ARCONTROLLER_Frame_t *)frame
{
    if (_canDisplayVideo)
    {
        if (!_shouldWaitForIFrame || frame->isIFrame)
        {
            _shouldWaitForIFrame = NO;
            
            CMBlockBufferRef blockBufferRef = NULL;
            //CMSampleTimingInfo timing = kCMTimingInfoInvalid;
            CMSampleBufferRef sampleBufferRef = NULL;
            BOOL failed = NO;
            OSStatus osstatus;
            NSError *error = nil;
            long dataLength = 0;
            long blockLength = 0;
            int offset = 0;
            
            uint8_t *data = NULL;
            uint8_t *pps = NULL;
            uint8_t *sps = NULL;
            
            // on error, flush the video layer and wait for the next iFrame
            if (!_videoLayer || [_videoLayer status] == AVQueuedSampleBufferRenderingStatusFailed)
            {
                ARSAL_PRINT(ARSAL_PRINT_ERROR, "PilotingViewController", "Video layer status is failed : flush and wait for next iFrame");
                [self cleanFormatDesc];
            }
            
            // if format description is not init yet and we are not receiving an iFrame
            if (!frame->isIFrame && _formatDesc == NULL)
            {
                failed = YES;
            }
            
            if (!failed && frame->isIFrame)
            {
                int searchIndex = 0;
                
                // we'll need to search the "00 00 00 01" pattern to find each header size
                // Search start at index 4 to avoid finding the SPS "00 00 00 01" tag
                for (searchIndex = 4; searchIndex <= frame->used - 4; searchIndex ++)
                {
                    if (0 == frame->data[searchIndex  ] &&
                        0 == frame->data[searchIndex+1] &&
                        0 == frame->data[searchIndex+2] &&
                        1 == frame->data[searchIndex+3])
                    {
                        break;  // PPS header found
                    }
                }
                _spsSize = searchIndex;
                
                // Search start at index 4 to avoid finding the SPS "00 00 00 01" tag
                for (searchIndex = _spsSize+4; searchIndex <= frame->used - 4; searchIndex ++)
                {
                    if (0 == frame->data[searchIndex  ] &&
                        0 == frame->data[searchIndex+1] &&
                        0 == frame->data[searchIndex+2] &&
                        1 == frame->data[searchIndex+3])
                    {
                        break;  // frame header found
                    }
                }
                
                _ppsSize = searchIndex - _spsSize;
                
                sps = malloc(_spsSize-4);
                pps = malloc(_ppsSize-4);
                if (NULL == sps || NULL == pps)
                {
                    ARSAL_PRINT(ARSAL_PRINT_ERROR, "PilotingViewController", "Unable to allocate SPS/PPS buffers");
                    failed = YES;
                }
                
            }
            
            if (!failed && frame->isIFrame)
            {
                memcpy (sps, &frame->data[4], _spsSize-4);
                memcpy (pps, &frame->data[_spsSize+4], _ppsSize-4);
                
                uint8_t* props[] = {sps, pps};
                
                size_t sizes[] = {_spsSize-4, _ppsSize-4};
                
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
            
            if (!failed)
            {
                if (frame->isIFrame)
                {
                    offset = _spsSize + _ppsSize;
                    blockLength = frame->used * sizeof(char) - offset;
                    data = malloc(blockLength);
                }
                else
                {
                    offset = 0;
                    blockLength = frame->used * sizeof(char);
                    data = malloc(blockLength);
                }
                
                if (data == NULL)
                {
                    ARSAL_PRINT(ARSAL_PRINT_ERROR, "PilotingViewController", "Unable to allocate SPS/PPS buffers");
                    failed = YES;
                }
            }
            
            if (!failed)
            {
                data = memcpy(data, &frame->data[offset], blockLength);
                
                dataLength = blockLength - 4;
                
                // replace first 4 bytes with the length
                uint32_t dataLength32 = htonl (dataLength);
                memcpy ( data, &dataLength32, sizeof (uint32_t));
                
                osstatus  = CMBlockBufferCreateWithMemoryBlock(CFAllocatorGetDefault(), data, blockLength, kCFAllocatorNull, NULL, 0, dataLength + 4, 0, &blockBufferRef);
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
                const size_t sampleSize = dataLength + 4;
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
            if (NULL != data)
            {
                free (data);
                data = NULL;
            }
            
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
            
            if (NULL != sps)
            {
                free (sps);
                sps = NULL;
            }
            
            if (NULL != pps)
            {
                free (pps);
                pps = NULL;
            }
        }
    }
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
