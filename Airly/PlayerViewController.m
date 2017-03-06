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

// Classes
#import "SLColorArt.h"

// Managers
#import "ConnectivityManager.h"
#import "SyncManager.h"

// Extensions
#import "UIImage+Gradient.h"
#import "UIColor+Helpers.h"

@interface PlayerViewController () <ConnectivityManagerDelegate> {
  unsigned long receivingItemMaxCount;
  
  NSString *songTitle;
  NSString *songArtist;
  
  UIImage *albumImage;
  
  NSURL *songURL;
}

@property (strong, nonnull) UIImageView *backgroundImageView;

@property (strong, nonatomic) ConnectivityManager *connectivityManager;
@property (strong, nonatomic) SyncManager *syncManager;
@property (strong, nonatomic) AVPlayer *player;

@property (strong, nonatomic) IBOutlet UIImageView *albumImageView;
@property (strong, nonatomic) IBOutlet UILabel *songTitleLabel;
@property (strong, nonatomic) IBOutlet UILabel *songArtistLabel;

@property (strong, nonatomic) IBOutlet UIProgressView *progressBar;

@end

@implementation PlayerViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
  
  // Setup the connectivity manager
  self.connectivityManager = [ConnectivityManager sharedManagerWithDisplayName:[[UIDevice currentDevice] name]];
  [self.connectivityManager advertiseSelfInSessions:YES];
  self.connectivityManager.delegate = self;
  
  // Setup the Network Player Manager
  self.syncManager = [SyncManager sharedManager];
  
  // Setup the player
  self.player = [AVPlayer new];
  
  // Setup the background image view
  if (!self.backgroundImageView) {
    self.backgroundImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:self.backgroundImageView];
    [self.view sendSubviewToBack:self.backgroundImageView];
  }
  
  // Update UI
  [self updatePlayerSongInfo];
  
  // Continue playing when earphones are unplugged
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioHardwareRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
  [super willMoveToParentViewController:parent];
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{// Asyncly handle session end
    // Stop playing
    self.player  = nil;
    
    // Stop advertising
    [self.connectivityManager advertiseSelfInSessions:NO];
    [self.connectivityManager disconnect];
    
    // Stop the session
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setActive:NO error:nil];
  });
}

#pragma mark - ConnectivityManagerDelegate
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
  // We received data from host either
  NSDictionary *payload = [NSKeyedUnarchiver unarchiveObjectWithData:data];

  if ([payload[@"command"] isEqualToString:@"metadata"]) {
    NSLog(@"Peer received song metadata.");
    
    songTitle = [payload[@"songName"] stringByReplacingOccurrencesOfString:@"title " withString:@""];
    songArtist = [payload[@"songArtist"] stringByReplacingOccurrencesOfString:@"artist " withString:@""];
    albumImage = [UIImage imageWithData:payload[@"songAlbumArt"]];
    
    // Update UI at specified date
    [self.syncManager atExactTime:((NSNumber *)payload[@"date"]).unsignedLongLongValue runBlock:^{
      [self performSelectorOnMainThread:@selector(updatePlayerSongInfo) withObject:nil waitUntilDone:YES];
    }];
    
  } else if ([payload[@"command"] isEqualToString:@"play"]) {
    NSLog(@"Peer received 'play' command.");
    
    // Pause the player to reset the time.
    [self.player pause];
    
    // Play at specified date
    [self.syncManager atExactTime:((NSNumber *)payload[@"date"]).unsignedLongLongValue runBlock:^{
      // Set the playback time
      [self.player seekToTime:CMTimeMakeWithSeconds(((NSNumber*)payload[@"commandTime"]).doubleValue, 1000000) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];

      // Play
      [self.player play];
    }];
    
    
  } else if ([payload[@"command"] isEqualToString:@"pause"]) {
    NSLog(@"Peer received 'pause' command.");

    // Pause at specified date
    [self.syncManager atExactTime:((NSNumber *)payload[@"date"]).unsignedLongLongValue runBlock:^{
      [self.player pause];
    }];
  }
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
  
  if (error) {
    NSLog(@"Peer got an error when receiving the song: %@", error);
  }
  
  // If there is no local URL, then this is not a song.
  if (localURL) {
    // Fix the path
    NSString *songPath = [[localURL.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"resource.caf"];
    songURL = [NSURL fileURLWithPath:songPath isDirectory:NO];
    
    // Move the file to change its name to the right format
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtURL:songURL error:&error];// Delete previous song file
    
    if (error) {
      NSLog(@"Peer got an error when deleting the old song: %@", error);
    }

    [fileManager moveItemAtURL:localURL toURL:songURL error:&error];// Move the new song file

    if (error) {
      NSLog(@"Peer got an error when moving the new song: %@", error);
    }
    
    // Load the song
    [self.player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:songURL]];
  
  }
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
  self.progressBar.observedProgress = progress;
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
  if (state == MCSessionStateConnecting) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.songTitleLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Connecting to %@", nil), peerID.displayName]];
    });
    
  } else if (state == MCSessionStateConnected) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.songTitleLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Connected to %@", nil), peerID.displayName]];
    });
    
  } else if (state == MCSessionStateNotConnected) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.songTitleLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Disconnected from %@", nil), peerID.displayName]];
    });
    
    [[NSFileManager defaultManager] removeItemAtURL:songURL error:nil];// Delete previous song file
  }
}

#pragma mark - Player
- (void)audioHardwareRouteChanged:(NSNotification *)notification {
  NSInteger routeChangeReason = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] integerValue];
  if (routeChangeReason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
    // If we're here, the player has been stopped, so play again!
    [self.player play];
  }
}

- (void)updatePlayerSongInfo {
  // Update thge player UI with song info
  UIImage *gradientBackground = [UIImage gradientFromColor:[UIColor generateRandomColor] toColor:[UIColor generateRandomColor] withSize:self.backgroundImageView.frame.size];
  
  // Animate all changes
  [UIView animateWithDuration:0.3 animations:^{
    if (songTitle) {
      [self.songTitleLabel setText:songTitle];
    }
    
    if (songArtist) {
      [self.songArtistLabel setText:songArtist];
    }
    
    [self.backgroundImageView setImage:(albumImage) ? self.backgroundImageView.image : gradientBackground];
  }];
  
  // If there's an album image generate a suitable gradient background
  if (albumImage) {
    // Generate a background gradient to match the album art
    [SLColorArt processImage:albumImage scaledToSize:self.backgroundImageView.frame.size threshold:0.01 onComplete:^(SLColorArt *colorArt) {// Get the SLColorArt
      // Build the gradient
      UIColor *firstColor = [colorArt.backgroundColor darkerColor];
      UIColor *secondColor = [colorArt.backgroundColor lighterColor];
      UIImage *albumGradientBackground = [UIImage gradientFromColor:firstColor toColor:secondColor withSize:self.backgroundImageView.frame.size];
      
      // update the gradient
      [UIView animateWithDuration:0.3 animations:^{
        [self.albumImageView setImage:albumImage];
        [self.backgroundImageView setImage:albumGradientBackground];
      }];
    }];
  }
}

#pragma mark - Other
// White status bar
- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}
@end
