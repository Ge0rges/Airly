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
  uint64_t endSongTime;
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
  
  // Notifications when playing item changes (for syncing).
  [self.playerManager.musicController beginGeneratingPlaybackNotifications];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playingItemDidChange) name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:nil];
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
  
  if ([self.playerManager nextMediaItem]) {
    self.forwardPlaybackButton.enabled = YES;
  }
  
  if ([self.playerManager previousMediaItem]) {
    self.rewindPlaybackButton.enabled = YES;
  }
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
    [self startPlayback];
  }
}

- (IBAction)rewindButtonPressed:(id)sender {
  // Pause playback
  [self pausePlayback];
  
  // Go to next song
  [self.playerManager performSelector:@selector(skipToPreviousSong) withObject:nil afterDelay:0.2];
  
  // Notify that the playing item changed
  [self performSelector:@selector(playingItemDidChange) withObject:nil afterDelay:0.22];
}

- (IBAction)forwardButtonPressed:(id)sender {
  // Pause playback
  [self pausePlayback];
  
  // Go to next song
  [self.playerManager performSelector:@selector(skipToNextSong) withObject:nil afterDelay:0.2];
  
  // Notify that the playing item changed
  [self performSelector:@selector(playingItemDidChange) withObject:nil afterDelay:0.22];
}

- (void)playingItemDidChange {
  // Pause playback
  [self pausePlayback];
  
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
  __block MPMediaItem *currentMediaItem = [self.playerManager currentMediaItem];
  [self.networkPlayerManager sendSong:currentMediaItem toPeers:[self.connectivityManager allPeers] completion:^(NSError * _Nullable error) {
    // Increment the peers received number.
    if (!error) {
      peersReceived +=1;
    }
    
    if (peersReceived == [self.connectivityManager allPeers].count && [currentMediaItem isEqual:[self.playerManager currentMediaItem]]) {
      [self startPlayback];
    }
  }];
}

- (void)startPlayback {
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
  uint64_t timeToPlay = [self.networkPlayerManager synchronisePlayWithCurrentPlaybackTime:self.playerManager.musicController.currentPlaybackTime];
  
  // Play at specified date
  [self.networkPlayerManager atExactTime:timeToPlay runBlock:^{
    [self.playerManager play];
  }];
  
  // Set a timer to update at the end of the song
  if ([self.playerManager nextMediaItem]) {
    NSInteger timeLeft = (self.playerManager.musicController.nowPlayingItem.playbackDuration - self.playerManager.musicController.currentPlaybackTime);
    
    endSongTime = [self.networkPlayerManager currentTime] + timeLeft*1000000000;// Seconds to Nanoseconds
    
    [self.networkPlayerManager atExactTime:endSongTime runBlock:^{
      if (llabs((int64_t)([self.networkPlayerManager currentTime] - endSongTime)) <= 10) {// Make sure the endSongTime is still valid
        [self playingItemDidChange];// Manually notify the player of the song change.
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
    case MCSessionStateConnecting:
      NSLog(@"Connecting to %@", peerID.displayName);
      break;
      
    case MCSessionStateConnected: {
      NSLog(@"Connected to %@", peerID.displayName);
      
      // Already loaded/playing a song, update only the new peer.
      MPMediaItem *nowPlayingItem = [self.playerManager.musicController nowPlayingItem];
      if (nowPlayingItem) {
        [self.networkPlayerManager sendSongMetadata:nowPlayingItem toPeers:@[peerID]];
        
        __block MPMediaItem *currentMediaItem = [self.playerManager currentMediaItem];
        [self.networkPlayerManager sendSong:nowPlayingItem toPeers:@[peerID] completion:^(NSError * _Nullable error) {
          if ([currentMediaItem isEqual:[self.playerManager currentMediaItem]] && self.playerManager.musicController.playbackState == MPMusicPlaybackStatePlaying) {
#warning this should be calculated (offset between host and peer.)
            // Play at current playback time + the time of the delay (1 second) + the time for the message to be received. (hardcoded)
            //[self.networkPlayerManager synchronisePlayWithCurrentPlaybackTime:self.playerManager.musicController.currentPlaybackTime + 1.2];
          }
        }];
      }
    }
      
      break;
      
    case MCSessionStateNotConnected:
      NSLog(@"Disconnected from %@", peerID.displayName);
      break;
      
    default:
      break;
  }
}


@end
