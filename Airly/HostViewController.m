//
//  HostViewController.m
//  Airly
//
//  Created by Georges Kanaan on 2/17/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "HostViewController.h"

// Frameworks
#import <AVFoundation/AVFoundation.h>

// Classes
#import "SLColorArt.h"

// Managers
#import "ConnectivityManager.h"
#import "PlayerManager.h"
#import "SyncManager.h"

// Extensions
#import "UIImage+Gradient.h"
#import "UIColor+Helpers.h"

@interface HostViewController () <ConnectivityManagerDelegate, PlayerManagerDelegate, UINavigationBarDelegate> {
  BOOL didInitialSetup;
  MPMediaItem *lastSentMediaItem;
}

@property (nonatomic, strong) ConnectivityManager *connectivityManager;
@property (nonatomic, strong) PlayerManager *playerManager;
@property (nonatomic, strong) SyncManager *syncManager;

@property (strong, nonnull) UIImageView *backgroundImageView;// Created in view did load

@property (strong, nonatomic) IBOutlet UIImageView *albumImageView;
@property (strong, nonatomic) IBOutlet UILabel *songTitleLabel;
@property (strong, nonatomic) IBOutlet UILabel *songArtistLabel;

@property (strong, nonatomic) IBOutlet UIBarButtonItem *pausePlaybackButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *playPlaybackButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *forwardPlaybackButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *rewindPlaybackButton;
@property (strong, nonatomic) IBOutlet UIToolbar *playbackControlsToolbar;

@end

@implementation HostViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
  
  // Setup the Player Manager
  self.playerManager = [PlayerManager sharedManager];
  self.playerManager.delegate = self;
  
  // Notification for song did change
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playingItemDidChange:) name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:self.playerManager.musicController];
  
  [self.playerManager.musicController beginGeneratingPlaybackNotifications];
  
  // Setup networkManager
  self.syncManager = [SyncManager sharedManager];
  
  // Setup the Connectivity Manager
  self.connectivityManager = [ConnectivityManager sharedManagerWithDisplayName:[[UIDevice currentDevice] name]];
  self.connectivityManager.delegate = self;
  self.connectivityManager.syncManager = self.syncManager;
  
  [self.connectivityManager setupBrowser];
  
  // Create a background image view
  if (!self.backgroundImageView) {
    self.backgroundImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:self.backgroundImageView];
    [self.view sendSubviewToBack:self.backgroundImageView];
  }
  
  // Update player UI
  [self updatePlayerSong];
  
  // Update player controls
  NSMutableArray *toolbarButtons = [self.playbackControlsToolbar.items mutableCopy];

  // 1.Remove pause button (initial)
  if ([toolbarButtons containsObject:self.pausePlaybackButton]) {
    [toolbarButtons removeObject:self.pausePlaybackButton];
  }
  
  // 2.All control buttons disabled at start.
  self.pausePlaybackButton.enabled = NO;
  self.playPlaybackButton.enabled = NO;
  self.forwardPlaybackButton.enabled = NO;
  self.rewindPlaybackButton.enabled = NO;
  
  [self.playbackControlsToolbar setItems:toolbarButtons animated:YES];
  
  // Transparent toolbar
  [self.playbackControlsToolbar setBackgroundImage:[UIImage new] forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
  [self.playbackControlsToolbar setShadowImage:[UIImage new] forToolbarPosition:UIBarPositionAny];  
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  
  // Guide the user on launch (both play and pause will be present)
  if (!didInitialSetup) {
    // Start the initial workflow by inviting players.
    [self invitePlayers:nil];
    didInitialSetup = YES;
  }
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
  [super willMoveToParentViewController:parent];
  
  // Disconnect from sessions
  [self.connectivityManager disconnect];
}

#pragma mark - Connectivity
- (IBAction)invitePlayers:(UIBarButtonItem *)sender {
  [self presentViewController:self.connectivityManager.browser animated:YES completion:nil];// Browser setup called in ViewDidLoad
}

- (void)updatePlayerSong {
  // Update thge player UI with song info
  UIImage *albumImage = [self.playerManager currentSongAlbumArt];
  UIImage *gradientBackground = [UIImage gradientFromColor:[UIColor generateRandomColor] toColor:[UIColor generateRandomColor] withSize:self.backgroundImageView.frame.size];
  
  // Animate all changes
  [UIView animateWithDuration:0.3 animations:^{
    if ([self.playerManager currentSongName]) {
      [self.songTitleLabel setText:[self.playerManager currentSongName]];
    }
    
    if ([self.playerManager currentSongArtist]) {
      [self.songArtistLabel setText:[self.playerManager currentSongArtist]];
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

- (IBAction)addSongs:(UIBarButtonItem *)sender {
  // Disable the button and show the picker
  sender.enabled = NO;
  
  [self.playerManager presentMediaPickerOnController:self completion:^{
    sender.enabled = YES;
  }];
}

- (IBAction)playbackToggleButtonPressed:(UIBarButtonItem *)sender {
  // A playback toggle control button was pressed.
  if (self.playerManager.musicController.playbackState == MPMusicPlaybackStatePlaying) {
    [self pausePlayback];
    
  } else  {
    [self startPlaybackAtTime:self.playerManager.musicController.currentPlaybackTime];
  }
}

- (IBAction)rewindButtonPressed:(id)sender {
  // Update Controls
  self.forwardPlaybackButton.enabled = NO;
  self.rewindPlaybackButton.enabled = NO;
  self.playPlaybackButton.enabled = NO;
  self.pausePlaybackButton.enabled = NO;
  
  // Pause
  [self.playerManager.musicController pause];
  
  // Go to next song
  [self.playerManager skipToPreviousSong];
}

- (IBAction)forwardButtonPressed:(id)sender {
  // Update Controls
  self.forwardPlaybackButton.enabled = NO;
  self.rewindPlaybackButton.enabled = NO;
  self.playPlaybackButton.enabled = NO;
  self.pausePlaybackButton.enabled = NO;
  
  // Pause
  [self.playerManager.musicController pause];
  
  // Go to next song
  [self.playerManager skipToNextSong];
}

- (void)playingItemDidChange:(NSNotification *)notification {// Notification isn't nil when the song has changed
  // Get some needed variables
  __block NSArray *allPeers = [self.connectivityManager allPeers];
  __block MPMediaItem *currentMediaItem = [self.playerManager currentMediaItem];
  
  // Disable the control buttons
  dispatch_async(dispatch_get_main_queue(), ^{
    self.playPlaybackButton.enabled = NO;
    self.pausePlaybackButton.enabled = NO;
    self.forwardPlaybackButton.enabled = NO;
    self.rewindPlaybackButton.enabled = NO;
  });
  
  // Pause the music
  [self.playerManager pauseLocallyAndOnHosts:self.connectivityManager.allPeers completion:nil];
  
  if (currentMediaItem && self.syncManager.calibratedPeers.count >= allPeers.count) {// Make sure peers are calibrated and song is loaded
    // Before anything else, check if this is just the same song restarting, if it is just play.
    if ([lastSentMediaItem isEqual:currentMediaItem] && !notification) {// If the song didn't change
      [self startPlaybackAtTime:self.playerManager.musicController.currentPlaybackTime];
      return;
    }
    
    // Check if the song changed
    if (notification) {
      // Reset to playback time to 0
      self.playerManager.musicController.currentPlaybackTime = (NSTimeInterval)0;
    }
    
    // Send song metadata to peers
    uint64_t updateUITime = [self.syncManager sendSongMetadata:currentMediaItem toPeers:allPeers];

    // Update UI at specified date after asking to sync.
    [self.syncManager atExactTime:updateUITime runBlock:^{
      [self performSelectorOnMainThread:@selector(updatePlayerSong) withObject:nil waitUntilDone:YES];
    }];
    
    // Track how many peers received and failed
    __block NSUInteger peersReceived = 0;
    __block NSUInteger peersFailed = 0;
    
    // Send the song to all peers
    [self.syncManager sendSong:currentMediaItem toPeers:allPeers completion:^(NSError * _Nullable error) {
      // Increment the peers received number.
      if (error) {
        peersFailed++;
        NSLog(@"Airly failed sending song with error: %@", error);
        
      } else {
        peersReceived++;
      }
      
      // If we got a response from everyone, and at least one peer received: play.
      if ((peersReceived+peersFailed) >= allPeers.count && peersReceived > 0 && [currentMediaItem isEqual:[self.playerManager currentMediaItem]]) {
        [self startPlaybackAtTime:self.playerManager.musicController.currentPlaybackTime];
        lastSentMediaItem = [currentMediaItem copy];// Store the previously sent song for reference.
      }
      
      // If a peer failed
      if (peersFailed > 0) {
        // If this song replays it will be sent to all peers since at least one failed.
        lastSentMediaItem = nil;
        
        if (peersReceived == 0) {// Nobody received the song retry
          [self playingItemDidChange:notification];
          return;
        }
        
        // Show an error informing the user that some listeners won't be able to play
        NSString *message = [NSString stringWithFormat:@"Sorry but Airly failed to send the song to %lu listeners. %@", (unsigned long)peersFailed, error.localizedDescription];
        UIAlertController *failedPeerAlert = [UIAlertController alertControllerWithTitle:@"Error Sending" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        [failedPeerAlert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:failedPeerAlert animated:YES completion:nil];
      }
    }];
  }
}

- (void)startPlaybackAtTime:(NSTimeInterval)playbackTime {
  // Disable the control buttons
  dispatch_async(dispatch_get_main_queue(), ^{
    self.playPlaybackButton.enabled = NO;
    self.pausePlaybackButton.enabled = NO;
    self.forwardPlaybackButton.enabled = NO;
    self.rewindPlaybackButton.enabled = NO;
  });
  
  // Tell the player manager to play everywhere
  [self.playerManager playAtPlaybackTime:playbackTime locallyAndOnHosts:self.connectivityManager.allPeers completion:^{
    // Update controls.
    NSMutableArray *toolbarButtons = [self.playbackControlsToolbar.items mutableCopy];
    
    if (![toolbarButtons containsObject:self.pausePlaybackButton] && [toolbarButtons containsObject:self.playPlaybackButton]) {
      [toolbarButtons replaceObjectAtIndex:[toolbarButtons indexOfObject:self.playPlaybackButton] withObject:self.pausePlaybackButton];
    }
    
    // Remove the play button, enable the pause button.
    self.pausePlaybackButton.enabled = YES;
    
    [self.playbackControlsToolbar setItems:toolbarButtons animated:YES];
    self.playPlaybackButton.enabled = NO;
    
    // Update forward & next buttons
    self.forwardPlaybackButton.enabled = ([self.playerManager nextMediaItem]) ? YES : NO;
    self.rewindPlaybackButton.enabled = ([self.playerManager previousMediaItem]) ? YES : NO;
  }];
}

- (void)pausePlayback {
  // Disable the control buttons
  dispatch_async(dispatch_get_main_queue(), ^{
    self.playPlaybackButton.enabled = NO;
    self.pausePlaybackButton.enabled = NO;
    self.forwardPlaybackButton.enabled = NO;
    self.rewindPlaybackButton.enabled = NO;
  });
  
  // Tell the player manager to pause everywhere
  [self.playerManager pauseLocallyAndOnHosts:self.connectivityManager.allPeers completion:^{
    // Update control buttons
    NSMutableArray *toolbarButtons = [self.playbackControlsToolbar.items mutableCopy];
    
    if (![toolbarButtons containsObject:self.playPlaybackButton]) {
      [toolbarButtons replaceObjectAtIndex:[toolbarButtons indexOfObject:self.pausePlaybackButton] withObject:self.playPlaybackButton];
    }
    
    // Disable the pause button and enable the play button
    self.playPlaybackButton.enabled = YES;

    [self.playbackControlsToolbar setItems:toolbarButtons animated:YES];
    self.pausePlaybackButton.enabled = NO;
    
    // Update forward & next buttons
    self.forwardPlaybackButton.enabled = ([self.playerManager nextMediaItem]) ? YES : NO;
    self.rewindPlaybackButton.enabled = ([self.playerManager previousMediaItem]) ? YES : NO;
  }];
}

#pragma mark - ConnectivityManagerDelegate & PlayerManagerDelegate
- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
  [self dismissViewControllerAnimated:YES completion:^{
    // If the user hasn't picked any songs yet, ask them too.
    if (![self.playerManager currentMediaItem]) {
      [self addSongs:nil];
    }
  }];
}

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
  // Disable the control buttons
  self.playPlaybackButton.enabled = NO;
  self.pausePlaybackButton.enabled = NO;
  self.forwardPlaybackButton.enabled = NO;
  self.rewindPlaybackButton.enabled = NO;
  
  // Load the media collection
  [self.playerManager loadMediaCollection:mediaItemCollection];
  [self.playerManager.musicController prepareToPlay];
  
  // Update the next button if the current song won't change and is playing
  if (self.playerManager.musicController.playbackState == MPMusicPlaybackStatePlaying && [mediaItemCollection.items[0] isEqual:[self.playerManager currentMediaItem]]) {
    self.forwardPlaybackButton.enabled = ([self.playerManager nextMediaItem]) ? YES : NO;
  }
  
  // Dismiss the media picker
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
  switch (state) {
    case MCSessionStateConnecting: {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.songTitleLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Connecting to %@", nil), peerID.displayName]];
      });
      
      break;
    }
      
    case MCSessionStateConnected: {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.songTitleLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Connected to %@", nil), peerID.displayName]];
        
        // Disable the buttons if paused
        if (self.playerManager.musicController.playbackState != MPMusicPlaybackStatePlaying) {
          self.playPlaybackButton.enabled = NO;
          self.pausePlaybackButton.enabled = NO;
          self.forwardPlaybackButton.enabled = NO;
          self.rewindPlaybackButton.enabled = NO;
        }
      });

      // Ask peer to calculate offset.
      [self.syncManager askPeersToCalculateOffset:@[peerID]];
      
      // Wait for peer to calibrate then send the appropriate data.
      [self.syncManager executeBlockWhenAllPeersCalibrate:@[peerID] block:^(NSArray<MCPeerID *> * _Nullable peers) {
        // Already loaded a song. Send song to this peer only
        MPMediaItem *currentMediaItem = [self.playerManager currentMediaItem];
        if (currentMediaItem) {
          // Send song metadata to peers
          [self.syncManager sendSongMetadata:currentMediaItem toPeers:peers];
          
          // Send song to peers
          [self.syncManager sendSong:currentMediaItem toPeers:peers completion:^(NSError * _Nullable error) {
            if (self.playerManager.musicController.playbackState != MPMusicPlaybackStatePlaying) {
              [self playingItemDidChange:nil];
            }
          }];
        }
      }];
    }
      
      break;
      
    case MCSessionStateNotConnected: {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.songTitleLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Disconnected from %@", nil), peerID.displayName]];
      });
      
      break;
    }
      
    default:
      break;
  }
}

// White status bar
- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

@end
