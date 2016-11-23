//
//  HostPlayerManager.m
//  Airly
//
//  Created by Georges Kanaan on 23/11/2016.
//  Copyright © 2016 Georges Kanaan. All rights reserved.
//

#import "HostPlayerManager.h"

// Frameworks
#import <AVFoundation/AVFoundation.h>

// Managers
#import "ConnectivityManager.h"

@implementation HostPlayerManager

+ (NSDate * _Nonnull)synchronisePlayWithCurrentTime:(NSTimeInterval)currentPlaybackTime {
  ConnectivityManager *connectivityManager = [ConnectivityManager sharedInstanceWithDisplayName:[[UIDevice currentDevice] name]];
  
  // Get peers
  NSMutableArray *peers = [NSMutableArray new];
  for (MCSession *session in connectivityManager.sessions) {
    for (MCPeerID *peerID in session.connectedPeers) {
      [peers addObject:peerID];
    }
  }
  
  // Create NSData to send
  NSDate *dateToPlay = [NSDate dateWithTimeIntervalSinceNow:0.5];
  NSData *dataToSend = [NSKeyedArchiver archivedDataWithRootObject:@{@"command": @"play",
                                                                     @"date": dateToPlay,
                                                                     @"commandTime": [NSNumber numberWithDouble:currentPlaybackTime]
                                                                     }];
  
  // Send data
  [connectivityManager sendData:dataToSend toPeers:peers reliable:YES];
  
  return dateToPlay;
}


+ (NSDate * _Nonnull)synchronisePause {
  ConnectivityManager *connectivityManager = [ConnectivityManager sharedInstanceWithDisplayName:[[UIDevice currentDevice] name]];
  
  // Create NSData to send
  NSDate *dateToPause = [NSDate dateWithTimeIntervalSinceNow:0.5];
  NSData *dataToSend = [NSKeyedArchiver archivedDataWithRootObject:@{@"command": @"pause",
                                                                     @"date": dateToPause,
                                                                     }];
  
  // Send data
  [connectivityManager sendData:dataToSend toPeers:[connectivityManager allPeers] reliable:YES];
  
  return dateToPause;
}


+ (void)sendSongMetadata:(MPMediaItem * _Nonnull)mediaItem toPeers:(NSArray<MCPeerID *> * _Nonnull)peers completion:(void(^ _Nullable)(NSError * _Nullable error))handler {
  ConnectivityManager *connectivityManager = [ConnectivityManager sharedInstanceWithDisplayName:[[UIDevice currentDevice] name]];

  // Send the song metadata
  NSMutableDictionary *metadataDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"metadata",
                                                                                       @"songName": (mediaItem.title) ?: @"Unknown Song Name",
                                                                                       @"songArtist": (mediaItem.artist) ?: @"Unknown Artist",
                                                                                       }];
  
  UIImage *albumArtwork = [mediaItem.artwork imageWithSize:CGSizeMake(320, 290)];
  if (mediaItem.artwork) {
    [metadataDic addEntriesFromDictionary:@{@"songAlbumArt": UIImagePNGRepresentation(albumArtwork)}];
  }
  
  NSData *metadata = [NSKeyedArchiver archivedDataWithRootObject:metadataDic];
  
  [connectivityManager sendData:metadata toPeers:peers reliable:YES];
}


+ (void)sendSong:(MPMediaItem * _Nonnull)mediaItem toPeers:(NSArray<MCPeerID *> * _Nonnull)peers completion:(void(^ _Nullable)(NSError * _Nullable error))handler {
  ConnectivityManager *connectivityManager = [ConnectivityManager sharedInstanceWithDisplayName:[[UIDevice currentDevice] name]];
  
  // Send the song file
  // Get resource path
  NSURL *url = [mediaItem valueForProperty:MPMediaItemPropertyAssetURL];
  
  AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:url options:nil];
  AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:songAsset presetName:AVAssetExportPresetPassthrough];
  exporter.outputFileType = @"com.apple.coreaudio-format";
  exporter.shouldOptimizeForNetworkUse = YES;
  
  NSString *exportFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"song.caf"];
  [[NSFileManager defaultManager] removeItemAtPath:exportFilePath error:nil];// Delete the last song
  
  exporter.outputURL = [NSURL fileURLWithPath:exportFilePath];
    
  [exporter exportAsynchronouslyWithCompletionHandler:^{
    // Send resource file
    [connectivityManager sendResourceAtURL:exporter.outputURL withName:mediaItem.title toPeers:peers withCompletionHandler:handler];
  }];
}

@end
