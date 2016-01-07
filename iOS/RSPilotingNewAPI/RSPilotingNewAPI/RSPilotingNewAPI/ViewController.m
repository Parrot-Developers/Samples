/*
    Copyright (C) 2014 Parrot SA

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in
      the documentation and/or other materials provided with the 
      distribution.
    * Neither the name of Parrot nor the names
      of its contributors may be used to endorse or promote products
      derived from this software without specific prior written
      permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
    OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED 
    AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
    OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
    SUCH DAMAGE.
*/
//
//  ViewController.m
//  RollingSpiderPiloting
//
//  Created on 19/01/2015.
//  Copyright (c) 2015 Parrot. All rights reserved.
//

#import "ViewController.h"
#import <libARDiscovery/ARDISCOVERY_BonjourDiscovery.h>
#import "PilotingViewController.h"

@interface CellData ()
@end

@implementation CellData
@end

@interface ViewController ()

@property (nonatomic, strong) ARService *serviceSelected;
@property (nonatomic, strong) NSArray *tableData;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _tableData = [NSArray array];
    _serviceSelected = nil;
    
}

- (void) viewDidAppear:(BOOL)animated
{
    NSLog(@"viewDidAppear ... ");
    [super viewDidAppear:animated];
    
    [self registerApplicationNotifications];
    // start the discovery
    [[ARDiscovery sharedInstance] start];
}

- (void) viewDidDisappear:(BOOL)animated
{
    NSLog(@"viewDidDisappear ... ");
    [super viewDidDisappear:animated];
    
    [self unregisterApplicationNotifications];
    [[ARDiscovery sharedInstance] stop];
}

- (void)registerApplicationNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enteredBackground:) name: UIApplicationDidEnterBackgroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterForeground:) name: UIApplicationWillEnterForegroundNotification object: nil];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(discoveryDidUpdateServices:) name:kARDiscoveryNotificationServicesDevicesListUpdated object:nil];
}

- (void)unregisterApplicationNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name: UIApplicationDidEnterBackgroundNotification object: nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name: UIApplicationWillEnterForegroundNotification object: nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kARDiscoveryNotificationServicesDevicesListUpdated object:nil];
}

#pragma mark - application notifications
- (void)enteredBackground:(NSNotification*)notification
{
    [[ARDiscovery sharedInstance] stop];
}

- (void)enterForeground:(NSNotification*)notification
{
    [[ARDiscovery sharedInstance] start];
}

#pragma mark ARDiscovery notification
- (void)discoveryDidUpdateServices:(NSNotification *)notification
{
    // Called when the list of discovered services has changed
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateServicesList:[[notification userInfo] objectForKey:kARDiscoveryServicesList]];
    });
}

- (void)updateServicesList:(NSArray *)services
{
    NSMutableArray *serviceArray = [NSMutableArray array];
    
    for (ARService *service in services)
    {
        // only display the ble services
        if ([service.service isKindOfClass:[ARBLEService class]])
        {
            CellData *cellData = [[CellData alloc]init];
            
            [cellData setService:service];
            [cellData setName:service.name];
            [serviceArray addObject:cellData];
        }
    }
    
    _tableData = serviceArray;
    [_tableView reloadData];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_tableData count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *simpleTableIdentifier = @"SimpleTableItem";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    
    cell.textLabel.text = [(CellData *)[_tableData objectAtIndex:indexPath.row] name];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    _serviceSelected = [(CellData *)[_tableData objectAtIndex:indexPath.row] service];
    
    [self performSegueWithIdentifier:@"pilotingSegue" sender:self];
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if(([segue.identifier isEqualToString:@"pilotingSegue"]) && (_serviceSelected != nil))
    {
        PilotingViewController *pilotingViewController = (PilotingViewController *)[segue destinationViewController];
        
        [pilotingViewController setService: _serviceSelected];
    }
}

@end
