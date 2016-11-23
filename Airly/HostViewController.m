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
#import "HostPlayerManager.h"

@interface HostViewController () <ConnectivityManagerDelegate, PlayerManagerDelegate> {
  NSTimer *nowPlayingItemTimer;
  BOOL presentedInitialWorkflow;
}

@property (nonatomic, strong) ConnectivityManager *connectivityManager;
@property (nonatomic, strong) PlayerManager *playerManager;

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
  
  // Setup the Connectivity Manager
  self.connectivityManager = [ConnectivityManager sharedInstanceWithDisplayName:[[UIDevice currentDevice] name]];
  [self.connectivityManager setupBrowser];
  self.connectivityManager.delegate = self;
  
  // Setup the Player Manager
  self.playerManager = [PlayerManager sharedInstance];
  self.playerManager.delegate = self;
  
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
  NSDate *updateUIDate = [HostPlayerManager sendSongMetadata:[self.playerManager currentMediaItem] toPeers:[self.connectivityManager allPeers]];
  
  // Update UI at specified date
  NSTimer *updateUITimer = [NSTimer timerWithTimeInterval:0 target:self selector:@selector(updatePlayerUI) userInfo:nil repeats:NO];
  updateUITimer.fireDate = updateUIDate;
  
  [[NSRunLoop mainRunLoop] addTimer:updateUITimer forMode:@"NSDefaultRunLoopMode"];
  

#warning when skipping through songs, they will all be sent and played.
  // Send song to peers
  __block NSInteger peersReceived = 0;
  [HostPlayerManager sendSong:[self.playerManager currentMediaItem] toPeers:[self.connectivityManager allPeers] completion:^(NSError * _Nullable error) {
    // Increment the peers received number.
    if (!error) {
      peersReceived +=1;
    }
    
    if (peersReceived == [self.connectivityManager allPeers].count) {
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
  NSDate *dateToPlay = [HostPlayerManager synchronisePlayWithCurrentTime:self.playerManager.musicController.currentPlaybackTime];
  
  // Play at specified date
  NSTimer *playTimer = [NSTimer timerWithTimeInterval:0 target:self.playerManager selector:@selector(play) userInfo:nil repeats:NO];
  playTimer.fireDate = dateToPlay;
  
  [[NSRunLoop mainRunLoop] addTimer:playTimer forMode:@"NSDefaultRunLoopMode"];
  
  // Set a timer to update at the end of the song
  if ([self.playerManager nextMediaItem]) {
    nowPlayingItemTimer = [NSTimer timerWithTimeInterval:0 target:self selector:@selector(playingItemDidChange) userInfo:nil repeats:NO];
    
    NSInteger timeLeft = (self.playerManager.musicController.nowPlayingItem.playbackDuration - self.playerManager.musicController.currentPlaybackTime);
    nowPlayingItemTimer.fireDate = [NSDate dateWithTimeInterval:timeLeft+0.01 sinceDate:dateToPlay];
    
    [[NSRunLoop mainRunLoop] addTimer:nowPlayingItemTimer forMode:@"NSDefaultRunLoopMode"];
    
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
  
  // Remove the timer.
  [nowPlayingItemTimer invalidate];
  nowPlayingItemTimer = nil;
  
  // Order a synchronized pause
  NSDate *dateToPause = [HostPlayerManager synchronisePause];
  
  // Pause at specified date
  NSTimer *pauseTimer = [NSTimer timerWithTimeInterval:0 target:self.playerManager selector:@selector(pause) userInfo:nil repeats:NO];
  pauseTimer.fireDate = dateToPause;
  
  [[NSRunLoop mainRunLoop] addTimer:pauseTimer forMode:@"NSDefaultRunLoopMode"];
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
        #warning figure out a way to make the peer be in the same status.
        [HostPlayerManager sendSongMetadata:nowPlayingItem toPeers:@[peerID]];
        [HostPlayerManager sendSong:nowPlayingItem toPeers:@[peerID] completion:nil];
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
