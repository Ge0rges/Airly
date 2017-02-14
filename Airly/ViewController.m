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

// Extensions
#import "UIImage+Gradient.h"
#import "UIColor+Helpers.h"

@interface ViewController ()

@property (strong, nonatomic) IBOutlet UIButton *broadcastButton;
@property (strong, nonatomic) IBOutlet UIButton *listenButton;

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
  
  // Hide the nav bar
  [self.navigationController setNavigationBarHidden:YES animated:YES];
  
  // Color the buttons
  UIColor *firstColor = [UIColor generateRandomColor];
  UIColor *secondColor = [UIColor generateRandomColor];
  
  UIImage *leftGradientBackground = [UIImage gradientFromColor:firstColor toColor:secondColor withSize:self.broadcastButton.frame.size];
  UIImage *rightGradientBackground = [UIImage gradientFromColor:secondColor toColor:firstColor withSize:self.listenButton.frame.size];
  
  [self.broadcastButton setBackgroundImage:leftGradientBackground forState:UIControlStateNormal];
  [self.listenButton setBackgroundImage:rightGradientBackground forState:UIControlStateNormal];
}

- (void)viewWillDisappear:(BOOL)animated {
  // Hide the nav bar
  [self.navigationController setNavigationBarHidden:NO animated:YES];
}

// White status bar
- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

@end
