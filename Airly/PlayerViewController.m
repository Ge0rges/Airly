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
  
  NSMutableArray *localSongUrls;
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
  self.connectivityManger = [[ConnectivityManager alloc] initWithPeerWithDisplayName:[[UIDevice currentDevice] name]];
  [self.connectivityManger advertiseSelfInSessions:YES];
  self.connectivityManger.delegate = self;
  
  //init localSong array
  localSongUrls = [NSMutableArray new];
}


#pragma mark - ConnectivityManagerDelegate
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
  // We received data from host either
  NSDictionary *dataDic = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  
  if ([dataDic[@"command"] isEqualToString:@"title"]) {
    songTitle = [dataDic[@"data"] stringByReplacingOccurrencesOfString:@"title " withString:@""];
    
  } else if ([dataDic[@"command"] isEqualToString:@"artist"]) {
    songArtist = [dataDic[@"data"] stringByReplacingOccurrencesOfString:@"artist " withString:@""];
    
  } else if ([dataDic[@"command"] isEqualToString:@"play"]) {
    // Play at specified date
    NSTimer *playTimer = [NSTimer timerWithTimeInterval:0 target:self.player selector:@selector(play) userInfo:nil repeats:NO];
    playTimer.fireDate = (NSDate*)dataDic[@"data"];
    
    [[NSRunLoop mainRunLoop] addTimer:playTimer forMode:@"NSDefaultRunLoopMode"];
    
    // Set the playback time
    [self.player seekToTime:CMTimeMakeWithSeconds(((NSNumber*)dataDic[@"playTime"]).doubleValue, 1000000)];
    
  } else if ([dataDic[@"command"] isEqualToString:@"pause"]) {
    // Pause at specified date
    NSTimer *pauseTimer = [NSTimer timerWithTimeInterval:0 target:self.player selector:@selector(pause) userInfo:nil repeats:NO];
    pauseTimer.fireDate = (NSDate*)dataDic[@"data"];
    
    [[NSRunLoop mainRunLoop] addTimer:pauseTimer forMode:@"NSDefaultRunLoopMode"];
    
  } else if ([dataDic[@"command"] isEqualToString:@"albumImage"]) {
    albumImage = [UIImage imageWithData:dataDic[@"data"]];
  }
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
  
  // We received the song file
  if (!localURL) return;
  
  // Fix the path
  NSString *fixedUrl = [[localURL.absoluteString stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"resource.caf"];
  
  // Move the file to change its name to the right format
  [[NSFileManager new] removeItemAtURL:[NSURL URLWithString:fixedUrl] error:nil];//delete current file
  [[NSFileManager new] moveItemAtURL:localURL toURL:[NSURL URLWithString:fixedUrl] error:nil];//move the file
  
  // Load the song
  dispatch_sync(dispatch_get_main_queue(), ^{
    self.player = [AVPlayer playerWithURL:[NSURL URLWithString:fixedUrl]];
    
    // Update UI
    [self updatePlayerUI];
  });
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
