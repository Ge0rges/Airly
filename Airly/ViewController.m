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
  [self.broadcastButton setBackgroundImage:[self gradientFromColor:[self generateRandomColor] toColor:[self generateRandomColor] withSize:self.broadcastButton.frame.size] forState:UIControlStateNormal];
  [self.listenButton setBackgroundImage:[self gradientFromColor:[self generateRandomColor] toColor:[self generateRandomColor] withSize:self.listenButton.frame.size] forState:UIControlStateNormal];
}

- (void)viewWillDisappear:(BOOL)animated {
  // Hide the nav bar
  [self.navigationController setNavigationBarHidden:NO animated:YES];
}

#pragma mark - Background Color
// Gradient Generator
- (UIImage *)gradientFromColor:(UIColor *)fromColor toColor:(UIColor *)toColor withSize:(CGSize)size {
  CAGradientLayer *layer = [CAGradientLayer layer];
  layer.frame = CGRectMake(0, 0, size.width, size.height);
  layer.colors = @[(__bridge id)fromColor.CGColor,
                   (__bridge id)toColor.CGColor];
  
  UIGraphicsBeginImageContext(size);
  [layer renderInContext:UIGraphicsGetCurrentContext()];
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  return image;
}

- (UIColor *)generateRandomColor {
  CGFloat hue = ( arc4random() % 256 / 256.0 );  //  0.0 to 1.0
  CGFloat saturation = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from white
  CGFloat brightness = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from black
  return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
}

// White status bar
- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

@end
