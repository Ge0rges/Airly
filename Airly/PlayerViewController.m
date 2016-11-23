//
//  PlayerViewController.m
//  Airly
//
//  Created by Georges Kanaan on 2/19/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "PlayerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "ConnectivityManager.h"

@interface PlayerViewController () <ConnectivityManagerDelegate> {
  unsigned long receivingItemMaxCount;
  
  NSString *songTitle;
  NSString *songArtist;
  
  UIImage *albumImage;
}

@property (nonatomic, strong) ConnectivityManager *connectivityManger;
@property (nonatomic, strong) AVPlayer *player;

@property (strong, nonatomic) IBOutlet UIImageView *albumImageView;
@property (strong, nonatomic) IBOutlet UILabel *songTitleLabel;
@property (strong, nonatomic) IBOutlet UILabel *songArtistLabel;


@end

@implementation PlayerViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view.
  
  //setup the connectivity manager
  self.connectivityManger = [ConnectivityManager sharedInstanceWithDisplayName:[[UIDevice currentDevice] name]];
  [self.connectivityManger advertiseSelfInSessions:YES];
  self.connectivityManger.delegate = self;
  
  // Setup the player
  self.player = [AVPlayer new];
  
  // Configure the AVAudioSession
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  [audioSession setActive:YES error:nil];
  [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
}


#pragma mark - ConnectivityManagerDelegate
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
  // We received data from host either
  NSDictionary *dataDic = [NSKeyedUnarchiver unarchiveObjectWithData:data];

  if ([dataDic[@"command"] isEqualToString:@"metadata"]) {
    NSLog(@"received metadata");

    songTitle = [dataDic[@"songName"] stringByReplacingOccurrencesOfString:@"title " withString:@""];
    songArtist = [dataDic[@"songArtist"] stringByReplacingOccurrencesOfString:@"artist " withString:@""];
    albumImage = [UIImage imageWithData:dataDic[@"songAlbumArt"]];
    
    [self performSelectorOnMainThread:@selector(updatePlayerUI) withObject:nil waitUntilDone:NO];

  } else if ([dataDic[@"command"] isEqualToString:@"play"]) {
    NSLog(@"received command to play");
        
    // Play at specified date
    NSTimer *playTimer = [NSTimer timerWithTimeInterval:0 target:self.player selector:@selector(play) userInfo:nil repeats:NO];
    playTimer.fireDate = (NSDate*)dataDic[@"date"];
    
    [[NSRunLoop mainRunLoop] addTimer:playTimer forMode:@"NSDefaultRunLoopMode"];
    
    // Set the playback time
    [self.player seekToTime:CMTimeMakeWithSeconds(((NSNumber*)dataDic[@"commandTime"]).doubleValue, 1000000)];
    
  } else if ([dataDic[@"command"] isEqualToString:@"pause"]) {
    NSLog(@"received command to pause");

    // Pause at specified date
    NSTimer *pauseTimer = [NSTimer timerWithTimeInterval:0 target:self.player selector:@selector(pause) userInfo:nil repeats:NO];
    pauseTimer.fireDate = (NSDate*)dataDic[@"date"];
    
    [[NSRunLoop mainRunLoop] addTimer:pauseTimer forMode:@"NSDefaultRunLoopMode"];
    
  }
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
  
  // If there is no local URL, then this is not a song.
  if (localURL) {
    NSLog(@"got a song: %@", resourceName);
    
    // Fix the path
    NSString *fixedPath = [[localURL.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"resourc.caf"];
    NSURL *fixedURL = [NSURL fileURLWithPath:fixedPath isDirectory:NO];
    
    // Move the file to change its name to the right format
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtURL:fixedURL error:&error];//delete current song (old)
    [fileManager moveItemAtURL:localURL toURL:fixedURL error:nil];//move the new song file

    // Load the song
    [self.player replaceCurrentItemWithPlayerItem:[AVPlayerItem playerItemWithURL:fixedURL]];
  }
}

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
  if (state == MCSessionStateConnecting) {
    NSLog(@"Connecting to %@", peerID.displayName);
  
  } else if (state == MCSessionStateConnected) {
    NSLog(@"Connected to %@", peerID.displayName);

  } else if (state == MCSessionStateNotConnected) {
    NSLog(@"Disconnected from %@", peerID.displayName);
  }
}

#pragma mark - Player
- (void)updatePlayerUI {
  [self.albumImageView setImage:albumImage];
  [self.songArtistLabel setText:songArtist];
  [self.songTitleLabel setText:songTitle];
}

#pragma mark - Navigation
- (IBAction)dismissView:(id)sender {
  [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
