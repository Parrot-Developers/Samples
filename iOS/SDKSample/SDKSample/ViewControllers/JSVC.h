//
//  JSVC.h
//  SDKSample
//

#import <UIKit/UIKit.h>
#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>

#import "AudioStreamAUBackend.h"

@interface JSVC : UIViewController <AudioStreamAUBackendRecordDelegate>

@property (nonatomic, strong) ARService *service;

- (void)audioStreamAUBackend:(AudioStreamAUBackend*)backend didAcquireNewBuffer:(uint8_t*)buf withSize:(size_t)size;

@end
