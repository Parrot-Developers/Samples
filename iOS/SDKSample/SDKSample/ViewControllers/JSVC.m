//
//  JSVC.m
//  SDKSample
//

#import "JSVC.h"
#import "JSDrone.h"
#import "JSVideoView.h"

#import <AVFoundation/AVFoundation.h>

#import "AudioStreamAUBackend.h"

typedef enum {
    AUDIO_STATE_MUTE = 0,
    AUDIO_STATE_INPUT,
    AUDIO_STATE_BIDIRECTIONAL,
} eAUDIO_STATE;

@interface JSVC ()<JSDroneDelegate>

@property (nonatomic, strong) UIAlertView *connectionAlertView;
@property (nonatomic, strong) UIAlertController *downloadAlertController;
@property (nonatomic, strong) UIProgressView *downloadProgressView;
@property (nonatomic, strong) JSDrone *jsDrone;
@property (nonatomic) dispatch_semaphore_t stateSem;

@property (nonatomic, assign) NSUInteger nbMaxDownload;
@property (nonatomic, assign) int currentDownloadIndex; // from 1 to nbMaxDownload
@property (nonatomic, assign) eAUDIO_STATE audioState;

@property (nonatomic, strong) IBOutlet JSVideoView *videoView;
@property (nonatomic, strong) IBOutlet UILabel *batteryLabel;
@property (nonatomic, strong) IBOutlet UIButton *downloadMediasBt;
@property (nonatomic, strong) IBOutlet UIButton *audioBt;
@property (nonatomic, strong) IBOutlet UILabel *audioLabel;

@end

@implementation JSVC

-(void)viewDidLoad {
    [super viewDidLoad];
    _stateSem = dispatch_semaphore_create(0);
    
    _jsDrone = [[JSDrone alloc] initWithService:_service];
    [_jsDrone setDelegate:self];
    [_jsDrone connect];
    
    _connectionAlertView = [[UIAlertView alloc] initWithTitle:[_service name] message:@"Connecting ..."
                                           delegate:self cancelButtonTitle:nil otherButtonTitles:nil, nil];
    _audioState = AUDIO_STATE_MUTE;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([_jsDrone connectionState] != ARCONTROLLER_DEVICE_STATE_RUNNING) {
        [_connectionAlertView show];
    }
}

- (void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    AudioStreamAUBackend *audioStream = [AudioStreamAUBackend sharedInstance];
    [audioStream stopPlaying];
    [audioStream stopRecording];
    
    if (_connectionAlertView && !_connectionAlertView.isHidden) {
        [_connectionAlertView dismissWithClickedButtonIndex:0 animated:NO];
    }
    _connectionAlertView = [[UIAlertView alloc] initWithTitle:[_service name] message:@"Disconnecting ..."
                                           delegate:self cancelButtonTitle:nil otherButtonTitles:nil, nil];
    [_connectionAlertView show];
    
    // in background, disconnect from the drone
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [_jsDrone disconnect];
        // wait for the disconnection to appear
        dispatch_semaphore_wait(_stateSem, DISPATCH_TIME_FOREVER);
        _jsDrone = nil;
        
        // dismiss the alert view in main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [_connectionAlertView dismissWithClickedButtonIndex:0 animated:YES];
        });
    });
}

- (void) updateView {
    if ([_jsDrone hasInputAudioStream] || [_jsDrone hasOutputAudioStream]) {
        [_audioBt setHidden:NO];
        [_audioLabel setHidden:NO];
    }
}

- (void) setAudioState:(eAUDIO_STATE) audioState {
    _audioState = audioState;
    switch (_audioState) {
        case AUDIO_STATE_MUTE:
            [_audioBt setTitle: @"MUTE" forState:UIControlStateNormal];
            [_jsDrone setAudioStreamEnabledWithInput:NO output:NO];
            break;
        case AUDIO_STATE_INPUT:
            [_audioBt setTitle: @"INPUT" forState:UIControlStateNormal];
            [_jsDrone setAudioStreamEnabledWithInput:YES output:NO];
            break;
        case AUDIO_STATE_BIDIRECTIONAL:
            [_audioBt setTitle: @"IN/OUTPUT" forState:UIControlStateNormal];
            [_jsDrone setAudioStreamEnabledWithInput:YES output:YES];
            break;
    }
}

#pragma mark JSDroneDelegate
-(void)jsDrone:(JSDrone *)jsDrone connectionDidChange:(eARCONTROLLER_DEVICE_STATE)state {
    switch (state) {
        case ARCONTROLLER_DEVICE_STATE_RUNNING:
            [_connectionAlertView dismissWithClickedButtonIndex:0 animated:YES];
            [self updateView];
            break;
        case ARCONTROLLER_DEVICE_STATE_STOPPED:
            dispatch_semaphore_signal(_stateSem);
            
            // Go back
            [self.navigationController popViewControllerAnimated:YES];
            
            break;
            
        default:
            break;
    }
}

- (void)jsDrone:(JSDrone*)jsDrone batteryDidChange:(int)batteryPercentage {
    [_batteryLabel setText:[NSString stringWithFormat:@"%d%%", batteryPercentage]];
}

- (BOOL)jsDrone:(JSDrone*)jsDrone configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec {
    return [_videoView configureDecoder:codec];
}

- (BOOL)jsDrone:(JSDrone*)jsDrone didReceiveFrame:(ARCONTROLLER_Frame_t*)frame {
    return [_videoView displayFrame:frame];
}

- (void)jsDrone:(JSDrone*)jsDrone audioStateDidChangeWithInput:(BOOL)inputEnabled output:(BOOL)outputEnabled {

    AudioStreamAUBackend *audioStream = [AudioStreamAUBackend sharedInstance];

    [audioStream stopPlaying];

    if (outputEnabled) {
        [audioStream startRecording:self withSampleRate:8000];
    } else {
        [audioStream stopRecording];
    }
}

- (BOOL)jsDrone:(JSDrone*)jsDrone configureAudioDecoder:(ARCONTROLLER_Stream_Codec_t)codec {

    if (codec.type == ARCONTROLLER_STREAM_CODEC_TYPE_PCM16LE) {
        AudioStreamAUBackend *audioStream = [AudioStreamAUBackend sharedInstance];
        [audioStream startPlayingWithSampleRate:codec.parameters.pcm16leParameters.sampleRate];
    }

    return true;
}

- (BOOL)jsDrone:(JSDrone*)jsDrone didReceiveAudioFrame:(ARCONTROLLER_Frame_t*)frame {

    AudioStreamAUBackend *audioStream = [AudioStreamAUBackend sharedInstance];
    [audioStream queueBuffer:frame->data withSize:frame->used];

    return true;
}

- (void)jsDrone:(JSDrone*)jsDrone didFoundMatchingMedias:(NSUInteger)nbMedias {
    _nbMaxDownload = nbMedias;
    _currentDownloadIndex = 1;
    
    if (nbMedias > 0) {
        [_downloadAlertController setMessage:@"Downloading medias"];
        UIViewController *customVC = [[UIViewController alloc] init];
        _downloadProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        [_downloadProgressView setProgress:0];
        [customVC.view addSubview:_downloadProgressView];
        
        [customVC.view addConstraint:[NSLayoutConstraint
                                      constraintWithItem:_downloadProgressView
                                      attribute:NSLayoutAttributeCenterX
                                      relatedBy:NSLayoutRelationEqual
                                      toItem:customVC.view
                                      attribute:NSLayoutAttributeCenterX
                                      multiplier:1.0f
                                      constant:0.0f]];
        [customVC.view addConstraint:[NSLayoutConstraint
                                      constraintWithItem:_downloadProgressView
                                      attribute:NSLayoutAttributeBottom
                                      relatedBy:NSLayoutRelationEqual
                                      toItem:customVC.bottomLayoutGuide
                                      attribute:NSLayoutAttributeTop
                                      multiplier:1.0f
                                      constant:-20.0f]];
        
        [_downloadAlertController setValue:customVC forKey:@"contentViewController"];
    } else {
        [_downloadAlertController dismissViewControllerAnimated:YES completion:^{
            _downloadProgressView = nil;
            _downloadAlertController = nil;
        }];
    }
}

- (void)jsDrone:(JSDrone*)jsDrone media:(NSString*)mediaName downloadDidProgress:(int)progress {
    float completedProgress = ((_currentDownloadIndex - 1) / (float)_nbMaxDownload);
    float currentProgress = (progress / 100.f) / (float)_nbMaxDownload;
    [_downloadProgressView setProgress:(completedProgress + currentProgress)];
}

- (void)jsDrone:(JSDrone*)jsDrone mediaDownloadDidFinish:(NSString*)mediaName {
    _currentDownloadIndex++;
    
    if (_currentDownloadIndex > _nbMaxDownload) {
        [_downloadAlertController dismissViewControllerAnimated:YES completion:^{
            _downloadProgressView = nil;
            _downloadAlertController = nil;
        }];
        
    }
}

#pragma mark buttons click
- (IBAction)takePictureClicked:(id)sender {
    [_jsDrone takePicture];
}

- (IBAction)downloadMediasClicked:(id)sender {
    [_downloadAlertController dismissViewControllerAnimated:YES completion:nil];
    
    _downloadAlertController = [UIAlertController alertControllerWithTitle:@"Download"
                                                                   message:@"Fetching medias"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action) {
                                                             [_jsDrone cancelDownloadMedias];
                                                         }];
    [_downloadAlertController addAction:cancelAction];
    
    
    UIViewController *customVC = [[UIViewController alloc] init];
    UIActivityIndicatorView* spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [spinner startAnimating];
    [customVC.view addSubview:spinner];
    
    [customVC.view addConstraint:[NSLayoutConstraint
                                  constraintWithItem: spinner
                                  attribute:NSLayoutAttributeCenterX
                                  relatedBy:NSLayoutRelationEqual
                                  toItem:customVC.view
                                  attribute:NSLayoutAttributeCenterX
                                  multiplier:1.0f
                                  constant:0.0f]];
    [customVC.view addConstraint:[NSLayoutConstraint
                                  constraintWithItem:spinner
                                  attribute:NSLayoutAttributeBottom
                                  relatedBy:NSLayoutRelationEqual
                                  toItem:customVC.bottomLayoutGuide
                                  attribute:NSLayoutAttributeTop
                                  multiplier:1.0f
                                  constant:-20.0f]];
    
    
    [_downloadAlertController setValue:customVC forKey:@"contentViewController"];
    
    [self presentViewController:_downloadAlertController animated:YES completion:nil];
    
    [_jsDrone downloadMedias];
}

- (IBAction)turnLeftTouchDown:(id)sender {
    [_jsDrone setFlag:1];
    [_jsDrone setTurn:-50];
}

- (IBAction)turnRightTouchDown:(id)sender {
    [_jsDrone setFlag:1];
    [_jsDrone setTurn:50];
}

- (IBAction)turnLeftTouchUp:(id)sender {
    [_jsDrone setFlag:0];
    [_jsDrone setTurn:0];
}

- (IBAction)turnRightTouchUp:(id)sender {
    [_jsDrone setFlag:0];
    [_jsDrone setTurn:0];
}

- (IBAction)forwardTouchDown:(id)sender {
    [_jsDrone setFlag:1];
    [_jsDrone setSpeed:50];
}

- (IBAction)backwardTouchDown:(id)sender {
    [_jsDrone setFlag:1];
    [_jsDrone setSpeed:-50];
}

- (IBAction)forwardTouchUp:(id)sender {
    [_jsDrone setFlag:0];
    [_jsDrone setSpeed:0];
}

- (IBAction)backwardTouchUp:(id)sender {
    [_jsDrone setFlag:0];
    [_jsDrone setSpeed:0];
}

- (IBAction)audioClicked:(id)sender {
    switch (_audioState) {
        case AUDIO_STATE_MUTE:
            [self setAudioState:AUDIO_STATE_INPUT];
            break;
        case AUDIO_STATE_INPUT:
            if([_jsDrone hasOutputAudioStream]) {
                [self setAudioState:AUDIO_STATE_BIDIRECTIONAL];
            } else {
                [self setAudioState:AUDIO_STATE_MUTE];
            }
            break;
        case AUDIO_STATE_BIDIRECTIONAL:
            [self setAudioState:AUDIO_STATE_MUTE];
            break;
    }
}

- (void)audioStreamAUBackend:(AudioStreamAUBackend*)backend didAcquireNewBuffer:(uint8_t*)buf withSize:(size_t)size
{
    [_jsDrone sendAudioStreamFrame:buf withSize:size];
}

@end
