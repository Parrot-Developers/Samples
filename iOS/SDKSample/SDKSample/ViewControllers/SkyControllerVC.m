//
//  SkyControllerVC.m
//  SDKSample
//

#import "SkyControllerVC.h"
#import "SkyController.h"
#import "H264VideoView.h"

@interface SkyControllerVC ()<SkyControllerDelegate>

@property (nonatomic, strong) UIAlertView *connectionAlertView;
@property (nonatomic, strong) UIAlertController *downloadAlertController;
@property (nonatomic, strong) UIProgressView *downloadProgressView;
@property (nonatomic, strong) SkyController *skyController;
@property (nonatomic) dispatch_semaphore_t stateSem;

@property (nonatomic, assign) NSUInteger nbMaxDownload;
@property (nonatomic, assign) int currentDownloadIndex; // from 1 to nbMaxDownload

@property (nonatomic, strong) IBOutlet H264VideoView *videoView;
@property (nonatomic, strong) IBOutlet UILabel *scBatteryLabel;
@property (nonatomic, strong) IBOutlet UILabel *droneBatteryLabel;
@property (nonatomic, strong) IBOutlet UIButton *takeOffLandBt;
@property (nonatomic, strong) IBOutlet UIButton *downloadMediasBt;
@property (nonatomic, strong) IBOutlet UIButton *emergencyButton;
@property (nonatomic, strong) IBOutlet UIButton *takePictureButton;
@property (nonatomic, strong) IBOutlet UILabel *droneConnectionLabel;

@end

@implementation SkyControllerVC

-(void)viewDidLoad {
    [super viewDidLoad];
    _stateSem = dispatch_semaphore_create(0);
    
    _skyController = [[SkyController alloc] initWithService:_service];
    [_skyController setDelegate:self];
    [_skyController connect];
    
    _connectionAlertView = [[UIAlertView alloc] initWithTitle:[_service name] message:@"Connecting ..."
                                           delegate:self cancelButtonTitle:nil otherButtonTitles:nil, nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([_skyController connectionState] != ARCONTROLLER_DEVICE_STATE_RUNNING) {
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
        [_skyController disconnect];
        // wait for the disconnection to appear
        dispatch_semaphore_wait(_stateSem, DISPATCH_TIME_FOREVER);
        _skyController = nil;
        
        // dismiss the alert view in main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [_connectionAlertView dismissWithClickedButtonIndex:0 animated:YES];
        });
    });
}


#pragma mark SkyControllerDroneDelegate
-(void)skyController:(SkyController*)sc scConnectionDidChange:(eARCONTROLLER_DEVICE_STATE)state {
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

-(void)skyController:(SkyController*)sc droneConnectionDidChange:(eARCONTROLLER_DEVICE_STATE)state {
    switch (state) {
        case ARCONTROLLER_DEVICE_STATE_RUNNING:
            [_takeOffLandBt setHidden:NO];
            [_downloadMediasBt setHidden:NO];
            [_emergencyButton setHidden:NO];
            [_takePictureButton setHidden:NO];
            [_droneConnectionLabel setHidden:YES];
            break;
        case ARCONTROLLER_DEVICE_STATE_STOPPED:
            [_takeOffLandBt setHidden:YES];
            [_downloadMediasBt setHidden:YES];
            [_emergencyButton setHidden:YES];
            [_takePictureButton setHidden:YES];
            [_droneConnectionLabel setHidden:NO];
            break;
            
        default:
            break;
    }
}

- (void)skyController:(SkyController*)sc scBatteryDidChange:(int)batteryPercentage {
    [_scBatteryLabel setText:[NSString stringWithFormat:@"%d%%", batteryPercentage]];
}

- (void)skyController:(SkyController*)sc droneBatteryDidChange:(int)batteryPercentage {
    [_droneBatteryLabel setText:[NSString stringWithFormat:@"%d%%", batteryPercentage]];
}

- (void)skyController:(SkyController*)sc flyingStateDidChange:(eARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE)state {
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

- (BOOL)skyController:(SkyController*)sc configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec {
    return [_videoView configureDecoder:codec];
}

- (BOOL)skyController:(SkyController*)sc didReceiveFrame:(ARCONTROLLER_Frame_t*)frame {
    return [_videoView displayFrame:frame];
}

- (void)skyController:(SkyController*)sc didFoundMatchingMedias:(NSUInteger)nbMedias {
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

- (void)skyController:(SkyController*)sc media:(NSString*)mediaName downloadDidProgress:(int)progress {
    float completedProgress = ((_currentDownloadIndex - 1) / (float)_nbMaxDownload);
    float currentProgress = (progress / 100.f) / (float)_nbMaxDownload;
    [_downloadProgressView setProgress:(completedProgress + currentProgress)];
}

- (void)skyController:(SkyController*)sc mediaDownloadDidFinish:(NSString*)mediaName {
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
    [_skyController emergency];
}

- (IBAction)takeOffLandClicked:(id)sender {
    switch ([_skyController flyingState]) {
        case ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_LANDED:
            [_skyController takeOff];
            break;
        case ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_FLYING:
        case ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_HOVERING:
            [_skyController land];
            break;
        default:
            break;
    }
}

- (IBAction)takePictureClicked:(id)sender {
    [_skyController takePicture];
}

- (IBAction)downloadMediasClicked:(id)sender {
    [_downloadAlertController dismissViewControllerAnimated:YES completion:nil];
    
    _downloadAlertController = [UIAlertController alertControllerWithTitle:@"Download"
                                                                   message:@"Fetching medias"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action) {
                                                             [_skyController cancelDownloadMedias];
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
    
    [_skyController downloadMedias];
}
@end
