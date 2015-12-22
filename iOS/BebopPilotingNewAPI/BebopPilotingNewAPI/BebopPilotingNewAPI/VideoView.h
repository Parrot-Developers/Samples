//
//  VideoView.h
//  BebopPilotingNewAPI
//
//  Created by Djavan Bertrand on 20/07/2015.
//  Copyright (c) 2015 Parrot. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <libARController/ARController.h>

@interface VideoView : UIView

- (BOOL)displayFrame:(ARCONTROLLER_Frame_t *)frame;
- (BOOL)sps:(uint8_t *)spsBuffer spsSize:(int)spsSize pps:(uint8_t *)ppsBuffer ppsSize:(int) ppsSize;

@end
