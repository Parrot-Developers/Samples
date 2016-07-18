//
//  AudioStreamAUBackend.m
//

#import <AVFoundation/AVFoundation.h>
#import "AudioStreamAUBackend.h"

#define AU_BACKEND_DEBUG_ENABLE 0
#define AU_BACKEND_DISABLE_VOICE_PROCESSING 0
#define AU_BACKEND_DISABLE_AUTOMATIC_GAIN_CONTROL 0

#if AU_BACKEND_DEBUG_ENABLE
#define DBG(...) do { NSLog(__VA_ARGS__); } while (0);
#else
#define DBG(...) while (0) {;};
#endif

typedef struct BackendBufferDescriptor {
    void* data; /** Pointer to the buffer data. Buffer is unused if NULL. */
    size_t totalSize; /** Total allocated size for the buffer. */
    size_t consumedSize; /** Size of the buffer which was already consumed. */
} BackendBufferDescriptor;

static const int kMaxPlaybackAudioBuffers = 40;
static const int kRecordBufferSize = 256;

static const int kAudioStreamAUBackendPlayMode = 1 << 0;
static const int kAudioStreamAUBackendRecordMode = 1 << 1;

@interface AudioStreamAUBackend () {
@public
    NSRecursiveLock *modeLock;
    int activeModes;
    AudioUnit ioUnit;
    id<AudioStreamAUBackendRecordDelegate> recordDelegate;
    BackendBufferDescriptor *playbackBuffers;
    NSPointerArray *playbackBuffersQueue;
    NSRecursiveLock *playbackBuffersLock;
}

@property (nonatomic) uint8_t *rcFrame;
@property (nonatomic) size_t rcFrameSize;

- (void)playbackBuffersGC;
- (void)fillRecordingFrame:(uint8_t*)buf withSize:(size_t)size;
@end

static OSStatus audio_render_input_notify_callback (void *inRefCon, AudioUnitRenderActionFlags *ioActionsFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    assert(ioActionsFlags != NULL);
    if ((*ioActionsFlags & kAudioUnitRenderAction_PostRender) != 0)
        return 0;

    static NSTimeInterval lastTimeCalled = 0.0;
    AudioStreamAUBackend* self = (__bridge AudioStreamAUBackend*)inRefCon;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    OSStatus status = 0;

    DBG(@"%@: Audio output input render callback. inNumberFrames:%i ioData:%p\n", [self class], (unsigned int)inNumberFrames, ioData);
    lastTimeCalled = now;

    AudioBufferList bufList = {
        .mNumberBuffers = 1,
        .mBuffers = {
            {
                1,
                inNumberFrames * sizeof(SInt16),
                NULL,
            },
        },
    };

    AudioUnitRenderActionFlags flags = 0;
    status = AudioUnitRender(self->ioUnit, &flags, inTimeStamp, inBusNumber, inNumberFrames, &bufList);
    if (status != 0)
    {
        NSLog(@"%@: AudioUnitRender() failed: %i", [self class], (int)status);
    }
    else if (self->recordDelegate != nil)
    {
        // fill the regarding buffer
        [self fillRecordingFrame:bufList.mBuffers[0].mData withSize:bufList.mBuffers[0].mDataByteSize];
    }

    return 0;
}

static OSStatus audio_render_output_input_callback (void *inRefCon, AudioUnitRenderActionFlags *ioActionsFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    assert(inRefCon != NULL);
    assert(ioActionsFlags != NULL);
    AudioStreamAUBackend *self = (__bridge AudioStreamAUBackend*)inRefCon;

    DBG(@"%@: Render callback called with flags: %i, expecting %i bytes.\n", [self class], (unsigned int)*ioActionsFlags, (int)(inNumberFrames * 2));

    if (*ioActionsFlags == 0) {
        BOOL scheduleGC = NO;

        // FIXME: Get rid of theses locks while still being thread-safe.
        [self->playbackBuffersLock lock];

        size_t availableBytes = 0;
        for (int i = 0; i < self->playbackBuffersQueue.count; i ++)
        {
            BackendBufferDescriptor *desc = [self->playbackBuffersQueue pointerAtIndex:i];
            if (desc->data != NULL)
            {
                availableBytes += (desc->totalSize - desc->consumedSize);
            }
        }
        DBG(@"%@: Render callback has %i bytes available.\n", [self class], (int)availableBytes);

        size_t requestedBytes = inNumberFrames * 2;
        if (availableBytes < requestedBytes)
        {
            *ioActionsFlags |= kAudioUnitRenderAction_OutputIsSilence;
        }
        else
        {
            size_t outOffset = 0;
            while (outOffset < requestedBytes)
            {
                BackendBufferDescriptor *desc = [self->playbackBuffersQueue pointerAtIndex:0];
                assert(desc != NULL);
                assert(desc->data != NULL);
                assert(desc->consumedSize <= desc->totalSize);
                if (desc->consumedSize < desc->totalSize) {
                    size_t size = desc->totalSize - desc->consumedSize;
                    if (size > requestedBytes - outOffset)
                    {
                        size = requestedBytes - outOffset;
                    }
                    memcpy(ioData->mBuffers[0].mData + outOffset, desc->data + desc->consumedSize, size);
                    desc->consumedSize += size;
                    assert(desc->consumedSize <= desc->totalSize);
                    outOffset += size;
                }
                // Remove buffer from queue if all its data was consumed.
                if (desc->consumedSize == desc->totalSize)
                {
                    [self->playbackBuffersQueue removePointerAtIndex:0];
                    scheduleGC = YES;
                }
            }
            DBG(@"%@: %i bytes returned from render callback.\n", [self class], (int)requestedBytes);
        }

        [self->playbackBuffersLock unlock];

        if (scheduleGC)
        {
            [self playbackBuffersGC];
        }
    }

    return 0;
}

@implementation AudioStreamAUBackend

- (void)myInit
{
    modeLock = [[NSRecursiveLock alloc] init];
    activeModes = 0;
    ioUnit = NULL;
    recordDelegate = nil;
    playbackBuffersQueue = [[NSPointerArray alloc] initWithOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)];
    playbackBuffers = calloc(kMaxPlaybackAudioBuffers, sizeof(BackendBufferDescriptor));
    playbackBuffersLock = [[NSRecursiveLock alloc] init];
    _playbackSampleRate = _recordSampleRate = 0;
    _rcFrame = malloc(kRecordBufferSize);
    _rcFrameSize = 0;
}

+ (AudioStreamAUBackend *)sharedInstance
{
    static AudioStreamAUBackend *sharedAudioStreamAUBackend = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedAudioStreamAUBackend = [[AudioStreamAUBackend alloc] init];
        [sharedAudioStreamAUBackend myInit];
    });

    return sharedAudioStreamAUBackend;
}

/** Update backend state depending on the requested modes. */
- (BOOL)updateBackendState:(int)reqModes
{
    BOOL retval = YES;
    OSStatus status = 0;

    [modeLock lock];

    if (reqModes == activeModes) {
        DBG(@"%@: updateBackendState: Nothing to do.\n", [self class]);
        goto unlock_and_return; // Nothing to do.
    }

    /* Create the IO unit and audio session if needed. */
    if (retval && reqModes != 0 && activeModes == 0)
    {
        AudioComponentDescription ioUnitDescription = {0};

        ioUnitDescription.componentType = kAudioUnitType_Output;
        ioUnitDescription.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
        ioUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
        ioUnitDescription.componentFlags = 0;
        ioUnitDescription.componentFlagsMask = 0;

        if (retval) {
            AudioComponent ioComponent = AudioComponentFindNext(NULL, &ioUnitDescription);
            status = AudioComponentInstanceNew(ioComponent, &ioUnit);
            if (status != 0) {
                NSLog(@"%@: Failed to instantiate IO unit: %i\n", [self class], (int)status);
                retval = NO;
            }
        }

        // Disable all I/O by default.
        UInt32 noValue = 0;
        if (retval) {
            status = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &noValue, sizeof(noValue));
            if (status != 0)
            {
                NSLog(@"%@: Failed to set IO unit input EnableIO property: %i\n", [self class], (int)status);
                retval = NO;
            }
        }
        if (retval) {
            status = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &noValue, sizeof(noValue));
            if (status != 0)
            {
                NSLog(@"%@: Failed to set IO unit output EnableIO property: %i\n", [self class], (int)status);
                retval = NO;
            }
        }
    }
    else if (retval && reqModes != activeModes)
    {
        /* We're going to change the IO unit parameters so we need to stop it first. */
        if (status == 0 && ioUnit != NULL) {
            status = AudioOutputUnitStop(ioUnit);
            if (status != 0) {
                NSLog(@"%@: AudioOutputUnitStop() failed: %i\n", [self class], (int)status);
            }
        }
        if (ioUnit != NULL) {
            status = AudioUnitUninitialize(ioUnit);
            if (status != 0) {
                NSLog(@"%@: AudioUnitUninitialize() failed: %i\n", [self class], (int)status);
            }
        }
    }

    /* Enable/disable play mode. */
    if (retval && (reqModes & kAudioStreamAUBackendPlayMode) && !(activeModes & kAudioStreamAUBackendPlayMode))
    {
        UInt32 yesValue = 1;
        AudioStreamBasicDescription playbackStreamDesc = {0};
        playbackStreamDesc.mSampleRate = _playbackSampleRate;
        playbackStreamDesc.mFormatID = kAudioFormatLinearPCM;
        playbackStreamDesc.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        playbackStreamDesc.mFramesPerPacket = 1;
        playbackStreamDesc.mChannelsPerFrame = 1;
        playbackStreamDesc.mBytesPerFrame = 2;
        playbackStreamDesc.mBytesPerPacket = 2;
        playbackStreamDesc.mBitsPerChannel = 16;
        playbackStreamDesc.mBitsPerChannel = 16;

        DBG(@"%@: Playback sample rate: %f channels: %u\n", [self class], playbackStreamDesc.mSampleRate, (unsigned int)playbackStreamDesc.mChannelsPerFrame);

        // Enable output.
        if (retval) {
            status = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &yesValue, sizeof(yesValue));
            if (status != 0)
            {
                NSLog(@"%@: Failed to enable IO unit output EnableIO property: %i\n", [self class], (int)status);
                retval = NO;
            }
        }
        // Set output render callback.
        if (retval) {
            AURenderCallbackStruct renderCallback = {0};
            renderCallback.inputProc = audio_render_output_input_callback;
            renderCallback.inputProcRefCon = (__bridge void*)self;
            status = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0, &renderCallback, sizeof(renderCallback));
            if (status != 0)
            {
                NSLog(@"%@: Failed to set IO unit RenderCallback: %i\n", [self class], (int)status);
                retval = NO;
            }
        }
        // Enable buffer allocation.
        if (retval) {
            status = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Input, 0, &yesValue, sizeof(yesValue));
            if (status != 0)
            {
                NSLog(@"%@: Failed to set IO output unit input ShouldAllocateBuffer property: %i\n", [self class], (int)status);
                retval = NO;
            }
        }
        // Set output format.
        if (retval) {
            status = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &playbackStreamDesc, sizeof(playbackStreamDesc));
            if (status != 0)
            {
                NSLog(@"%@: Failed to set IO output unit input StreamFormat property: %i\n", [self class], (int)status);
                retval = NO;
            }
        }
    }
    else if (retval && !(reqModes & kAudioStreamAUBackendPlayMode) && (activeModes & kAudioStreamAUBackendPlayMode))
    {
        UInt32 noValue = 0;
        // Disable output.
        if (retval) {
            status = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &noValue, sizeof(noValue));
            if (status != 0)
            {
                NSLog(@"%@: Failed to disable IO unit output EnableIO property: %i\n", [self class], (int)status);
                retval = NO;
            }
        }
        // Clear output render callback.
        if (retval) {
            AURenderCallbackStruct renderCallback = {0};
            status = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0, &renderCallback, sizeof(renderCallback));
            if (status != 0)
            {
                NSLog(@"%@: Failed to clear IO unit RenderCallback: %i\n", [self class], (int)status);
                retval = NO;
            }
        }
    }

    /* Enable/disable record mode. */
    if (retval && (reqModes & kAudioStreamAUBackendRecordMode) && !(activeModes & kAudioStreamAUBackendRecordMode))
    {
        UInt32 yesValue = 1;
        AudioStreamBasicDescription recordStreamDesc = {0};
        recordStreamDesc.mSampleRate = _recordSampleRate;
        recordStreamDesc.mFormatID = kAudioFormatLinearPCM;
        recordStreamDesc.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        recordStreamDesc.mFramesPerPacket = 1;
        recordStreamDesc.mChannelsPerFrame = 1;
        recordStreamDesc.mBytesPerFrame = 2;
        recordStreamDesc.mBytesPerPacket = 2;
        recordStreamDesc.mBitsPerChannel = 16;

        DBG(@"%@: Record sample rate: %f channels: %u\n", [self class], recordStreamDesc.mSampleRate, (unsigned int)recordStreamDesc.mChannelsPerFrame);

        // Enable input.
        if (retval) {
            status = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &yesValue, sizeof(yesValue));
            if (status != 0)
            {
                NSLog(@"%@: Failed to enable IO unit input EnableIO property: %i\n", [self class], (int)status);
                retval = NO;
            }
        }
        // Set input callback.
        if (retval) {
            AURenderCallbackStruct renderCallback = {0};
            renderCallback.inputProc = audio_render_input_notify_callback;
            renderCallback.inputProcRefCon = (__bridge void*)self;
            status = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_SetInputCallback,kAudioUnitScope_Global, 0, &renderCallback, sizeof(renderCallback));
            if (status != 0)
            {
                NSLog(@"%@: Failed to set IO unit InputCallback: %i\n", [self class], (int)status);
                retval = NO;
            }
        }
        // Set input format.
        if (retval) {
            status = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &recordStreamDesc, sizeof(recordStreamDesc));
            if (status != 0)
            {
                NSLog(@"%@: Failed to set IO input unit output StreamFormat property: %i\n", [self class], (int)status);
                retval = NO;
            }
        }
    }
    else if (retval && !(reqModes & kAudioStreamAUBackendRecordMode) && (activeModes & kAudioStreamAUBackendRecordMode))
    {
        UInt32 noValue = 0;
        // Disable input.
        if (retval) {
            status = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &noValue, sizeof(noValue));
            if (status != 0)
            {
                NSLog(@"%@: Failed to disable IO unit input EnableIO property: %i\n", [self class], (int)status);
                retval = NO;
            }
        }
    }

    /* Start the IO unit if needed. */
    if (retval && reqModes != 0)
    {
#if AU_BACKEND_DISABLE_VOICE_PROCESSING	
        UInt32 vpValue = 1;
#else
        UInt32 vpValue = 0;
#endif
        if (retval) {
            status = AudioUnitSetProperty(ioUnit, kAUVoiceIOProperty_BypassVoiceProcessing, kAudioUnitScope_Global, 0, &vpValue, sizeof(vpValue));
            if (status != 0)
            {
                NSLog(@"%@: Failed to set BypassVoiceProcessing property: %i\n", [self class], (int)status);
                retval = NO;
            }
        }

#if AU_BACKEND_DISABLE_AUTOMATIC_GAIN_CONTROL
        UInt32 agcValue = 1;
#else
        UInt32 agcValue = 0;
#endif
        if (retval) {
            status = AudioUnitSetProperty(ioUnit, kAUVoiceIOProperty_VoiceProcessingEnableAGC, kAudioUnitScope_Global, 0, &agcValue, sizeof(agcValue));
            if (status != 0)
            {
                NSLog(@"%@: Failed to set VoiceProcessingEnableAGC property: %i\n", [self class], (int)status);
                retval = NO;
            }
        }

        // Initialize audio unit.
        if (retval) {
            status = AudioUnitInitialize(ioUnit);
            if (status != 0)
            {
                NSLog(@"%@: IO unit initialization failed: %i\n", [self class], (int)status);
                retval = NO;
            }
        }
        // Start IO unit.
        if (retval) {
            status = AudioOutputUnitStart(ioUnit);
            if (status != 0)
            {
                NSLog(@"%@: IO unit failed to start: %i\n", [self class], (int)status);
                retval = NO;
            }
        }
    }

    /* Destroy the IO unit and audio session if no longer needed.  */
    if (retval && reqModes == 0 &&  activeModes != 0)
    {
        // Stop and uninitialize IO unit.
        if (status == 0 && ioUnit != NULL) {
            status = AudioOutputUnitStop(ioUnit);
            if (status != 0) {
                NSLog(@"%@: AudioOutputUnitStop() failed: %i\n", [self class], (int)status);
            }
        }
        if (ioUnit != NULL) {
            status = AudioUnitUninitialize(ioUnit);
            if (status != 0) {
                NSLog(@"%@: AudioUnitUninitialize() failed: %i\n", [self class], (int)status);
            }
        }

        // Dispose of audio component (the IO unit).
        if (ioUnit != NULL) {
            status = AudioComponentInstanceDispose(ioUnit);
            ioUnit = NULL;
            if (status != 0)
            {
                NSLog(@"%@: AudioComponentInstanceDispose() failed: %i\n", [self class], (int)status);
            }
        }

        if (status != 0)
        {
            NSLog(@"%@: Something went wrong while stopping.\n", [self class]);
        }
    }

    if (retval) {
        activeModes = reqModes;
        DBG(@"%@: Backend state update successful.\n", [self class]);
    } else {
        DBG(@"%@: Backend state update failed.\n", [self class]);
    }

unlock_and_return:
    [modeLock unlock];

    return retval;
}

- (void)playbackBuffersGC
{
    NSPointerArray *toRelease = [[NSPointerArray alloc] initWithOptions:(NSPointerFunctionsOpaqueMemory | NSPointerFunctionsOpaquePersonality)];

    [playbackBuffersLock lock];
    for (int i = 0; i < kMaxPlaybackAudioBuffers; i ++)
    {
        if (playbackBuffers[i].data != NULL && playbackBuffers[i].consumedSize == playbackBuffers[i].totalSize)
        {
            // Cleanup fully-consumed buffers. Doing it in the render callback would waste time.
            [toRelease addPointer:playbackBuffers[i].data];
            playbackBuffers[i] = (BackendBufferDescriptor){
                .data = NULL,
                .totalSize = 0,
                .consumedSize = 0,
            };
        }
    }
    [playbackBuffersLock unlock];

    for (int i = 0; i < toRelease.count; i ++)
    {
        free([toRelease pointerAtIndex:i]);
    }
    DBG(@"%@: playbackQueue GC disposed of %i buffers.\n", [self class], (int)toRelease.count);
}

- (void)queueBuffer:(void*)buf withSize:(size_t)size
{
    DBG(@"%@: Attempting to queue buffer %p (%i bytes).\n", [self class], buf, (int)size);

    [playbackBuffersLock lock];

    // Look for free buffers.
    int numFreeBuffers = 0;
    BackendBufferDescriptor *nextFreeBuffer = NULL;
    for (int i = 0; i < kMaxPlaybackAudioBuffers; i ++)
    {
        if (playbackBuffers[i].data == NULL)
        {
            numFreeBuffers ++;
            if (nextFreeBuffer == NULL) {
                nextFreeBuffer = &playbackBuffers[i];
            }
        }
    }
    if (numFreeBuffers > 0)
    {
        assert(nextFreeBuffer != NULL);
        assert(playbackBuffersQueue.count < kMaxPlaybackAudioBuffers);

        //nextFreeBuffer->data = buf;
        nextFreeBuffer->data = malloc(size);
        memcpy(nextFreeBuffer->data, buf, size);

        nextFreeBuffer->totalSize = (UInt32)size;
        nextFreeBuffer->consumedSize = 0;
        [playbackBuffersQueue addPointer:nextFreeBuffer];
        DBG(@"%@: Buffer queued.\n", [self class]);
    }
    else
    {
        NSLog(@"%@: Out of playback buffers. Failed to queue new buffer.\n", [self class]);
    }

    [playbackBuffersLock unlock];
}

- (BOOL)startPlayingWithSampleRate:(int) sampleRate
{
    BOOL retval = YES;

    [modeLock lock];
    _playbackSampleRate = sampleRate;
    retval = [self updateBackendState:(activeModes | kAudioStreamAUBackendPlayMode)];
    if (!retval) {
        _playbackSampleRate = 0;
    }
    [modeLock unlock];

    return retval;
}

- (void)stopPlaying
{
    [modeLock lock];
    [self updateBackendState:(activeModes & ~kAudioStreamAUBackendPlayMode)];
    /* Release all pending playback buffers. */
    for (int i = 0; i < kMaxPlaybackAudioBuffers; i ++)
    {
        BackendBufferDescriptor *desc = &playbackBuffers[i];
        if (desc->data != NULL)
        {
            free(desc->data);

            desc->data = NULL;
            desc->consumedSize = 0;
            desc->totalSize = 0;
        }
    }
    [playbackBuffersQueue setCount:0];
    _playbackSampleRate = 0;
    [modeLock unlock];
}

- (BOOL)startRecording:(id<AudioStreamAUBackendRecordDelegate>)delegate withSampleRate:(int)sampleRate
{
    BOOL retval = YES;

    [modeLock lock];
    recordDelegate = delegate;
    _recordSampleRate = sampleRate;
    retval = [self updateBackendState:(activeModes | kAudioStreamAUBackendRecordMode)];
    if (!retval) {
        recordDelegate = nil;
        _recordSampleRate = 0;
    }
    [modeLock unlock];

    return retval;
}

- (void)stopRecording
{
    [modeLock lock];
    [self updateBackendState:(activeModes & ~kAudioStreamAUBackendRecordMode)];
    recordDelegate = nil;
    _recordSampleRate = 0;
    [modeLock unlock];
}

- (void)fillRecordingFrame:(uint8_t*)buf withSize:(size_t)size
{
    uint8_t *data = buf;
    size_t dataSize = size;
    size_t freeSize = 0;
    size_t sizeToCpy = 0;

    while (dataSize > 0) {
        /* fill a frame */
        freeSize = kRecordBufferSize - _rcFrameSize;
        sizeToCpy = (dataSize <= freeSize) ? dataSize : freeSize;

        memcpy(_rcFrame + _rcFrameSize, data, sizeToCpy);
        _rcFrameSize += sizeToCpy;
        data += sizeToCpy;
        dataSize -= sizeToCpy;

        /* send only full frames */
        if (_rcFrameSize == kRecordBufferSize) {
            [self->recordDelegate audioStreamAUBackend:self didAcquireNewBuffer:_rcFrame withSize:kRecordBufferSize];
            _rcFrameSize = 0;
        }
    }
}

- (void)dealloc
{
    free(_rcFrame);
    _rcFrame = NULL;

    [self stopPlaying];
    [self stopRecording];
    free(playbackBuffers);
    playbackBuffers = NULL;
}

@end
