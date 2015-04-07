//
//  PlayerViewController.m
//  Airly
//
//  Created by Georges Kanaan on 2/19/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "PlayerViewController.h"

@interface PlayerViewController ()

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
    self.localSongUrls = [NSMutableArray new];
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    self.connectivityManger = nil;
    self.player = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - ConnectivityManagerDelegate
-(void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    //we received data from host either: 1 (play); -1(pause)
    NSString *command = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    if ([command containsString:@"title"]) {
        songTitle = [command stringByReplacingOccurrencesOfString:@"title " withString:@""];

    } else if ([command containsString:@"artist"]) {
        songArtist = [command stringByReplacingOccurrencesOfString:@"artist " withString:@""];
    
    } else if ([command isEqualToString:@"1"]) {
        [self.player play];
    
    } else if ([command isEqualToString:@"-1"]) {
        [self.player pause];
    
    } else {
        albumImage = [UIImage imageWithData:data];
    }
}

-(void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {

    //fix the path
    if (!localURL) return;

    NSString *fixedUrl = [[localURL.absoluteString stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"resource.caf"];
    
    //move the file to change its name to the right format
    [[NSFileManager new] removeItemAtURL:[NSURL URLWithString:fixedUrl] error:nil];//delete current file
    [[NSFileManager new] moveItemAtURL:localURL toURL:[NSURL URLWithString:fixedUrl] error:nil];//move the file
    
    //load the song
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.player = [AVPlayer playerWithURL:[NSURL URLWithString:fixedUrl]];
        
        //update UI
        [self updatePlayerUI];
    });
}

-(void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    if (state == MCSessionStateConnecting) {
        NSLog(@"Connecting to %@", peerID.displayName);
    } else if (state == MCSessionStateConnected) {
        NSLog(@"Connected to %@", peerID.displayName);
    } else if (state == MCSessionStateNotConnected) {
        NSLog(@"Disconnected from %@", peerID.displayName);
    }
}

#pragma mark - Player
-(void)updatePlayerUI {
    [self.albumImageView setImage:albumImage];
    [self.songArtistLabel setText:songArtist];
    [self.songTitleLabel setText:songTitle];
}

#pragma mark - Navigation
- (IBAction)dismissView:(id)sender {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
