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

typedef NS_ENUM(NSUInteger, AIHostState) {
  AIHostStateUpdatingPeers, // The state of the host.
  AIHostStatePlaying,
  AIHostStateSkipping,
  AIHostStatePaused,
  AIHostStateDisconnected
};

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

@property (strong, nonatomic) IBOutlet UIProgressView *progressBar;

@property (strong, nonatomic) IBOutlet UIBarButtonItem *pausePlaybackButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *playPlaybackButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *forwardPlaybackButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *rewindPlaybackButton;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *addSongsButton;
@property (strong, nonatomic) IBOutlet UIToolbar *playbackControlsToolbar;

@end

@implementation HostViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
  
  // Setup the Player Manager
  self.playerManager = [PlayerManager sharedManager];
  self.playerManager.delegate = self;
  
  // Subscribe to notifications
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playingItemDidChange:) name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:self.playerManager.musicController];
  //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateDidChange:) name:MPMusicPlayerControllerPlaybackStateDidChangeNotification object:self.playerManager.musicController];

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
  [self updatePlayerSongInfo];
  [self updateControlsForState:AIHostStateDisconnected];
  
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
  [self.playerManager.musicController stop];
  self.playerManager = nil;
  [self.connectivityManager disconnect];
}

#pragma mark - Control Actions
- (IBAction)invitePlayers:(UIBarButtonItem *)sender {
  [self presentViewController:self.connectivityManager.browser animated:YES completion:nil];// Browser setup called in ViewDidLoad
}

- (IBAction)addSongs:(UIBarButtonItem *)sender {
  // Disable the button and show the picker
  self.addSongsButton.enabled = NO;
  
  [self.playerManager presentMediaPickerOnController:self completion:^{
    self.addSongsButton.enabled = YES;
  }];
}

- (IBAction)playbackToggleButtonPressed:(UIBarButtonItem *)sender {
  [self updateControlsForState:AIHostStateUpdatingPeers];
  
  // A playback toggle control button was pressed.
  if (self.playerManager.musicController.playbackState == MPMusicPlaybackStatePlaying) {
    [self pausePlayback];
    
  } else  {
    [self startPlaybackAtTime:self.playerManager.musicController.currentPlaybackTime];
  }
}

- (IBAction)rewindButtonPressed:(id)sender {
  // Update Controls
  [self updateControlsForState:AIHostStateSkipping];
  
  // Pause
  [self.playerManager.musicController pause];
  
  // Go to next song
  [self.playerManager skipToPreviousSongLocally];
}

- (IBAction)forwardButtonPressed:(id)sender {
  // Update Controls
  [self updateControlsForState:AIHostStateSkipping];
  
  // Pause
  [self.playerManager.musicController pause];
  
  // Go to next song
  [self.playerManager skipToNextSongLocally];
}

#pragma mark - Playing State Changers
//- (void)playbackStateDidChange:(NSNotification *)notification {
//    // In the future this will be used when we use the system music player.
//}

- (void)playingItemDidChange:(NSNotification *)notification {// Notification isn't nil when the song has changed
  // Update controls
  [self updateControlsForState:AIHostStateUpdatingPeers];

  // Get some needed variables
  __block MPMediaItem *currentMediaItem = [self.playerManager currentMediaItem];
  
  // Reset playback time to 0
  self.playerManager.musicController.currentPlaybackTime = (NSTimeInterval)0;

  // Prepare to play
  [self.playerManager.musicController prepareToPlay];
  
  // Pause the music
  [self.playerManager pauseLocallyAndOnHosts:self.connectivityManager.allPeers completion:nil];
  
  // Check if the player is just looping
  if (self.playerManager.musicController.indexOfNowPlayingItem == 0 && [self.playerManager.mediaCollection.items indexOfObject:lastSentMediaItem] == self.playerManager.mediaCollection.items.count-1) {
    [self updateControlsForState:AIHostStatePaused];
    return;
  }
  
  // Before anything else, check if this is just the same song restarting, if it is just play.
  if ([lastSentMediaItem isEqual:currentMediaItem]) {// If the song didn't change
    [self startPlaybackAtTime:self.playerManager.musicController.currentPlaybackTime];
    return;
  }
  
  // Different song, update network.
  if (currentMediaItem) {// Make sure peers are calibrated and song is loaded
    // Send song metadata to peers, and update Player Song Info.
    [self.syncManager sendSongMetadata:currentMediaItem toPeers:self.connectivityManager.allPeers];
    [self updatePlayerSongInfo];
    
    // Track how many peers received and failed
    __block uint peersReceived = 0;
    __block uint peersFailed = 0;
    
    // Send the song to all peers
    [self.syncManager sendSong:currentMediaItem toPeers:self.connectivityManager.allPeers progress:^(NSArray<NSProgress *> * _Nullable progressArray) {
      [self updateProgressBarWithProgressArray:progressArray];
      
    } completion:^(NSError * _Nullable error) {
      // Increment the peers received number.
      if (error) {
        peersFailed++;
        NSLog(@"Airly failed sending song with error: %@", error);
        
      } else {
        peersReceived++;
        NSLog(@"Airly sent song.");
      }
      
      // If we got a response from everyone, and at least one peer received: play.
      if ((peersReceived+peersFailed) >= self.connectivityManager.allPeers.count && peersReceived > 0) {
        [self startPlaybackAtTime:self.playerManager.musicController.currentPlaybackTime];
        lastSentMediaItem = [currentMediaItem copy];// Store the previously sent song for reference.
        
      } else if (peersReceived == 0 && self.connectivityManager.allPeers.count > 0) {// Retry, nobody received.
        lastSentMediaItem = nil;
        [self playingItemDidChange:notification];
      }
      
      // If a peer failed
      if (peersFailed > 0 && self.connectivityManager.allPeers.count > 0) {
        // If this song replays it will be sent to all peers since at least one failed.
        lastSentMediaItem = nil;
        
        // Show an error informing the user that some listeners won't be able to play
        NSString *message = [NSString stringWithFormat:@"Sorry but Airly failed to send the song to %u listeners. %@", peersFailed, error.localizedDescription];
        UIAlertController *failedPeerAlert = [UIAlertController alertControllerWithTitle:@"Error Sending" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        [failedPeerAlert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:failedPeerAlert animated:YES completion:nil];
      }
    }];
    
  } else {
    NSLog(@"Song changed, asked to pause, completion called but song is: %@ and calibrated is: %lu and peers is: %lu so FAILED", currentMediaItem, self.syncManager.calibratedPeers.count, self.connectivityManager.allPeers.count);
  }

}

- (void)startPlaybackAtTime:(NSTimeInterval)playbackTime {
  NSLog(@"Submitting network play for song time: %f", playbackTime);
  
  // Tell the player manager to play everywhere
  [self.playerManager playAtPlaybackTime:playbackTime locallyAndOnHosts:self.connectivityManager.allPeers completion:^{
    // Update Controls
    [self updateControlsForState:AIHostStatePlaying];
  }];
}

- (void)pausePlayback {
  // Tell the player manager to pause everywhere
  [self.playerManager pauseLocallyAndOnHosts:self.connectivityManager.allPeers completion:^{
    // Upd ate Controls
    [self updateControlsForState:AIHostStatePaused];
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
  // Update the control buttons
  if ([mediaItemCollection.items[0] isEqual:[self.playerManager currentMediaItem]]) {// Song didn't change
    [self updateControlsForState:AIHostStatePlaying];

  } else {// Song changed
    [self updateControlsForState:AIHostStateUpdatingPeers];
  }
  
  // Load the media collection
  [self.playerManager loadMediaCollection:mediaItemCollection];
  [self.playerManager.musicController prepareToPlay];

  // Dismiss the media picker
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
  switch (state) {
    case MCSessionStateConnecting: {
      [self.songTitleLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Connecting to %@", nil), peerID.displayName]];
      
      break;
    }
      
    case MCSessionStateConnected: {
      [self.songTitleLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Connected to %@", nil), peerID.displayName]];
      
      // Ask peers to calibrate
      [self.syncManager askPeersToCalculateOffset:@[peerID]];
      NSLog(@"Asked peer: %@ to calibrate.", peerID);
      
      // If a song is loaded whent the peer calibrates, send it over.
      [self.syncManager executeBlockWhenEachPeerCalibrates:@[peerID] block:^(NSArray<MCPeerID *> * _Nullable peers) {
        NSLog(@"Peer: %@ calibrated", peers);
        
        if ([self.playerManager currentMediaItem]) {
          NSLog(@"Peer: %@ calibrated, sending song and song metadata.", peers);
          // Send the song info
          [self.syncManager sendSongMetadata:[self.playerManager currentMediaItem] toPeers:@[peerID]];
          [self.syncManager sendSong:[self.playerManager currentMediaItem] toPeers:@[peerID] progress:^(NSArray<NSProgress *> * _Nullable progressArray) {
            [self updateProgressBarWithProgressArray:progressArray];
            
          } completion:^(NSError * _Nullable error) {
            // If music is playing, send the command to have the peer sync in.
            if (self.playerManager.musicController.playbackState == MPMusicPlaybackStatePlaying && !error && [self.playerManager currentMediaItem]) {
#warning not good enough sync
              // [self.syncManager synchronisePlayWithCurrentPlaybackTime:self.playerManager.musicController.currentPlaybackTime whileHostPlaying:YES];
            }
          }];
        }
      }];
    };
      
      
      break;
      
    case MCSessionStateNotConnected: {
      [self.songTitleLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Disconnected from %@", nil), peerID.displayName]];
      
      break;
    }
      
    default:
      break;
  }
}

#pragma mark - UI Handling
- (void)updateControlsForState:(AIHostState)hostState {
  dispatch_async(dispatch_get_main_queue(), ^{// Everything on the main thread
    // Update player controls based on state
    NSMutableArray *toolbarButtons = [self.playbackControlsToolbar.items mutableCopy];
    
    switch (hostState) {
      case AIHostStatePaused: {
        [toolbarButtons removeObject:self.pausePlaybackButton];
        
        if (![toolbarButtons containsObject:self.playPlaybackButton]) {
          [toolbarButtons insertObject:self.playPlaybackButton atIndex:3];
        }
        
        // Remove the pause button, enable the play button.
        self.playPlaybackButton.enabled = YES;
        
        [self.playbackControlsToolbar setItems:toolbarButtons animated:YES];
        self.pausePlaybackButton.enabled = NO;
        
        // Allow song changing
        self.addSongsButton.enabled = YES;

        break;
      }
        
      case AIHostStatePlaying: {
        [toolbarButtons removeObject:self.playPlaybackButton];
        
        if (![toolbarButtons containsObject:self.pausePlaybackButton]) {
          [toolbarButtons insertObject:self.pausePlaybackButton atIndex:3];
        }
        
        // Remove the play button, enable the pause button.
        self.pausePlaybackButton.enabled = YES;
        
        [self.playbackControlsToolbar setItems:toolbarButtons animated:YES];
        self.playPlaybackButton.enabled = NO;
        
        // Update forward & next buttons
        self.forwardPlaybackButton.enabled = ([self.playerManager nextMediaItem]) ? YES : NO;
        self.rewindPlaybackButton.enabled = ([self.playerManager previousMediaItem]) ? YES : NO;
        
        // Allow song changing
        self.addSongsButton.enabled = YES;
        
        break;
      }

      case AIHostStateDisconnected: {
        // Show a disabled play button
        [toolbarButtons removeObject:self.pausePlaybackButton];
        
        if (![toolbarButtons containsObject:self.playPlaybackButton]) {
          [toolbarButtons insertObject:self.playPlaybackButton atIndex:3];
        }
        
        [self.playbackControlsToolbar setItems:toolbarButtons animated:YES];
        
        // Enable adding songs
        self.addSongsButton.enabled = YES;
        
        // Disable all control buttons
        self.pausePlaybackButton.enabled = NO;
        self.playPlaybackButton.enabled = NO;
        self.forwardPlaybackButton.enabled = NO;
        self.rewindPlaybackButton.enabled = NO;
        
        break;
      }
        
      case AIHostStateSkipping:
        
      case AIHostStateUpdatingPeers:
        self.addSongsButton.enabled = NO;

      default:
        self.pausePlaybackButton.enabled = NO;
        self.playPlaybackButton.enabled = NO;
        self.forwardPlaybackButton.enabled = NO;
        self.rewindPlaybackButton.enabled = NO;
        
        break;
    }
  });
}

- (void)updatePlayerSongInfo {
  dispatch_async(dispatch_get_main_queue(), ^{// Everything on the main thread
    // Update thge player UI with song info
    UIImage *albumImage = [self.playerManager currentSongAlbumArt];
    
    // Animate all changes
    [UIView animateWithDuration:0.3 animations:^{
      if ([self.playerManager currentSongName]) {
        [self.songTitleLabel setText:[self.playerManager currentSongName]];
      }
      
      if ([self.playerManager currentSongArtist]) {
        [self.songArtistLabel setText:[self.playerManager currentSongArtist]];
      }
      
      if (!albumImage) {
        [self.backgroundImageView setImage:[UIImage gradientFromColor:[UIColor generateRandomColor] toColor:[UIColor generateRandomColor] withSize:self.backgroundImageView.frame.size]];
      }
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
  });
}

- (void)updateProgressBarWithProgressArray:(NSArray <NSProgress *> *)progressArray {
  NSProgress *parentProgress = [NSProgress progressWithTotalUnitCount:progressArray.count];
  
  for (NSProgress *progress in progressArray) {
    [parentProgress addChild:progress withPendingUnitCount:1];
  }
  
  self.progressBar.observedProgress = parentProgress;
}

// White status bar
- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

@end
