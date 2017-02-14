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
#import "NetworkPlayerManager.h"

// Extensions
#import "UIImage+Gradient.h"
#import "UIColor+Helpers.h"

@interface HostViewController () <ConnectivityManagerDelegate, PlayerManagerDelegate> {
  BOOL presentedInitialWorkflow;
}

@property (nonatomic, strong) ConnectivityManager *connectivityManager;
@property (nonatomic, strong) PlayerManager *playerManager;
@property (nonatomic, strong) NetworkPlayerManager *networkPlayerManager;

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

  // Setup NetworkPlayerManager
  self.networkPlayerManager = [NetworkPlayerManager sharedManager];
  
  // Setup the Connectivity Manager
  self.connectivityManager = [ConnectivityManager sharedManagerWithDisplayName:[[UIDevice currentDevice] name]];
  self.connectivityManager.delegate = self;
  self.connectivityManager.networkPlayerManager = self.networkPlayerManager;
  
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
        
        self.forwardPlaybackButton.enabled = ([self.playerManager nextMediaItem]) ? YES : NO;
        self.rewindPlaybackButton.enabled = ([self.playerManager previousMediaItem]) ? YES : NO;
        
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
      
      self.forwardPlaybackButton.enabled = ([self.playerManager nextMediaItem]) ? YES : NO;
      self.rewindPlaybackButton.enabled = ([self.playerManager previousMediaItem]) ? YES : NO;
      
      [self.backgroundImageView setImage:gradientBackground];
    }];
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
    [self startPlaybackAtTime:self.playerManager.musicController.currentPlaybackTime];
  }
}

- (IBAction)rewindButtonPressed:(id)sender {
  [self.playerManager pause];
  [self pausePlayback];
  
  // Reset to playback time to 0
  self.playerManager.musicController.currentPlaybackTime = (NSTimeInterval)0;
  
  // Go to next song
  [self.playerManager skipToPreviousSong];
}

- (IBAction)forwardButtonPressed:(id)sender {
  [self.playerManager pause];
  [self pausePlayback];
  
  // Reset to playback time to 0
  self.playerManager.musicController.currentPlaybackTime = (NSTimeInterval)0;
  
  // Go to next song
  [self.playerManager skipToNextSong];
}

- (void)playingItemDidChange:(NSNotification *)notification {
  // Make sure to pause the music.
  if (notification && self.playerManager.musicController.playbackState == MPMusicPlaybackStatePlaying) {// Song ended, then changed.
    [self.playerManager pause];
    [self pausePlayback];
    
    // Reset to playback time to 0
    self.playerManager.musicController.currentPlaybackTime = (NSTimeInterval)0;
  }
  
  // Disable the play/pause buttons
  dispatch_async(dispatch_get_main_queue(), ^{
    self.playPlaybackButton.enabled = NO;
    self.pausePlaybackButton.enabled = NO;
  });
  
  // Get some needed avriables
  __block MPMediaItem *sentMediaItem = [self.playerManager currentMediaItem];
  __block NSArray *allPeers = [self.connectivityManager allPeers];

  // Send song metadata to peers
  uint64_t updateUITime = [self.networkPlayerManager sendSongMetadata:sentMediaItem toPeers:allPeers];
  
  // Update UI at specified date
  [self.networkPlayerManager atExactTime:updateUITime runBlock:^{
    [self performSelectorOnMainThread:@selector(updatePlayerUI) withObject:nil waitUntilDone:NO];
  }];
  
  
  // Send song to peers
  __block NSInteger peersReceived = 0;
  __block NSInteger peersFailed = 0;
  [self.networkPlayerManager sendSong:sentMediaItem toPeers:allPeers completion:^(NSError * _Nullable error) {
    // Increment the peers received number.
    if (!error) {
      peersReceived++;
      
    } else {
      peersFailed++;
    }
    
    if ((peersReceived+peersFailed) >= allPeers.count && [sentMediaItem isEqual:[self.playerManager currentMediaItem]]) {
      [self startPlaybackAtTime:self.playerManager.musicController.currentPlaybackTime];
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
  
  // Set the playback time on the current device
  if (playbackTime != self.playerManager.musicController.currentPlaybackTime) {
    self.playerManager.musicController.currentPlaybackTime = playbackTime;
  }
  
  // Order a Synchronize play
  uint64_t timeToPlay = [self.networkPlayerManager synchronisePlayWithCurrentPlaybackTime:playbackTime];
  
  // Play at specified date
  [self.networkPlayerManager atExactTime:timeToPlay runBlock:^{
    [self.playerManager play];
  }];
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
      
      // Already loaded a song.
      if (self.playerManager.currentMediaItem) {
        [self playingItemDidChange:nil];
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

// White status bar
- (UIStatusBarStyle)preferredStatusBarStyle {
  return UIStatusBarStyleLightContent;
}


@end
