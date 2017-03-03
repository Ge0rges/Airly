//
//  HostViewController.m
//  Airly
//
//  Created by Georges Kanaan on 2/17/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "HostViewController.h"

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

@property (strong, nonnull) UIImageView *backgroundImageView;

@property (strong, nonatomic) IBOutlet UIImageView *albumImageView;
@property (strong, nonatomic) IBOutlet UILabel *songTitleLabel;
@property (strong, nonatomic) IBOutlet UILabel *songArtistLabel;

@property (strong, nonatomic) IBOutlet UIBarButtonItem *pausePlaybackButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *playPlaybackButton;
@property (strong, nonatomic) IBOutlet UIToolbar *playbackControlsToolbar;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *forwardPlaybackButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *rewindPlaybackButton;

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
#warning test accuracy
  self.syncManager.numberOfCalibrations = 5000;
  
  // Setup the Connectivity Manager
  self.connectivityManager = [ConnectivityManager sharedManagerWithDisplayName:[[UIDevice currentDevice] name]];
  self.connectivityManager.delegate = self;
  self.connectivityManager.syncManager = self.syncManager;
  
  [self.connectivityManager setupBrowser];
  
  // Set a gradient as the background image
  if (!self.backgroundImageView) {
    self.backgroundImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:self.backgroundImageView];
    [self.view sendSubviewToBack:self.backgroundImageView];
  }
  
  UIImage *gradientBackground = [UIImage gradientFromColor:[UIColor generateRandomColor] toColor:[UIColor generateRandomColor] withSize:self.backgroundImageView.frame.size];
  [self.backgroundImageView setImage:gradientBackground];
  
  // Transparent toolbar
  [self.playbackControlsToolbar setBackgroundImage:[UIImage new] forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
  [self.playbackControlsToolbar setShadowImage:[UIImage new] forToolbarPosition:UIBarPositionAny];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  
  NSMutableArray *toolbarButtons = [self.playbackControlsToolbar.items mutableCopy];
  
  // Guide the user on launch (both play and pause will be present)
  if (!didInitialSetup) {
    
    // Start the initial workflow by inviting players.
    [self invitePlayers:nil];
    didInitialSetup = YES;
    
    // Remove pause button (initial)
    if ([toolbarButtons containsObject:self.pausePlaybackButton]) {
      [toolbarButtons removeObject:self.pausePlaybackButton];
    }
    
    self.pausePlaybackButton.enabled = NO;
    self.playPlaybackButton.enabled = NO;
    self.forwardPlaybackButton.enabled = NO;
    self.rewindPlaybackButton.enabled = NO;
    
    [self.playbackControlsToolbar setItems:toolbarButtons animated:YES];
  }
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
  [super willMoveToParentViewController:parent];
  
  // Disconnect seassions
  [self.connectivityManager disconnect];
}

#pragma mark - Connectivity
- (IBAction)invitePlayers:(UIBarButtonItem *)sender {
  [self presentViewController:self.connectivityManager.browser animated:YES completion:nil];
}


#pragma mark - Player
- (void)updatePlayerUI {
  // Update thge player UI with song info
  UIImage *albumImage = [self.playerManager currentSongAlbumArt];
  
  if (albumImage) {
    // Generate a background gradient to match the album art
    CGSize imageViewSize = self. backgroundImageView.frame.size;
    [SLColorArt processImage:albumImage scaledToSize:imageViewSize threshold:0.01 onComplete:^(SLColorArt *colorArt) {// Get the SLColorArt (object of processed UIImage)
      // Build the gradient
      UIColor *firstColor = [colorArt.backgroundColor darkerColor];
      UIColor *secondColor = [colorArt.backgroundColor lighterColor];
      UIImage *gradientBackground = [UIImage gradientFromColor:firstColor toColor:secondColor withSize:imageViewSize];
      
      // Animate all changes
      [UIView animateWithDuration:0.3 animations:^{
        [self.albumImageView setImage:albumImage];
        [self.songArtistLabel setText:[self.playerManager currentSongArtist]];
        [self.songTitleLabel setText:[self.playerManager currentSongName]];
        
        [self.backgroundImageView setImage:gradientBackground];
      }];
    }];
    
  } else {
    // Random gradient
    UIImage *gradientBackground = [UIImage gradientFromColor:[UIColor generateRandomColor] toColor:[UIColor generateRandomColor] withSize:self.backgroundImageView.frame.size];
    
    // Animate all changes
    [UIView animateWithDuration:0.3 animations:^{
      [self.albumImageView setImage:nil];
      [self.songArtistLabel setText:[self.playerManager currentSongArtist]];
      [self.songTitleLabel setText:[self.playerManager currentSongName]];
      
      [self.backgroundImageView setImage:gradientBackground];
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


  // Reset to playback time to 0
  self.playerManager.musicController.currentPlaybackTime = (NSTimeInterval)0;
  
  // Go to next song
  [self.playerManager skipToPreviousSong];
}

- (IBAction)forwardButtonPressed:(id)sender {
  // Update Controls
  self.forwardPlaybackButton.enabled = NO;
  self.rewindPlaybackButton.enabled = NO;
  self.playPlaybackButton.enabled = NO;
  self.pausePlaybackButton.enabled = NO;


  // Reset to playback time to 0
  self.playerManager.musicController.currentPlaybackTime = (NSTimeInterval)0;
  
  // Go to next song
  [self.playerManager skipToNextSong];
}

- (void)playingItemDidChange:(NSNotification *)notification {
  // Get some needed variables
  __block NSArray *allPeers = [self.connectivityManager allPeers];
  __block MPMediaItem *currentMediaItem = [self.playerManager currentMediaItem];
  
  
  if (currentMediaItem && self.syncManager.calibratedPeers.count >= allPeers.count) {// Make sure peers are calibrated and song is loaded
    // Before anything else, check if this is just the same song restarting, if it is just play.
    if ([lastSentMediaItem isEqual:currentMediaItem]) {
      [self startPlaybackAtTime:self.playerManager.musicController.currentPlaybackTime];
      return;
    }
    
    
    if (self.playerManager.musicController.playbackState == MPMusicPlaybackStatePlaying) {// Song still palying so pause the music
      [self.playerManager pause];
      [self performSelectorInBackground:@selector(pausePlayback) withObject:nil];
      [NSThread sleepForTimeInterval:1.2];// For some reason this avoids issues on peers, probably a queue thing.
    }
    
    if (notification) {// Check if the song changed
      // Reset to playback time to 0
      self.playerManager.musicController.currentPlaybackTime = (NSTimeInterval)0;
    }
    
    // Disable the control buttons
    dispatch_async(dispatch_get_main_queue(), ^{
      self.playPlaybackButton.enabled = NO;
      self.pausePlaybackButton.enabled = NO;
      self.forwardPlaybackButton.enabled = NO;
      self.rewindPlaybackButton.enabled = NO;
    });
    
    // Send song metadata to peers
    uint64_t updateUITime = [self.syncManager sendSongMetadata:currentMediaItem toPeers:allPeers];
    
    // Update UI at specified date
    [self.syncManager atExactTime:updateUITime runBlock:^{
      [self performSelectorOnMainThread:@selector(updatePlayerUI) withObject:nil waitUntilDone:YES];
    }];
    
    
    __block NSUInteger peersReceived = 0;
    __block NSUInteger peersFailed = 0;
    [self.syncManager sendSong:currentMediaItem toPeers:allPeers completion:^(NSError * _Nullable error) {
      // Increment the peers received number.
      if (error) {
        peersFailed++;
        NSLog(@"Airly failed sending song with error: %@", error);
        
      } else {
        peersReceived++;
      }
      
      // If we got a response from everyone, and at least one peer received.
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
        NSString *message = [NSString stringWithFormat:@"Sorry but Airly failed to send the song to %lu listeners. %@", peersFailed, error.localizedDescription];
        UIAlertController *failedPeerAlert = [UIAlertController alertControllerWithTitle:@"Error Sending" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        [failedPeerAlert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:failedPeerAlert animated:YES completion:nil];

      }
    }];
    
  // Not the same song
  } else if (!currentMediaItem){
    [self pausePlayback];// This will update the UI for a end of song and resync.
  }
}

- (void)startPlaybackAtTime:(NSTimeInterval)playbackTime {
  // Order a Synchronize play
  uint64_t timeToPlay = [self.syncManager synchronisePlayWithCurrentPlaybackTime:playbackTime];
  
  // Play at specified date
  [self.syncManager atExactTime:timeToPlay runBlock:^{
    // Set the playback time on the current device
    if (playbackTime != self.playerManager.musicController.currentPlaybackTime) {
      self.playerManager.musicController.currentPlaybackTime = playbackTime;
    }
    
    // Play
    [self.playerManager play];
  }];
  
  // Update control buttons.
  dispatch_async(dispatch_get_main_queue(), ^{
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
  });
}

- (void)pausePlayback {
  // Order a synchronized pause
  uint64_t timeToPause = [self.syncManager synchronisePause];
  
  // Pause at specified date
  [self.syncManager atExactTime:timeToPause runBlock:^{
    [self.playerManager pause];
  }];
  
  // Take this opportunity to resync
  [self.syncManager askPeersToCalculateOffset:self.connectivityManager.allPeers];
  
  // Update control buttons
  dispatch_async(dispatch_get_main_queue(), ^{
    NSMutableArray *toolbarButtons = [self.playbackControlsToolbar.items mutableCopy];
    
    if (![toolbarButtons containsObject:self.playPlaybackButton]) {
      [toolbarButtons replaceObjectAtIndex:[toolbarButtons indexOfObject:self.pausePlaybackButton] withObject:self.playPlaybackButton];
    }
    
    // Add the play button, disable the pause button
    self.playPlaybackButton.enabled = YES;
    
    [self.playbackControlsToolbar setItems:toolbarButtons animated:YES];
    self.pausePlaybackButton.enabled = NO;
    
    // Update forward & next buttons
    self.forwardPlaybackButton.enabled = ([self.playerManager nextMediaItem]) ? YES : NO;
    self.rewindPlaybackButton.enabled = ([self.playerManager previousMediaItem]) ? YES : NO;
  });
}

#pragma mark - ConnectivityManagerDelegate & PlayerManagerDelegate
- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
  [self dismissViewControllerAnimated:YES completion:^{
    // If the user hasn't picked any songs yet, ask him too.
    if (![self.playerManager currentMediaItem]) {
      [self addSongs:nil];
    }
  }];
}

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
  // Disable the play forward and next buttons
  // Pause won't cause any issues and will be replaced by a disabled play anyway.
  self.playPlaybackButton.enabled = NO;
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
      });
      
      // Ask peer to calculate offset.
      [self.syncManager askPeersToCalculateOffset:@[peerID]];
      
      // Wait for peer to calibrate then send the appropriate data.
      [self.syncManager executeBlockWhenPeerCalibrates:peerID block:^(MCPeerID * _Nullable peer) {
        // Already loaded a song. Send song to this peer only
        MPMediaItem *currentMediaItem = [self.playerManager currentMediaItem];
        if (currentMediaItem) {
          if (self.playerManager.musicController.playbackState != MPMusicPlaybackStatePlaying) {
            [self playingItemDidChange:nil];
            return;
          }
          
          // Send song metadata to peers
          [self.syncManager sendSongMetadata:currentMediaItem toPeers:@[peer]];
          
          // Send song to peers
          [self.syncManager sendSong:currentMediaItem toPeers:@[peer] completion:nil];
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
