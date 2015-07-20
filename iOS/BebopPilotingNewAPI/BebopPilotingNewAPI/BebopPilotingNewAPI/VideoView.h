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

- (void)displayFrame:(ARCONTROLLER_Frame_t *)frame;

@end
