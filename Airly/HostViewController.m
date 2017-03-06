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
  
  // Subscribe to notifications
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
  [self.playerManager.musicController pause];
  [self.connectivityManager disconnect];
}

#pragma mark - Control Actions
- (IBAction)invitePlayers:(UIBarButtonItem *)sender {
  [self presentViewController:self.connectivityManager.browser animated:YES completion:nil];// Browser setup called in ViewDidLoad
}

- (IBAction)addSongs:(UIBarButtonItem *)sender {
  // Disable the button and show the picker
  sender.enabled = NO;
  
  [self.playerManager presentMediaPickerOnController:self completion:^{
    sender.enabled = YES;
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
- (void)playingItemDidChange:(NSNotification *)notification {// Notification isn't nil when the song has changed
  // Update controls
  [self updateControlsForState:AIHostStateUpdatingPeers];

  // Get some needed variables
  __block NSArray *allPeers = [self.connectivityManager allPeers];
  __block MPMediaItem *currentMediaItem = [self.playerManager currentMediaItem];
  
  // Before anything else, check if this is just the same song restarting, if it is just play.
  if ([lastSentMediaItem isEqual:currentMediaItem] && !notification) {// If the song didn't change
    [self startPlaybackAtTime:self.playerManager.musicController.currentPlaybackTime];
    return;
  }
  
  // Pause the music
  [self.playerManager pauseLocallyAndOnHosts:self.connectivityManager.allPeers completion:nil];
  
  if (currentMediaItem && self.syncManager.calibratedPeers.count >= allPeers.count) {// Make sure peers are calibrated and song is loaded
    if (notification) {// Song changed
      // Reset to playback time to 0
      self.playerManager.musicController.currentPlaybackTime = (NSTimeInterval)0;
    }
    
    // Send song metadata to peers, and update Player Song Info.
    uint64_t updateUITime = [self.syncManager sendSongMetadata:currentMediaItem toPeers:allPeers];
    [self.syncManager atExactTime:updateUITime runBlock:^{
      [self performSelectorOnMainThread:@selector(updatePlayerSongInfo) withObject:nil waitUntilDone:YES];
    }];
    
    
    // Track how many peers received and failed
    __block uint peersReceived = 0;
    __block uint peersFailed = 0;
    
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
      if ((peersReceived+peersFailed) >= allPeers.count && peersReceived > 0) {
        [self startPlaybackAtTime:self.playerManager.musicController.currentPlaybackTime];
        lastSentMediaItem = [currentMediaItem copy];// Store the previously sent song for reference.
      
      } else if (peersReceived == 0) {// Retry, nobody received.
        lastSentMediaItem = nil;
        [self playingItemDidChange:notification];
      }
      
      // If a peer failed
      if (peersFailed > 0) {
        // If this song replays it will be sent to all peers since at least one failed.
        lastSentMediaItem = nil;
        
        // Show an error informing the user that some listeners won't be able to play
        NSString *message = [NSString stringWithFormat:@"Sorry but Airly failed to send the song to %u listeners. %@", peersFailed, error.localizedDescription];
        UIAlertController *failedPeerAlert = [UIAlertController alertControllerWithTitle:@"Error Sending" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        [failedPeerAlert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:failedPeerAlert animated:YES completion:nil];
      }
    }];
  }
}

- (void)startPlaybackAtTime:(NSTimeInterval)playbackTime {
  // Tell the player manager to play everywhere
  [self.playerManager playAtPlaybackTime:playbackTime locallyAndOnHosts:self.connectivityManager.allPeers completion:^{
    // Update Controls
    [self updateControlsForState:AIHostStatePlaying];
  }];
}

- (void)pausePlayback {
  // Tell the player manager to pause everywhere
  [self.playerManager pauseLocallyAndOnHosts:self.connectivityManager.allPeers completion:^{
    // Update Controls
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
  // Load the media collection
  [self.playerManager loadMediaCollection:mediaItemCollection];
  [self.playerManager.musicController prepareToPlay];
  
  // Update the control buttons
  [self updateControlsForState:AIHostStateUpdatingPeers];

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
    }
      
      break;
      
    case MCSessionStateNotConnected: {
      [self.songTitleLabel setText:[NSString stringWithFormat:NSLocalizedString(@"Disconnected from %@", nil), peerID.displayName]];
      [self updateControlsForState:AIHostStateDisconnected];
      
      break;
    }
      
    default:
      break;
  }
}

#pragma mark - UI Handling
- (void)updateControlsForState:(AIHostState)hostState {
  // Update player controls based on state
  switch (hostState) {
    case AIHostStatePaused: {
      NSMutableArray *toolbarButtons = [self.playbackControlsToolbar.items mutableCopy];
      
      if (![toolbarButtons containsObject:self.playerManager] && [toolbarButtons containsObject:self.pausePlaybackButton]) {
        [toolbarButtons replaceObjectAtIndex:[toolbarButtons indexOfObject:self.pausePlaybackButton] withObject:self.playPlaybackButton];
      }
      
      // Remove the pause button, enable the play button.
      self.playPlaybackButton.enabled = YES;
      
      [self.playbackControlsToolbar setItems:toolbarButtons animated:YES];
      self.pausePlaybackButton.enabled = NO;
      
      break;
    }
      
    case AIHostStatePlaying: {
      NSMutableArray *toolbarButtons = [self.playbackControlsToolbar.items mutableCopy];
      
      if (![toolbarButtons containsObject:self.pausePlaybackButton] && [toolbarButtons containsObject:self.playPlaybackButton]) {
        [toolbarButtons replaceObjectAtIndex:[toolbarButtons indexOfObject:self.playPlaybackButton] withObject:self.pausePlaybackButton];
      }
      
      // Remove the play button, enable the pause button.
      self.pausePlaybackButton.enabled = YES;
      
      [self.playbackControlsToolbar setItems:toolbarButtons animated:YES];
      self.playPlaybackButton.enabled = NO;
      
      break;
    }
      
    case AIHostStateSkipping:
      // Update forward & next buttons
      self.forwardPlaybackButton.enabled = ([self.playerManager nextMediaItem]) ? YES : NO;
      self.rewindPlaybackButton.enabled = ([self.playerManager previousMediaItem]) ? YES : NO;

      break;
      
    case AIHostStateDisconnected:
      
    case AIHostStateUpdatingPeers:
      
    default:
      self.pausePlaybackButton.enabled = NO;
      self.playPlaybackButton.enabled = NO;
      self.forwardPlaybackButton.enabled = NO;
      self.rewindPlaybackButton.enabled = NO;
      
      break;
  }
}

- (void)updatePlayerSongInfo {
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

// White status bar
- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}

@end
