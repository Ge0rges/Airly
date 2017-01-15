//
//  HostViewController.m
//  Airly
//
//  Created by Georges Kanaan on 2/17/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "HostViewController.h"

// Managers
#import "ConnectivityManager.h"
#import "PlayerManager.h"
#import "NetworkPlayerManager.h"

@interface HostViewController () <ConnectivityManagerDelegate, PlayerManagerDelegate> {
  BOOL presentedInitialWorkflow;
  __block uint64_t endSongTime;
  __block MPMediaItem *mediaItemAtCheck;
}

@property (nonatomic, strong) ConnectivityManager *connectivityManager;
@property (nonatomic, strong) PlayerManager *playerManager;
@property (nonatomic, strong) NetworkPlayerManager *networkPlayerManager;

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
  
  // Setup NetworkPlayerManager
  self.networkPlayerManager = [NetworkPlayerManager sharedManager];
  
  // Setup the Connectivity Manager
  self.connectivityManager = [ConnectivityManager sharedManagerWithDisplayName:[[UIDevice currentDevice] name]];
  self.connectivityManager.delegate = self;
  self.connectivityManager.networkPlayerManager = self.networkPlayerManager;
  
  [self.connectivityManager setupBrowser];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  
  // Guide the user on launch.
  if (!presentedInitialWorkflow) {
    presentedInitialWorkflow = YES;
    
    // Start the initial workflow by inviting players.
    [self invitePlayers:nil];
    
    // Remove pause button (initial)
    NSMutableArray *toolbarButtons = [self.playbackControlsToolbar.items mutableCopy];
    
    if ([toolbarButtons containsObject:self.pausePlaybackButton]) {
      [toolbarButtons removeObject:self.pausePlaybackButton];
    }
    
    self.pausePlaybackButton.enabled = NO;
    self.playPlaybackButton.enabled = NO;
    
    [self.playbackControlsToolbar setItems:toolbarButtons animated:YES];
  }
}

#pragma mark - Connectivity
- (IBAction)invitePlayers:(UIBarButtonItem *)sender {
  [self presentViewController:self.connectivityManager.browser animated:YES completion:nil];
}

#pragma mark - Player
- (void)updatePlayerUI {
  [self.albumImageView setImage:[self.playerManager currentSongAlbumArt]];
  [self.songArtistLabel setText:[self.playerManager currentSongArtist]];
  [self.songTitleLabel setText:[self.playerManager currentSongName]];
  
  self.forwardPlaybackButton.enabled = ([self.playerManager nextMediaItem]) ? YES : NO;
  self.rewindPlaybackButton.enabled = ([self.playerManager previousMediaItem]) ? YES : NO;
}

- (IBAction)addSongs:(UIBarButtonItem *)sender {
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
  [self pausePlayback];
  
  // Go to next song
  [self.playerManager skipToPreviousSong];
  
  // Notify that the playing item changed
  [self playingItemDidChange];
}

- (IBAction)forwardButtonPressed:(id)sender {
  [self pausePlayback];
  
  // Go to next song
  [self.playerManager skipToNextSong];
  
  // Notify that the playing item changed
  [self playingItemDidChange];
}

- (void)playingItemDidChange {
  // Disable the play/pause buttons
  dispatch_async(dispatch_get_main_queue(), ^{
    self.playPlaybackButton.enabled = NO;
    self.pausePlaybackButton.enabled = NO;
    
  });
  
  // Send song metadata to peers
  uint64_t updateUITime = [self.networkPlayerManager sendSongMetadata:[self.playerManager currentMediaItem] toPeers:[self.connectivityManager allPeers]];
  
  // Update UI at specified date
  [self.networkPlayerManager atExactTime:updateUITime runBlock:^{
    [self performSelectorOnMainThread:@selector(updatePlayerUI) withObject:nil waitUntilDone:NO];
  }];

  
  // Send song to peers
  __block NSInteger peersReceived = 0;
  __block NSInteger peersFailed = 0;
  __block MPMediaItem *currentMediaItem = [self.playerManager currentMediaItem];
  [self.networkPlayerManager sendSong:currentMediaItem toPeers:[self.connectivityManager allPeers] completion:^(NSError * _Nullable error) {
    // Increment the peers received number.
    if (!error) {
      peersReceived +=1;
      
    } else {
      peersFailed += 1;
    }
    
    if (peersReceived+peersFailed == [self.connectivityManager allPeers].count && [currentMediaItem isEqual:[self.playerManager currentMediaItem]]) {
      [self startPlaybackAtTime:0];
    }
  }];
}

- (void)startPlaybackAtTime:(NSTimeInterval)playbackTime {
  // Hide play button. Show pause button.
  dispatch_async(dispatch_get_main_queue(), ^{
    NSMutableArray *toolbarButtons = [self.playbackControlsToolbar.items mutableCopy];
    
    if (![toolbarButtons containsObject:self.pausePlaybackButton] && [toolbarButtons containsObject:self.playPlaybackButton]) {
      [toolbarButtons replaceObjectAtIndex:[toolbarButtons indexOfObject:self.playPlaybackButton] withObject:self.pausePlaybackButton];
    }
    
    self.playPlaybackButton.enabled = NO;
    
    [self.playbackControlsToolbar setItems:toolbarButtons animated:YES];
    self.pausePlaybackButton.enabled = YES;
  });
  
  // Order a Synchronize play
  uint64_t timeToPlay = [self.networkPlayerManager synchronisePlayWithCurrentPlaybackTime:playbackTime];
  
  // Play at specified date
  [self.networkPlayerManager atExactTime:timeToPlay runBlock:^{
    [self.playerManager play];
  }];
  
  // Set a timer to update at the end of the song
  if ([self.playerManager nextMediaItem]) {
    NSInteger timeLeft = (self.playerManager.musicController.nowPlayingItem.playbackDuration - self.playerManager.musicController.currentPlaybackTime);
    
    endSongTime = self.networkPlayerManager.currentTime + timeLeft*1000000000;// Seconds to Nanoseconds
    
    mediaItemAtCheck = [self.playerManager currentMediaItem];
    
    [self.networkPlayerManager atExactTime:endSongTime runBlock:^{
      uint64_t timeAtCheck =  self.networkPlayerManager.currentTime;
      
      if (timeAtCheck - endSongTime <= 10000 && (self.playerManager.musicController.nowPlayingItem.playbackDuration - self.playerManager.musicController.currentPlaybackTime) < 2) {// Make sure the endSongTime is still valid
        if ([mediaItemAtCheck isEqual:[self.playerManager currentMediaItem]]) {// The song might have a not switched yet
          [self forwardButtonPressed:nil];// Go to next song
          
        } else {
          [self pausePlayback];
          
          [self playingItemDidChange];// Notify the player of the song change.
        }
      }
    }];
  }
}

- (void)pausePlayback {
  // Hide pause button. Show play button.
  dispatch_async(dispatch_get_main_queue(), ^{
    NSMutableArray *toolbarButtons = [self.playbackControlsToolbar.items mutableCopy];
    
    if (![toolbarButtons containsObject:self.playPlaybackButton]) {
      [toolbarButtons replaceObjectAtIndex:[toolbarButtons indexOfObject:self.pausePlaybackButton] withObject:self.playPlaybackButton];
    }
    
    self.pausePlaybackButton.enabled = NO;
    
    [self.playbackControlsToolbar setItems:toolbarButtons animated:YES];
    self.playPlaybackButton.enabled = YES;
  });
  
  // Order a synchronized pause
  uint64_t timeToPause = [self.networkPlayerManager synchronisePause];
  
  // Pause at specified date
  [self.networkPlayerManager atExactTime:timeToPause runBlock:^{
    [self.playerManager pause];
  }];
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
  // Disable the play button
  UIBarButtonItem *playButton = (UIBarButtonItem *)[self.view viewWithTag:1];
  [playButton setEnabled:NO];
  
  // Load the media collection
  [self.playerManager loadMediaCollection:mediaItemCollection];
  [self.playerManager.musicController prepareToPlay];
  
  // Notify that the playing item changed
  [self playingItemDidChange];
  
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
        [self.songTitleLabel setText:[NSString stringWithFormat:@"Connecting to %@", peerID.displayName]];
      });
      
      break;
    }
      
    case MCSessionStateConnected: {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.songTitleLabel setText:[NSString stringWithFormat:@"Connected to %@", peerID.displayName]];
      });
      
      // Already loaded a song, update only the new peer.
      if (self.playerManager.currentMediaItem) {
        [self playingItemDidChange];
      }
    }
      
      break;
      
    case MCSessionStateNotConnected: {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.songTitleLabel setText:[NSString stringWithFormat:@"Disconnected from %@", peerID.displayName]];
      });
      
      break;
    }
      
    default:
      break;
  }
}


@end
