//
//  BebopVC.m
//  SDKSample
//

#import "BebopVC.h"
#import "BebopDrone.h"
#import "H264VideoView.h"

@interface BebopVC ()<BebopDroneDelegate>

@property (nonatomic, strong) UIAlertView *connectionAlertView;
@property (nonatomic, strong) UIAlertController *downloadAlertController;
@property (nonatomic, strong) UIProgressView *downloadProgressView;
@property (nonatomic, strong) BebopDrone *bebopDrone;
@property (nonatomic) dispatch_semaphore_t stateSem;

@property (nonatomic, assign) NSUInteger nbMaxDownload;
@property (nonatomic, assign) int currentDownloadIndex; // from 1 to nbMaxDownload

@property (nonatomic, strong) IBOutlet H264VideoView *videoView;
@property (nonatomic, strong) IBOutlet UILabel *batteryLabel;
@property (nonatomic, strong) IBOutlet UIButton *takeOffLandBt;
@property (nonatomic, strong) IBOutlet UIButton *downloadMediasBt;

@end

@implementation BebopVC

-(void)viewDidLoad {
    [super viewDidLoad];
    _stateSem = dispatch_semaphore_create(0);
    
    _bebopDrone = [[BebopDrone alloc] initWithService:_service];
    [_bebopDrone setDelegate:self];
    [_bebopDrone connect];
    
    _connectionAlertView = [[UIAlertView alloc] initWithTitle:[_service name] message:@"Connecting ..."
                                           delegate:self cancelButtonTitle:nil otherButtonTitles:nil, nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([_bebopDrone connectionState] != ARCONTROLLER_DEVICE_STATE_RUNNING) {
        [_connectionAlertView show];
    }
}

- (void) viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (_connectionAlertView && !_connectionAlertView.isHidden) {
        [_connectionAlertView dismissWithClickedButtonIndex:0 animated:NO];
    }
    _connectionAlertView = [[UIAlertView alloc] initWithTitle:[_service name] message:@"Disconnecting ..."
                                           delegate:self cancelButtonTitle:nil otherButtonTitles:nil, nil];
    [_connectionAlertView show];
    
    // in background, disconnect from the drone
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [_bebopDrone disconnect];
        // wait for the disconnection to appear
        dispatch_semaphore_wait(_stateSem, DISPATCH_TIME_FOREVER);
        _bebopDrone = nil;
        
        // dismiss the alert view in main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [_connectionAlertView dismissWithClickedButtonIndex:0 animated:YES];
        });
    });
}


#pragma mark BebopDroneDelegate
-(void)bebopDrone:(BebopDrone *)bebopDrone connectionDidChange:(eARCONTROLLER_DEVICE_STATE)state {
    switch (state) {
        case ARCONTROLLER_DEVICE_STATE_RUNNING:
            [_connectionAlertView dismissWithClickedButtonIndex:0 animated:YES];
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

- (void)bebopDrone:(BebopDrone*)bebopDrone batteryDidChange:(int)batteryPercentage {
    [_batteryLabel setText:[NSString stringWithFormat:@"%d%%", batteryPercentage]];
}

- (void)bebopDrone:(BebopDrone*)bebopDrone flyingStateDidChange:(eARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE)state {
    switch (state) {
        case ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_LANDED:
            [_takeOffLandBt setTitle:@"Take off" forState:UIControlStateNormal];
            [_takeOffLandBt setEnabled:YES];
            [_downloadMediasBt setEnabled:YES];
            break;
        case ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_FLYING:
        case ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_HOVERING:
            [_takeOffLandBt setTitle:@"Land" forState:UIControlStateNormal];
            [_takeOffLandBt setEnabled:YES];
            [_downloadMediasBt setEnabled:NO];
            break;
        default:
            [_takeOffLandBt setEnabled:NO];
            [_downloadMediasBt setEnabled:NO];
    }
}

- (BOOL)bebopDrone:(BebopDrone*)bebopDrone configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec {
    return [_videoView configureDecoder:codec];
}

- (BOOL)bebopDrone:(BebopDrone*)bebopDrone didReceiveFrame:(ARCONTROLLER_Frame_t*)frame {
    return [_videoView displayFrame:frame];
}

- (void)bebopDrone:(BebopDrone*)bebopDrone didFoundMatchingMedias:(NSUInteger)nbMedias {
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

- (void)bebopDrone:(BebopDrone*)bebopDrone media:(NSString*)mediaName downloadDidProgress:(int)progress {
    float completedProgress = ((_currentDownloadIndex - 1) / (float)_nbMaxDownload);
    float currentProgress = (progress / 100.f) / (float)_nbMaxDownload;
    [_downloadProgressView setProgress:(completedProgress + currentProgress)];
}

- (void)bebopDrone:(BebopDrone*)bebopDrone mediaDownloadDidFinish:(NSString*)mediaName {
    _currentDownloadIndex++;
    
    if (_currentDownloadIndex > _nbMaxDownload) {
        [_downloadAlertController dismissViewControllerAnimated:YES completion:^{
            _downloadProgressView = nil;
            _downloadAlertController = nil;
        }];
        
    }
}

#pragma mark buttons click
- (IBAction)emergencyClicked:(id)sender {
    [_bebopDrone emergency];
}

- (IBAction)takeOffLandClicked:(id)sender {
    switch ([_bebopDrone flyingState]) {
        case ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_LANDED:
            [_bebopDrone takeOff];
            break;
        case ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_FLYING:
        case ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_HOVERING:
            [_bebopDrone land];
            break;
        default:
            break;
    }
}

- (IBAction)takePictureClicked:(id)sender {
    [_bebopDrone takePicture];
}

- (IBAction)downloadMediasClicked:(id)sender {
    [_downloadAlertController dismissViewControllerAnimated:YES completion:nil];
    
    _downloadAlertController = [UIAlertController alertControllerWithTitle:@"Download"
                                                                   message:@"Fetching medias"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action) {
                                                             [_bebopDrone cancelDownloadMedias];
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
    
    [_bebopDrone downloadMedias];
}

- (IBAction)gazUpTouchDown:(id)sender {
    [_bebopDrone setGaz:50];
}

- (IBAction)gazDownTouchDown:(id)sender {
    [_bebopDrone setGaz:-50];
}

- (IBAction)gazUpTouchUp:(id)sender {
    [_bebopDrone setGaz:0];
}

- (IBAction)gazDownTouchUp:(id)sender {
    [_bebopDrone setGaz:0];
}

- (IBAction)yawLeftTouchDown:(id)sender {
    [_bebopDrone setYaw:-50];
}

- (IBAction)yawRightTouchDown:(id)sender {
    [_bebopDrone setYaw:50];
}

- (IBAction)yawLeftTouchUp:(id)sender {
    [_bebopDrone setYaw:0];
}

- (IBAction)yawRightTouchUp:(id)sender {
    [_bebopDrone setYaw:0];
}

- (IBAction)rollLeftTouchDown:(id)sender {
    [_bebopDrone setFlag:1];
    [_bebopDrone setRoll:-50];
}

- (IBAction)rollRightTouchDown:(id)sender {
    [_bebopDrone setFlag:1];
    [_bebopDrone setRoll:50];
}

- (IBAction)rollLeftTouchUp:(id)sender {
    [_bebopDrone setFlag:0];
    [_bebopDrone setRoll:0];
}

- (IBAction)rollRightTouchUp:(id)sender {
    [_bebopDrone setFlag:0];
    [_bebopDrone setRoll:0];
}

- (IBAction)pitchForwardTouchDown:(id)sender {
    [_bebopDrone setFlag:1];
    [_bebopDrone setPitch:50];
}

- (IBAction)pitchBackTouchDown:(id)sender {
    [_bebopDrone setFlag:1];
    [_bebopDrone setPitch:-50];
}

- (IBAction)pitchForwardTouchUp:(id)sender {
    [_bebopDrone setFlag:0];
    [_bebopDrone setPitch:0];
}

- (IBAction)pitchBackTouchUp:(id)sender {
    [_bebopDrone setFlag:0];
    [_bebopDrone setPitch:0];
}

@end
