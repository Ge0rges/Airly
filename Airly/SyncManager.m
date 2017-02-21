//
//  SyncManager.m
//  Airly
//
//  Created by Georges Kanaan on 23/11/2016.
//  Copyright © 2016 Georges Kanaan. All rights reserved.
//

#import "SyncManager.h"

// Frameworks
#import <AVFoundation/AVFoundation.h>
#import <mach/mach_time.h>

@interface SyncManager () {
  NSMutableArray *calculatedOffsets;
  BOOL calibrated;
}

@property (strong, nonatomic) ConnectivityManager *connectivityManager;

@property (nonatomic) int64_t hostTimeOffset;
@property (nonatomic) uint64_t numberOfCalibrations;

@end

@implementation SyncManager

+ (instancetype _Nonnull)sharedManager {
  static SyncManager *sharedManager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedManager = [[self alloc] init];
    sharedManager.connectivityManager = [ConnectivityManager sharedManagerWithDisplayName:[[UIDevice currentDevice] name]];
    sharedManager.connectivityManager.syncManager = sharedManager;
    sharedManager.hostTimeOffset = 0;
    sharedManager.numberOfCalibrations = 1;
    sharedManager.calibratedPeers = [NSMutableSet new];
    sharedManager->calibrated = NO;
    sharedManager->calculatedOffsets = [NSMutableArray new];
    
  });
  
  return sharedManager;
}

#pragma mark - Player
- (uint64_t)synchronisePlayWithCurrentPlaybackTime:(NSTimeInterval)currentPlaybackTime {
  // Create NSData to send
  uint64_t timeToPlay = [self currentNetworkTime] + 500000000;
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
  uint64_t timeToPause = [self currentNetworkTime] + 500000000;
  NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:@{@"command": @"pause",
                                                                  @"date": [NSNumber numberWithUnsignedLongLong:timeToPause],
                                                                  }];
  
  // Send data
  [self.connectivityManager sendData:payload toPeers:self.connectivityManager.allPeers reliable:YES];
  
  return timeToPause;
}

- (uint64_t)sendSongMetadata:(MPMediaItem * _Nonnull)mediaItem toPeers:(NSArray<MCPeerID *> * _Nonnull)peers {
  // Send the song metadata
  uint64_t timeToUpdateUI = [self currentNetworkTime] + 500000000;
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
  if (peers.count == 0) return;
  
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
// Host
- (void)executeBlockWhenPeerCalibrates:(MCPeerID * _Nonnull)peer block:(calibrationBlock)completionBlock {
  if ([self.calibratedPeers containsObject:peer]) {// Already calibrated
    completionBlock(peer);
    return;
  }
  
  __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:@"peerCalibrated" object:self.calibratedPeers queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull notification) {
    if ([notification.userInfo[@"calibratedPeer"] isEqual:peer]) {
      completionBlock(peer);
      [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }
  }];
}

- (void)askPeersToCalculateOffset {
  // Send the "sync" command to peers to trigger their offset calculations.
  NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"sync"}];
  NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
  
  [self.connectivityManager sendData:payload toPeers:self.connectivityManager.allPeers reliable:YES];
}

// Meant for speakers.
- (void)calculateTimeOffsetWithHostFromStart:(BOOL)resetBools {
  if (resetBools) {// These bools are used to track the state of calculation. They must be set to no to go through a full calibration.
    calibrated = NO;
  }
  
  for (int i=0; i<self.numberOfCalibrations; i++) {
    NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncPing",
                                                                                        @"timeSent": [NSNumber numberWithUnsignedLongLong:[self currentNetworkTime]],
                                                                                        }];
    NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
    
    [self.connectivityManager sendData:payload toPeers:self.connectivityManager.allPeers reliable:YES];
  }
}

- (uint64_t)currentNetworkTime {// https://developer.apple.com/library/content/qa/qa1398/_index.html
  uint64_t baseTime = mach_absolute_time();
  
  // Convert from ticks to nanoseconds:
  static mach_timebase_info_data_t sTimebaseInfo;
  if (sTimebaseInfo.denom == 0) {// Check if timebase is initialize
    mach_timebase_info(&sTimebaseInfo);
  }
  
  uint64_t timeNanoSeconds = baseTime * sTimebaseInfo.numer / sTimebaseInfo.denom;
  return timeNanoSeconds - self.hostTimeOffset;
}

- (void)atExactTime:(uint64_t)val runBlock:(dispatch_block_t _Nonnull)block {
  
  // Use the most accurate timing possible to trigger an event at the specified DTime.
  // This is much more accurate than dispatch_after(...), which has a 10% "leeway" by default.
  // However, this method will use battery faster as it avoids most timer coalescing.
  // Use as little as necessary.
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, DISPATCH_TIMER_STRICT, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
  dispatch_source_set_event_handler(timer, ^{
    dispatch_source_cancel(timer); // one shot timer
    while (val > [self currentNetworkTime]) {
      [NSThread sleepForTimeInterval:0];
    }
    NSLog(@"executed block that request time: %llu at time: %llu", val, [self currentNetworkTime]);
    block();
  });
  
  // Now, we employ a dirty trick:
  // Since even with DISPATCH_TIMER_STRICT there can be about 1ms of inaccuracy, we set the timer to
  // fire 1.3ms too early, then we use an until(time) { sleep(); } loop to delay until the exact time
  // that we wanted. This takes us from an accuracy of ~1ms to an accuracy of ~0.01ms, i.e. two orders
  // of magnitude improvement. However, of course the downside is that this will block the main thread
  // for 1.3ms.
  dispatch_time_t at_time = dispatch_time(DISPATCH_TIME_NOW, val - [self currentNetworkTime] - 1300000);
  dispatch_source_set_timer(timer, at_time, DISPATCH_TIME_FOREVER /*one shot*/, 0 /* minimal leeway */);
  dispatch_resume(timer);
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
  
  NSDictionary *payload = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  
  // Check if the host is asking us to sync
  if ([payload[@"command"] isEqualToString:@"sync"]) {
    [self calculateTimeOffsetWithHostFromStart:YES];
    
    return;
    
  } else if ([payload[@"command"] isEqualToString:@"syncDone"]) {
    [self.calibratedPeers addObject:peerID];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"peerCalibrated" object:self.calibratedPeers userInfo:@{@"calibratedPeer": peerID}];
    
    return;
  } else if ([payload[@"command"] isEqualToString:@"syncPing"]) {// This is done on the peer with which we are calculating the offset (Host).
    NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncPong",
                                                                                        @"timeReceived": [NSNumber numberWithUnsignedLongLong:[self currentNetworkTime]],
                                                                                        @"timeSent": payload[@"timeSent"],
                                                                                        }];
    
    NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
    
    [self.connectivityManager sendData:payload toPeers:@[peerID] reliable:YES];// Speakers are only connected to the host.
    
    return;
    
    // This is done on the person who callled calculateTimeOffsetWithHost (Player).
  } else if ([payload[@"command"] isEqualToString:@"syncPong"]) {
    
    // Calculate the offset and add it to the calculated offsets.
    uint64_t timePingSent = ((NSNumber*)payload[@"timeSent"]).unsignedLongLongValue;
    uint64_t timeHostReceivedPing = ((NSNumber*)payload[@"timeReceived"]).unsignedLongLongValue;
    
    //uint64_t latencyWithHost = ([self currentNetworkTime] - timePingSent)/2;
    
    int64_t calculatedOffset = ((int64_t)[self currentNetworkTime] + (int64_t)timePingSent - (2*(int64_t)timeHostReceivedPing))/2; // WAY 1. Best because it doesn't depend on latency
    //calculatedOffset2 = latencyWithHost - timeHostReceivedPing + timePingSent;// WAY 2
    //calculatedOffset3 = -latencyWithHost - timeHostReceivedPing + [self currentNetworkTime];// WAY 3
    
    [calculatedOffsets addObject:[NSNumber numberWithLongLong:calculatedOffset]];
    
    if (calculatedOffsets.count == self.numberOfCalibrations) {// If is the last value, calculate the average of all offsets.
      int64_t numeratorForAverage = 0;
      for (NSNumber *calculatedOffset in calculatedOffsets) {
        numeratorForAverage += calculatedOffset.longLongValue;
      }
      
      self.hostTimeOffset = numeratorForAverage/(int64_t)self.numberOfCalibrations;
      NSLog(@"calculated hostTimeOffset: %lli from %llu offsets: %@", self.hostTimeOffset, self.numberOfCalibrations, calculatedOffsets);
      
      calibrated = YES; // No calibrating twice.
      
      // Let the host know we calibrated
      NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncDone"}];
      NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
      
      [self.connectivityManager sendData:payload toPeers:@[peerID] reliable:YES];
    }
    
    return;
  }
}

- (void)session:(MCSession* _Nonnull)session peer:(MCPeerID* _Nonnull)peerID didChangeState:(MCSessionState)state {
  // Remove the disconnected peer from the calibratde peer list if it's there.
  if (state == MCSessionStateNotConnected) {
    [self.calibratedPeers removeObject:peerID];
  }
}

@end
