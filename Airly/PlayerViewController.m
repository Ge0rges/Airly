//
//  PlayerViewController.m
//  Airly
//
//  Created by Georges Kanaan on 2/19/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "PlayerViewController.h"

// Frameworks
#import <AVFoundation/AVFoundation.h>

// Managers
#import "ConnectivityManager.h"
#import "NetworkPlayerManager.h"

@interface PlayerViewController () <ConnectivityManagerDelegate> {
  unsigned long receivingItemMaxCount;
  
  NSString *songTitle;
  NSString *songArtist;
  
  NSTimer *offsetCalculationTimer;
  
  UIImage *albumImage;
}

@property (strong, nonnull) UIImageView *backgroundImageView;

@property (strong, nonatomic) ConnectivityManager *connectivityManger;
@property (strong, nonatomic) NetworkPlayerManager *networkPlayerManager;
@property (strong, nonatomic) AVPlayer *player;

@property (strong, nonatomic) IBOutlet UIImageView *albumImageView;
@property (strong, nonatomic) IBOutlet UILabel *songTitleLabel;
@property (strong, nonatomic) IBOutlet UILabel *songArtistLabel;

@end

@implementation PlayerViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
  
  // Setup the connectivity manager
  self.connectivityManger = [ConnectivityManager sharedManagerWithDisplayName:[[UIDevice currentDevice] name]];
  [self.connectivityManger advertiseSelfInSessions:YES];
  self.connectivityManger.delegate = self;
  
  // Setup the Network Player Manager
  self.networkPlayerManager = [NetworkPlayerManager sharedManager];
  
  // Setup the player
  self.player = [AVPlayer new];
  
  // Configure the AVAudioSession
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  [audioSession setActive:YES error:nil];
  [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
  
  // Set a gradient as the background image
  if (!self.backgroundImageView) {
    self.backgroundImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:self.backgroundImageView];
    [self.view sendSubviewToBack:self.backgroundImageView];
  }
  
  [self.backgroundImageView setImage:[self gradientFromColor:[self generateRandomColor] toColor:[self generateRandomColor] withSize:self.backgroundImageView.frame.size]];
}

#pragma mark - ConnectivityManagerDelegate
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
  // We received data from host either
  NSDictionary *payload = [NSKeyedUnarchiver unarchiveObjectWithData:data];

  if ([payload[@"command"] isEqualToString:@"metadata"]) {
    songTitle = [payload[@"songName"] stringByReplacingOccurrencesOfString:@"title " withString:@""];
    songArtist = [payload[@"songArtist"] stringByReplacingOccurrencesOfString:@"artist " withString:@""];
    albumImage = [UIImage imageWithData:payload[@"songAlbumArt"]];
    
    // Update UI at specified date
    [self.networkPlayerManager atExactTime:((NSNumber *)payload[@"date"]).unsignedLongLongValue runBlock:^{
      [self performSelectorOnMainThread:@selector(updatePlayerUI) withObject:nil waitUntilDone:NO];
    }];
    
  } else if ([payload[@"command"] isEqualToString:@"play"]) {
    // Play at specified date
    [self.networkPlayerManager atExactTime:((NSNumber *)payload[@"date"]).unsignedLongLongValue runBlock:^{
      [self.player play];
    }];
    
    // Set the playback time
    [self.player seekToTime:CMTimeMakeWithSeconds(((NSNumber*)payload[@"commandTime"]).doubleValue, 1000000000)];

    
  } else if ([payload[@"command"] isEqualToString:@"pause"]) {
    // Pause at specified date
    [self.networkPlayerManager atExactTime:((NSNumber *)payload[@"date"]).unsignedLongLongValue runBlock:^{
      [self.player pause];
    }];
  }
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
  // If there is no local URL, then this is not a song.
  if (localURL) {    
    // Fix the path
    NSString *fixedPath = [[localURL.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"resourc.caf"];
    NSURL *fixedURL = [NSURL fileURLWithPath:fixedPath isDirectory:NO];
    
    // Move the file to change its name to the right format
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtURL:fixedURL error:&error];//delete current song (old)
    [fileManager moveItemAtURL:localURL toURL:fixedURL error:nil];//move the new song file

    // Load the song
    [self.player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:fixedURL]];
  }
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
  if (state == MCSessionStateConnecting) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.songTitleLabel setText:[NSString stringWithFormat:@"Connecting to %@", peerID.displayName]];
    });
    
  } else if (state == MCSessionStateConnected) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.songTitleLabel setText:[NSString stringWithFormat:@"Connected to %@", peerID.displayName]];
    });
    
    // Periodicaly resync the offset (latency issues)
    //offsetCalculationTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self.networkPlayerManager selector:@selector(calculateTimeOffsetWithHost) userInfo:nil repeats:YES];
    
    [self.networkPlayerManager calculateTimeOffsetWithHost];

  } else if (state == MCSessionStateNotConnected) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.songTitleLabel setText:[NSString stringWithFormat:@"Disconnected from %@", peerID.displayName]];
    });
    
    [offsetCalculationTimer invalidate];
    offsetCalculationTimer = nil;
  }
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

#pragma mark - Player
- (void)updatePlayerUI {
  [self.albumImageView setImage:albumImage];
  [self.songArtistLabel setText:songArtist];
  [self.songTitleLabel setText:songTitle];
}

#pragma mark - Navigation
- (IBAction)dismissView:(id)sender {
  [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
