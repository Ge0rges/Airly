//
//  ViewController.m
//  Airly
//
//  Created by Georges Kanaan on 2/16/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "ViewController.h"

// Frameworks
#import <AVFoundation/AVFoundation.h>

// Managers
#import "ConnectivityManager.h"
#import "PlayerManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  
  // Stop advertising
  ConnectivityManager *connectivityManger = [ConnectivityManager sharedManagerWithDisplayName:[[UIDevice currentDevice] name]];
  [connectivityManger advertiseSelfInSessions:NO];
  
  // Stop all music
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  [audioSession setActive:YES error:nil];
  
  [[PlayerManager sharedManager].musicController stop];
}

@end
