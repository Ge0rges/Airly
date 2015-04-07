//
//  HostViewController.m
//  Airly
//
//  Created by Georges Kanaan on 2/17/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "HostViewController.h"

@interface HostViewController ()

@end

@implementation HostViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    //initial bool values
    shouldNilOut = YES;

    //setup the connectivity manager
    self.connectivityManger = [[ConnectivityManager alloc] initWithPeerWithDisplayName:[[UIDevice currentDevice] name]];
    [self.connectivityManger setupBrowser];
    self.connectivityManger.delegate = self;
    
    //setup player manager
    self.playerManager = [PlayerManager new];
    self.playerManager.delegate = self;
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (shouldNilOut) {
        self.connectivityManger = nil;
        self.playerManager = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Connectivity
- (IBAction)invitePlayers:(UIBarButtonItem *)sender {
    shouldNilOut = NO;
    [self presentViewController:self.connectivityManger.browser animated:YES completion:nil];
}

-(void)sendSongToPeers {
    //get all peers
    NSMutableArray *peers = [NSMutableArray new];
    for (MCSession *session in self.connectivityManger.sessions) {
        for (MCPeerID *peerID in session.connectedPeers) {
            [peers addObject:peerID];
        }
    }
    
    //metadata
    //create the data
    NSData *titleData = [[NSString stringWithFormat:@"title %@", [self.playerManager currentSongName]] dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    NSData *artistData = [[NSString stringWithFormat:@"artist %@", [self.playerManager currentSongArtist]] dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    NSData *imageData = UIImagePNGRepresentation([self.playerManager currentSongAlbumArt]);

    //send
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{[self.connectivityManger sendData:artistData toPeers:peers reliable:YES];});
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{[self.connectivityManger sendData:imageData toPeers:peers reliable:YES];});
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{[self.connectivityManger sendData:titleData toPeers:peers reliable:YES];});
    
    //start playing
    UIBarButtonItem *btn = ([self.view viewWithTag:1]) ? (UIBarButtonItem *)[self.view viewWithTag:1] : (UIBarButtonItem *)[self.view viewWithTag:-1];
    [self playButtonPressed:btn];
    
    //song file
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        //get the real path url
        NSString *tempPath = NSTemporaryDirectory();
        NSURL *url = [[self.playerManager currentSong] valueForProperty:MPMediaItemPropertyAssetURL];
        AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:url options:nil];
        AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:songAsset presetName:AVAssetExportPresetPassthrough];
        exporter.outputFileType = @"com.apple.coreaudio-format";
        NSString *fname = [[NSString stringWithFormat:@"1"] stringByAppendingString:@".caf"];
        NSString *exportFile = [tempPath stringByAppendingPathComponent: fname];
        exporter.outputURL = [NSURL fileURLWithPath:exportFile];
        [exporter exportAsynchronouslyWithCompletionHandler:^{
            //send resource file
            [self.connectivityManger sendResourceAtURL:exporter.outputURL withName:[self.playerManager currentSongName] toPeers:peers withCompletionHandler:^(NSError *error) {
                //enable the play button
                UIBarButtonItem *btn = ([self.view viewWithTag:1]) ? (UIBarButtonItem *)[self.view viewWithTag:1] : (UIBarButtonItem *)[self.view viewWithTag:-1];
                [btn setEnabled:YES];
                
            }];
        }];
    });
}

#pragma mark - Player
-(void)updatePlayerUI {
    [self.albumImageView setImage:[self.playerManager currentSongAlbumArt]];
    [self.songArtistLabel setText:[self.playerManager currentSongArtist]];
    [self.songTitleLabel setText:[self.playerManager currentSongName]];
    
}

- (IBAction)addSongs:(UIBarButtonItem *)sender {
    shouldNilOut = NO;
    [self.playerManager presentMediaPickerOnController:self];
}

- (IBAction)rewindButtonPressed:(id)sender {
    //go to previous song and pause
    [self.playerManager previousSong];
    
    //send song to peers
    [self sendSongToPeers];
    
    //update UI
    [self updatePlayerUI];
}

- (IBAction)playButtonPressed:(UIBarButtonItem *)sender {
    NSString *stringToEncode;
    if (sender.tag == -1) {
        sender.tag = 1;
        stringToEncode = @"1";
        [sender setTitle:@"||"];
        
    }  else if (sender.tag == 1) {
        sender.tag = -1;
        stringToEncode = @"-1";
        [sender setTitle:@"►"];
    }
    
    //get peers
    NSMutableArray *peers = [NSMutableArray new];
    for (MCSession *session in self.connectivityManger.sessions) {
        for (MCPeerID *peerID in session.connectedPeers) {
            [peers addObject:peerID];
        }
    }
    
    //create NSData to send
    NSData *dataToSend = [stringToEncode dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    
    //play at the same time
    if (sender.tag == 1) {
        [self.playerManager play];
    }  else if (sender.tag == -1) {
        [self.playerManager pause];
    }
    
    [self.connectivityManger sendData:dataToSend toPeers:peers reliable:YES];
    
}

- (IBAction)forwardButtonPressed:(id)sender {
    //go to next song and pause
    [self.playerManager nextSong];
    
    //send song to peers
    [self sendSongToPeers];
    
    //update UI
    [self updatePlayerUI];

}

#pragma mark - ConnectivityManagerDelegate & PlayerManagerDelegate
-(void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
    shouldNilOut = YES;
    [browserViewController dismissViewControllerAnimated:YES completion:nil];
}

-(void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
    shouldNilOut = YES;
    [browserViewController dismissViewControllerAnimated:YES completion:nil];
}

-(void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
    //disable the play button
    UIBarButtonItem *btn = ([self.view viewWithTag:1]) ? (UIBarButtonItem *)[self.view viewWithTag:1] : (UIBarButtonItem *)[self.view viewWithTag:-1];
    [btn setEnabled:NO];
    
    //load the media colelction
    [self.playerManager loadMediaCollection:mediaItemCollection];

    //set the current playing item
    [self.playerManager play];
    
    //send song
    [self sendSongToPeers];
    
    //update UI
    [self updatePlayerUI];
    
    //pause
    [self.playerManager pause];
    
    //dismiss
    [mediaPicker dismissViewControllerAnimated:YES completion:^{shouldNilOut = YES;}];
}

-(void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
    [mediaPicker dismissViewControllerAnimated:YES completion:^{shouldNilOut = YES;}];
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

#pragma mark - Navigation
- (IBAction)dismissView:(id)sender {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
