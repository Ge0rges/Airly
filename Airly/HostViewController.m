//
//  HostViewController.m
//  Airly
//
//  Created by Georges Kanaan on 2/17/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "HostViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "ConnectivityManager.h"
#import "PlayerManager.h"

@interface HostViewController () <ConnectivityManagerDelegate, PlayerManagerDelegate>

@property (nonatomic, strong) ConnectivityManager *connectivityManger;
@property (nonatomic, strong) PlayerManager *playerManager;

@property (strong, nonatomic) IBOutlet UIImageView *albumImageView;
@property (strong, nonatomic) IBOutlet UILabel *songTitleLabel;
@property (strong, nonatomic) IBOutlet UILabel *songArtistLabel;

@end

@implementation HostViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
  
  // Setup the Connectivity Manager
  self.connectivityManger = [[ConnectivityManager alloc] initWithPeerWithDisplayName:[[UIDevice currentDevice] name]];
  [self.connectivityManger setupBrowser];
  self.connectivityManger.delegate = self;
  
  // Setup the Player Manager
  self.playerManager = [PlayerManager new];
  self.playerManager.delegate = self;
  
  NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
  
  [notificationCenter addObserver:self selector:@selector(playingItemDidChange) name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:nil];
  
  [self.playerManager.musicController beginGeneratingPlaybackNotifications];
}

#pragma mark - Connectivity
- (IBAction)invitePlayers:(UIBarButtonItem *)sender {
  [self presentViewController:self.connectivityManger.browser animated:YES completion:nil];
}

- (void)sendSongToPeers {
  // Get all peers
  NSMutableArray *peers = [NSMutableArray new];
  for (MCSession *session in self.connectivityManger.sessions) {
    for (MCPeerID *peerID in session.connectedPeers) {
      [peers addObject:peerID];
    }
  }
  
  // Send the song metadata
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    // Create the metadata
    NSData *titleData = [NSKeyedArchiver archivedDataWithRootObject:@{@"command": @"title", @"data": [self.playerManager currentSongName]}];
    NSData *artistData = [NSKeyedArchiver archivedDataWithRootObject:@{@"command": @"artist", @"data": [self.playerManager currentSongArtist]}];
    NSData *imageData = [NSKeyedArchiver archivedDataWithRootObject:@{@"command": @"albumImage", @"data": UIImagePNGRepresentation([self.playerManager currentSongAlbumArt])}];

    [self.connectivityManger sendData:artistData toPeers:peers reliable:YES];
    [self.connectivityManger sendData:imageData toPeers:peers reliable:YES];
    [self.connectivityManger sendData:titleData toPeers:peers reliable:YES];
    
  });
  
  // Send the song file
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    // Get resource path
    NSString *tempPath = NSTemporaryDirectory();
    NSURL *url = [[self.playerManager currentSong] valueForProperty:MPMediaItemPropertyAssetURL];
    
    AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:songAsset presetName:AVAssetExportPresetPassthrough];
    exporter.outputFileType = @"com.apple.coreaudio-format";
    
    NSString *fname = [@"play" stringByAppendingString:@".caf"];
    NSString *exportFile = [tempPath stringByAppendingPathComponent:fname];
    
    exporter.outputURL = [NSURL fileURLWithPath:exportFile];
    
    [exporter exportAsynchronouslyWithCompletionHandler:^{
      // Send resource file
      [self.connectivityManger sendResourceAtURL:exporter.outputURL withName:[self.playerManager currentSongName] toPeers:peers withCompletionHandler:^(NSError *error) {
        if (!error) {
          // Enable the play button
          UIBarButtonItem *btn = (UIBarButtonItem *)[self.view viewWithTag:1];
          [btn setEnabled:YES];
          
          // Start playing
          [self playButtonPressed:btn];
        }
        
      }];
    }];
  });
}

#pragma mark - Player
- (void)updatePlayerUI {
  [self.albumImageView setImage:[self.playerManager currentSongAlbumArt]];
  [self.songArtistLabel setText:[self.playerManager currentSongArtist]];
  [self.songTitleLabel setText:[self.playerManager currentSongName]];
}

- (IBAction)addSongs:(UIBarButtonItem *)sender {
  [self.playerManager presentMediaPickerOnController:self];
}

- (IBAction)rewindButtonPressed:(id)sender {
  // Go to previous song
  [self playButtonPressed:(UIBarButtonItem *)[self.view viewWithTag:1]];
  [self.playerManager previousSong];
  
  // Send song to peers
  [self sendSongToPeers];
  
  // Update UI
  [self updatePlayerUI];
}

- (IBAction)playButtonPressed:(UIBarButtonItem *)sender {
  NSString *command = @"";
  
  if (self.playerManager.musicController.playbackState == MPMusicPlaybackStatePlaying) {
    command = @"play";
    [sender setTitle:@"||"];
    
  }  else if (self.playerManager.musicController.playbackState == MPMusicPlaybackStatePaused) {
    command = @"pause";
    [sender setTitle:@"►"];
  }
  
  // Get peers
  NSMutableArray *peers = [NSMutableArray new];
  for (MCSession *session in self.connectivityManger.sessions) {
    for (MCPeerID *peerID in session.connectedPeers) {
      [peers addObject:peerID];
    }
  }
  
  // Create NSData to send
  NSDate *dateToPlay = [NSDate dateWithTimeIntervalSinceNow:1];
  NSData *dataToSend = [NSKeyedArchiver archivedDataWithRootObject:@{@"command": command,
                                                                     @"data": dateToPlay,
                                                                     @"playTime": [NSNumber numberWithDouble:[self.playerManager.musicController currentPlaybackTime]]
                                                                     }
                        ];
  
  // Send data
  [self.connectivityManger sendData:dataToSend toPeers:peers reliable:YES];
  
  // Play at the same time
  if ([command isEqualToString:@"play"]) {
    // Play at specified date
    NSTimer *playTimer = [NSTimer timerWithTimeInterval:0 target:self.playerManager selector:@selector(play) userInfo:nil repeats:NO];
    playTimer.fireDate = dateToPlay;
    
    [[NSRunLoop mainRunLoop] addTimer:playTimer forMode:@"NSDefaultRunLoopMode"];
    
  } else if ([command isEqualToString:@"pause"]) {
    // Pause at specified date
    NSTimer *pauseTimer = [NSTimer timerWithTimeInterval:0 target:self.playerManager selector:@selector(pause) userInfo:nil repeats:NO];
    pauseTimer.fireDate = dateToPlay;
    
    [[NSRunLoop mainRunLoop] addTimer:pauseTimer forMode:@"NSDefaultRunLoopMode"];
    
  }
}

- (IBAction)forwardButtonPressed:(id)sender {
  // Go to next song and pause
  [self playButtonPressed:(UIBarButtonItem *)[self.view viewWithTag:1]];

  [self.playerManager nextSong];
  
  // Send song to peers
  [self sendSongToPeers];
  
  // Update UI
  [self updatePlayerUI];
}

- (void)playingItemDidChange {
  // Pause song and update button
  [self.playerManager pause];
  [self playButtonPressed:(UIBarButtonItem *)[self.view viewWithTag:1]];
  
  // Send song to peers
  [self sendSongToPeers];
  
  // Update UI
  [self updatePlayerUI];
}

#pragma mark - ConnectivityManagerDelegate & PlayerManagerDelegate
- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
  // Disable the play button
  UIBarButtonItem *playButton = (UIBarButtonItem *)[self.view viewWithTag:1];
  [playButton setEnabled:NO];
  
  // Load the media collection
  [self.playerManager loadMediaCollection:mediaItemCollection];
  
  // Set the current playing item
  [self.playerManager.musicController prepareToPlay];
  
  // Send song
  [self sendSongToPeers];
  
  // Update UI
  [self updatePlayerUI];
  
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
      
    case MCSessionStateConnected:
      NSLog(@"Connected to %@", peerID.displayName);
      
      if ([self.playerManager.musicController nowPlayingItem]) {
        [self sendSongToPeers];
      }
      
      break;
      
    case MCSessionStateNotConnected:
      NSLog(@"Disconnected from %@", peerID.displayName);
      break;
      
    default:
      break;
  }
}

#pragma mark - Navigation
- (IBAction)dismissView:(id)sender {
  [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
