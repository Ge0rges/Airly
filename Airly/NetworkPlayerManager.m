//
//  NetworkPlayerManager.m
//  Airly
//
//  Created by Georges Kanaan on 23/11/2016.
//  Copyright © 2016 Georges Kanaan. All rights reserved.
//

#import "NetworkPlayerManager.h"

// Frameworks
#import <AVFoundation/AVFoundation.h>
#import <mach/mach_time.h>

@interface NetworkPlayerManager () {
  uint64_t hostTimeOffset;
  uint64_t tempHostTimeOffset;
  
}

@property (strong, nonatomic) ConnectivityManager *connectivityManager;

@end

@implementation NetworkPlayerManager

+ (instancetype _Nonnull)sharedManager {
  static NetworkPlayerManager *sharedManager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedManager = [[self alloc] init];
    sharedManager.connectivityManager = [ConnectivityManager sharedManagerWithDisplayName:[[UIDevice currentDevice] name]];
    sharedManager->tempHostTimeOffset = 0;
  });
  
  return sharedManager;
}

#pragma mark - Player
- (uint64_t)synchronisePlayWithCurrentTime:(NSTimeInterval)currentPlaybackTime {
  
  // Create NSData to send
  uint64_t timeToPlay = [self getCurrentTime] + 1000000000;// Add 1 second1
  NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:@{@"command": @"play",
                                                                  @"date": [NSNumber numberWithUnsignedLongLong:timeToPlay],
                                                                  @"commandTime": [NSNumber numberWithDouble:currentPlaybackTime]
                                                                  }];
  
  // Send data
  [self.connectivityManager sendData:payload toPeers:self.connectivityManager.allPeers reliable:YES];
  
  return timeToPlay;
}

- (uint64_t)synchronisePause {
  // Create NSData to send
  uint64_t timeToPause = [self getCurrentTime] + 1000000000;// Add 1 second
  NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:@{@"command": @"pause",
                                                                  @"date": [NSNumber numberWithUnsignedLongLong:timeToPause],
                                                                  }];
  
  // Send data
  [self.connectivityManager sendData:payload toPeers:self.connectivityManager.allPeers reliable:YES];
  
  return timeToPause;
}

- (uint64_t)sendSongMetadata:(MPMediaItem * _Nonnull)mediaItem toPeers:(NSArray<MCPeerID *> * _Nonnull)peers {
  // Send the song metadata
  uint64_t timeToUpdateUI = [self getCurrentTime] + 1000000000;// Add 1 second
  NSMutableDictionary *metadataDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"metadata",
                                                                                       @"songName": (mediaItem.title) ?: @"Unknown Song Name",
                                                                                       @"songArtist": (mediaItem.artist) ?: @"Unknown Artist",
                                                                                       @"date": [NSNumber numberWithUnsignedLongLong:timeToUpdateUI]
                                                                                       }];
  
  UIImage *albumArtwork = [mediaItem.artwork imageWithSize:CGSizeMake(320, 290)];
  if (mediaItem.artwork) {
    [metadataDic addEntriesFromDictionary:@{@"songAlbumArt": UIImagePNGRepresentation(albumArtwork)}];
  }
  
  NSData *metadata = [NSKeyedArchiver archivedDataWithRootObject:metadataDic];
  
  [self.connectivityManager sendData:metadata toPeers:peers reliable:YES];
  
  return timeToUpdateUI;
}

- (void)sendSong:(MPMediaItem * _Nonnull)mediaItem toPeers:(NSArray<MCPeerID *> * _Nonnull)peers completion:(void(^ _Nullable)(NSError * _Nullable error))handler {
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
    [self.connectivityManager sendResourceAtURL:exporter.outputURL withName:mediaItem.title toPeers:peers withCompletionHandler:handler];
  }];
}

#pragma mark - Network Time Sync
//Meant for speakers.

- (void)calculateTimeOffsetWithHost {
  hostTimeOffset = 0;
  
  self.connectivityManager.networkPlayerManager = self;// Needed for reply.
  
  NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncPing",
                                                                                      @"timeSent": [NSNumber numberWithUnsignedLongLong:[self getCurrentTime]]
                                                                                      }];
  
  NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
  
  [self.connectivityManager sendData:payload toPeers:self.connectivityManager.allPeers reliable:YES];// Speakers are only connected to the host.
}

- (uint64_t)getCurrentTime {
  uint64_t baseTime = mach_absolute_time();
  // Convert from ticks to nanoseconds:
  static mach_timebase_info_data_t s_timebase_info;
  if (s_timebase_info.denom == 0) {
    mach_timebase_info(&s_timebase_info);
  }
  
  uint64_t timeNanoSeconds = (baseTime * s_timebase_info.numer) / s_timebase_info.denom;
  return timeNanoSeconds - hostTimeOffset;
}

- (void)atExactTime:(uint64_t)val runBlock:(dispatch_block_t _Nonnull)block {
  // Use the most accurate timing possible to trigger an event at the specified DTime.
  // This is much more accurate than dispatch_after(...), which has a 10% "leeway" by default.
  // However, this method will use battery faster as it avoids most timer coalescing.
  // Use as little as necessary.
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, DISPATCH_TIMER_STRICT, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
  dispatch_source_set_event_handler(timer, ^{
    dispatch_source_cancel(timer); // one shot timer
    while ((int64_t)(val - [self getCurrentTime]) > 200) {
      [NSThread sleepForTimeInterval:0];
    }
    NSLog(@"Launched at CurrentTime: %lli", [self getCurrentTime]);
    block();
  });
  // Now, we employ a dirty trick:
  // Since even with DISPATCH_TIMER_STRICT there can be about 1ms of inaccuracy, we set the timer to
  // fire 1.3ms too early, then we use an until(time) { sleep(); } loop to delay until the exact time
  // that we wanted. This takes us from an accuracy of ~1ms to an accuracy of ~0.01ms, i.e. two orders
  // of magnitude improvement. However, of course the downside is that this will block the main thread
  // for 1.3ms.
  dispatch_time_t at_time = dispatch_time(DISPATCH_TIME_NOW, val - [self getCurrentTime] - 1300000);
  dispatch_source_set_timer(timer, at_time, DISPATCH_TIME_FOREVER /*one shot*/, 0 /* minimal leeway */);
  dispatch_resume(timer);
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
  
  NSDictionary *payload = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  
  // This is done on the peer with which we are calculating the offset (Host).
  if ([payload[@"command"] isEqualToString:@"syncPing"]) {
    NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncPong",
                                                                                        @"timeReceived": [NSNumber numberWithUnsignedLongLong:[self getCurrentTime]],
                                                                                        @"timeSent": payload[@"timeSent"]
                                                                                        }];
    
    NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
    
    [self.connectivityManager sendData:payload toPeers:@[peerID] reliable:YES];// Speakers are only connected to the host.
    
    
    // This is done on the person who callled calculateTimeOffsetWithHost (Player).
  } else if ([payload[@"command"] isEqualToString:@"syncPong"]) {
    if (tempHostTimeOffset != 0) {
      hostTimeOffset = (([self getCurrentTime] + ((NSNumber*)payload[@"timeSent"]).unsignedLongLongValue)/2) - ((NSNumber*)payload[@"timeReceived"]).unsignedLongLongValue;
    
      // Check that two calculated offsets don't differ by much, do the average.
      NSLog(@"Difference between offsets: %lli", llabs((int64_t)(tempHostTimeOffset - hostTimeOffset)));

      if (llabs((int64_t)(tempHostTimeOffset - hostTimeOffset)) > 500) {// Error margin
        // Offsets are above error margin, restart process.
        tempHostTimeOffset = 0;
        [self calculateTimeOffsetWithHost];
      
      } else {
        // Offsets meet the acceptable error margin.
        NSLog(@"Offsets are acceptable: %lli", hostTimeOffset);
        tempHostTimeOffset = 0;// Reset for next time. Not really necessary.
      }
      
    } else {
      tempHostTimeOffset = (([self getCurrentTime] + ((NSNumber*)payload[@"timeSent"]).unsignedLongLongValue)/2) - ((NSNumber*)payload[@"timeReceived"]).unsignedLongLongValue;
      
      [self calculateTimeOffsetWithHost];// We do the average of the two.
    }
  }
}

@end
