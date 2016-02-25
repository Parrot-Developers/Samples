//
//  DroneDiscoverer.m
//  SDKSample
//

#import "DroneDiscoverer.h"
#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>

@implementation DroneDiscoverer

- (void)setDelegate:(id<DroneDiscovererDelegate>)delegate {
    _delegate = delegate;
    
    if (_delegate && [_delegate respondsToSelector:@selector(droneDiscoverer:didUpdateDronesList:)]) {
        [_delegate droneDiscoverer:self didUpdateDronesList:[[ARDiscovery sharedInstance] getCurrentListOfDevicesServices]];
    }
}

- (void)startDiscovering {
    [self registerNotifications];
    [[ARDiscovery sharedInstance] start];
}

- (void)stopDiscovering {
    [[ARDiscovery sharedInstance] stop];
    [self unregisterNotifications];
}

#pragma mark notification registration
- (void)registerNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoveryDidUpdateServices:) name:kARDiscoveryNotificationServicesDevicesListUpdated object:nil];
}

- (void)unregisterNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kARDiscoveryNotificationServicesDevicesListUpdated object:nil];
}

#pragma mark ARDiscovery notification
- (void)discoveryDidUpdateServices:(NSNotification *)notification {
    // reload the data in the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_delegate && [_delegate respondsToSelector:@selector(droneDiscoverer:didUpdateDronesList:)]) {
            [_delegate droneDiscoverer:self didUpdateDronesList:[[notification userInfo] objectForKey:kARDiscoveryServicesList]];
        }
    });
}

@end
