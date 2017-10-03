//
//  SkyController2VC.m
//  SDKSample
//

#import "SkyController2VC.h"
#import "SkyController2.h"
#import "H264VideoView.h"

@interface SkyController2VC ()<SkyController2Delegate>

@property (nonatomic, strong) UIAlertView *connectionAlertView;
@property (nonatomic, strong) UIAlertController *downloadAlertController;
@property (nonatomic, strong) UIProgressView *downloadProgressView;
@property (nonatomic, strong) SkyController2 *skyController2;
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

@implementation SkyController2VC

-(void)viewDidLoad {
    [super viewDidLoad];
    _stateSem = dispatch_semaphore_create(0);

    _skyController2 = [[SkyController2 alloc] initWithService:_service];
    [_skyController2 setDelegate:self];
    [_skyController2 connect];

    _connectionAlertView = [[UIAlertView alloc] initWithTitle:[_service name] message:@"Connecting ..."
                                           delegate:self cancelButtonTitle:nil otherButtonTitles:nil, nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if ([_skyController2 connectionState] != ARCONTROLLER_DEVICE_STATE_RUNNING) {
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
        [_skyController2 disconnect];
        // wait for the disconnection to appear
        dispatch_semaphore_wait(_stateSem, DISPATCH_TIME_FOREVER);
        _skyController2 = nil;

        // dismiss the alert view in main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            [_connectionAlertView dismissWithClickedButtonIndex:0 animated:YES];
        });
    });
}


#pragma mark SkyControllerDroneDelegate
-(void)skyController2:(SkyController2*)sc2 scConnectionDidChange:(eARCONTROLLER_DEVICE_STATE)state {
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

-(void)skyController2:(SkyController2*)sc2 droneConnectionDidChange:(eARCONTROLLER_DEVICE_STATE)state {
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

- (void)skyController2:(SkyController2*)sc2 scBatteryDidChange:(int)batteryPercentage {
    [_scBatteryLabel setText:[NSString stringWithFormat:@"%d%%", batteryPercentage]];
}

- (void)skyController2:(SkyController2*)sc2 droneBatteryDidChange:(int)batteryPercentage {
    [_droneBatteryLabel setText:[NSString stringWithFormat:@"%d%%", batteryPercentage]];
}

- (void)skyController2:(SkyController2*)sc2 flyingStateDidChange:(eARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE)state {
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

- (BOOL)skyController2:(SkyController2*)sc2 configureDecoder:(ARCONTROLLER_Stream_Codec_t)codec {
    return [_videoView configureDecoder:codec];
}

- (BOOL)skyController2:(SkyController2*)sc2 didReceiveFrame:(ARCONTROLLER_Frame_t*)frame {
    return [_videoView displayFrame:frame];
}

- (void)skyController2:(SkyController2*)sc2 didFoundMatchingMedias:(NSUInteger)nbMedias {
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

- (void)skyController2:(SkyController2*)sc2 media:(NSString*)mediaName downloadDidProgress:(int)progress {
    float completedProgress = ((_currentDownloadIndex - 1) / (float)_nbMaxDownload);
    float currentProgress = (progress / 100.f) / (float)_nbMaxDownload;
    [_downloadProgressView setProgress:(completedProgress + currentProgress)];
}

- (void)skyController2:(SkyController2*)sc2 mediaDownloadDidFinish:(NSString*)mediaName {
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
    [_skyController2 emergency];
}

- (IBAction)takeOffLandClicked:(id)sender {
    switch ([_skyController2 flyingState]) {
        case ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_LANDED:
            [_skyController2 takeOff];
            break;
        case ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_FLYING:
        case ARCOMMANDS_ARDRONE3_PILOTINGSTATE_FLYINGSTATECHANGED_STATE_HOVERING:
            [_skyController2 land];
            break;
        default:
            break;
    }
}

- (IBAction)takePictureClicked:(id)sender {
    [_skyController2 takePicture];
}

- (IBAction)downloadMediasClicked:(id)sender {
    [_downloadAlertController dismissViewControllerAnimated:YES completion:nil];

    _downloadAlertController = [UIAlertController alertControllerWithTitle:@"Download"
                                                                   message:@"Fetching medias"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction * action) {
                                                             [_skyController2 cancelDownloadMedias];
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

    [_skyController2 downloadMedias];
}
@end
