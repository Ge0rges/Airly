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
#import <unistd.h>

@interface SyncManager () {
  double calculatedOffsets;
  double totalCalculatedOffsets;
  BOOL isCalibrating;
}

@property (strong, nonatomic) ConnectivityManager *connectivityManager;
@property (nonatomic) int64_t hostTimeOffset;// Offset between this device and the host, in nanoseconds. 0 on host.
@property (nonatomic) uint64_t latencyWithHost;// Calculated latency with host for one ping (one-way) based on offsetWithHost, in nanoseconds.
@property (nonatomic) uint64_t maxNumberOfCalibrations;

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
    sharedManager.maxNumberOfCalibrations = 50000;
    sharedManager.calibratedPeers = [NSMutableSet new];
    sharedManager->calculatedOffsets = 0;
    sharedManager->totalCalculatedOffsets = 0;
  });
  
  return sharedManager;
}

#pragma mark - Player Interface
- (uint64_t)synchronisePlayWithCurrentPlaybackTime:(NSTimeInterval)currentPlaybackTime whileHostPlaying:(BOOL)hostIsPlaying {
  // Create NSData to send
  uint64_t timeToPlay = [self currentNetworkTime] + 1000000000;// In one second.
  NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:@{@"command": @"play",
                                                                  @"date": [NSNumber numberWithUnsignedLongLong:timeToPlay],
                                                                  @"commandTime": [NSNumber numberWithDouble:currentPlaybackTime],
                                                                  //If yes, the playback time will be adjusted on peer to take into account transfer time (eg the song was playing on host)
                                                                  @"continuousPlay": [NSNumber numberWithBool:hostIsPlaying]
                                                                  }];
  
  // Send data
  [self.connectivityManager sendData:payload toPeers:self.connectivityManager.allPeers reliable:YES];

  return timeToPlay;
}

- (uint64_t)synchronisePause {
  // Create NSData to send
  uint64_t timeToPause = [self currentNetworkTime] + 1000000000;// In one second.
  NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:@{@"command": @"pause",
                                                                  @"date": [NSNumber numberWithUnsignedLongLong:timeToPause],
                                                                  }];
  
  // Send data
  [self.connectivityManager sendData:payload toPeers:self.connectivityManager.allPeers reliable:YES];
  
  return timeToPause;
}

- (uint64_t)sendSongMetadata:(MPMediaItem * _Nonnull)mediaItem toPeers:(NSArray<MCPeerID *> * _Nonnull)peers {
  // Send the song metadata
  NSMutableDictionary *metadataDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"metadata",
                                                                                       @"songName": (mediaItem.title) ?: @"",
                                                                                       @"songArtist": (mediaItem.artist) ?: @""
                                                                                       }];
  
  
  if (mediaItem.artwork) {
    UIImage *albumArtwork = [mediaItem.artwork imageWithSize:CGSizeMake(320, 290)];
    [metadataDic addEntriesFromDictionary:@{@"songAlbumArt": UIImagePNGRepresentation(albumArtwork)}];
  }
  
  // Add the time to update last.
  uint64_t timeToUpdateUI = [self currentNetworkTime] + 1000000000;// In one second.
  [metadataDic addEntriesFromDictionary:@{@"date": [NSNumber numberWithUnsignedLongLong:timeToUpdateUI]}];
  
  NSData *metadata = [NSKeyedArchiver archivedDataWithRootObject:metadataDic];
  
  [self.connectivityManager sendData:metadata toPeers:peers reliable:YES];
  
  return timeToUpdateUI;
}

- (void)sendSong:(MPMediaItem * _Nonnull)mediaItem toPeers:(NSArray<MCPeerID *> * _Nonnull)peers progress:(void(^ _Nullable)(NSArray <NSProgress *>* _Nullable progressArray))progressHandler completion:(void(^ _Nullable)(NSError * _Nullable error))handler {
  if (peers.count == 0) handler(nil);
  
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
    NSArray *progress = [self.connectivityManager sendResourceAtURL:exporter.outputURL withName:mediaItem.title toPeers:peers withCompletionHandler:handler];
    progressHandler(progress);
  }];
}

#pragma mark - Network Time Sync
// Host
- (void)executeBlockWhenAllPeersCalibrate:(NSArray <MCPeerID *> * _Nonnull)peers block:(calibrationBlock)completionBlock {
  // Check if these peers already had the time to calibrate
  if (self.calibratedPeers.count >= peers.count || (peers.count > self.connectivityManager.allPeers.count && peers.count > self.calibratedPeers.count)) {// Already calibrated
    completionBlock(peers);
    return;
  }
  
  // They didn't calibrate. Register to receive notifications. Execute when all are calibrated.
  __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:@"peerCalibrated" object:self.calibratedPeers queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull notification) {
    
    __block BOOL executeBlock = YES;
    
    // Check that every object in peers is contained in calibratedPeers
    [peers enumerateObjectsUsingBlock:^(MCPeerID * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      if (executeBlock) {// Make sure a NO doesn't get switched to a YES.
        if ([self.connectivityManager.allPeers containsObject:obj]) {// Make sure this peer is still connected
          executeBlock = [self.calibratedPeers containsObject:obj];
        }
      }
      
      *stop = !executeBlock;// Stop if executeBlock is NO.
    }];
    
    // Check if we should execute the block
    if (executeBlock) {
      completionBlock(peers);
      [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }
  }];
}

- (void)executeBlockWhenEachPeerCalibrates:(NSArray <MCPeerID *> * _Nonnull)peers block:(calibrationBlock)completionBlock {
  // Check if these peers already had the time to calibrate
  __block NSMutableArray *peersMut = [peers mutableCopy];// Tracks which peers haven't calibrated yet and caused a notification
  NSSet *peersSet = [NSSet setWithArray:peers];
  
  for (MCPeerID *peer in peersSet) {
    if ([self.calibratedPeers containsObject:peer]) {// Already calibrated
      completionBlock(@[peer]);
      [peersMut removeObject:peer];
    }
  }
  
  // They didn't. Register to receive notifications. Execute when each one is calibrated.
  __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:@"peerCalibrated" object:self.calibratedPeers queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull notification) {
    for (MCPeerID *peer in peersSet) {
      if ([self.calibratedPeers containsObject:peer] && [peersMut containsObject:peer]) {// Newly calibrated
        completionBlock(@[peer]);
        [peersMut removeObject:peer];
      }
    }
    
    // Unsubscribe when every one calibrates.
    if (peersMut.count == 0) {
      [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }
  }];
}

- (void)askPeersToCalculateOffset:(NSArray <MCPeerID*>* _Nonnull)peers {
  // Remove all peer calibrated
  [self.calibratedPeers removeAllObjects];
  
  // Send the "sync" command to peers to trigger their offset calculations.
  NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"sync"}];
  NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
  
  [self.connectivityManager sendData:payload toPeers:peers reliable:YES];
}

// Meant for speakers.
- (void)calculateTimeOffsetWithHost:(MCPeerID *)hostPeer {
  if (!isCalibrating) {
    isCalibrating = YES;// Used to track the calibration
    calculatedOffsets = 0;// Reset calculated offsets number
    totalCalculatedOffsets = 0;
    
    // Handle 0 calibrations
    if (self.maxNumberOfCalibrations == 0) {
      isCalibrating = NO;
      
      // Let the host know we calibrated
      NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncDone"}];
      NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
      
      [self.connectivityManager sendData:payload toPeers:@[hostPeer] reliable:YES];
      
      return;
    }
    
    // Send a starting ping
    NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncPing",
                                                                                        @"timeSent": [NSNumber numberWithUnsignedLongLong:[self currentTime]]
                                                                                        }];
    NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
    
    [self.connectivityManager sendData:payload toPeers:@[hostPeer] reliable:YES];
  }
}

- (uint64_t)currentTime {// https://developer.apple.com/library/content/qa/qa1398/_index.html
  uint64_t baseTime = mach_absolute_time();
  
  // Convert from ticks to nanoseconds:
  static mach_timebase_info_data_t sTimebaseInfo;
  if (sTimebaseInfo.denom == 0) {// Check if timebase is initialize
    mach_timebase_info(&sTimebaseInfo);
  }
  
  uint64_t timeNanoSeconds = baseTime * sTimebaseInfo.numer / sTimebaseInfo.denom;
  return (int64_t)timeNanoSeconds;
}

- (uint64_t)currentNetworkTime {
  return (int64_t)[self currentTime] - self.hostTimeOffset;
}

- (void)atExactTime:(uint64_t)val runBlock:(dispatch_block_t _Nonnull)block {
  if (val <= [self currentNetworkTime]) {// The value has already passed execute immediately.
    block();
    return;
  }
  
  // Use the most accurate timing possible to trigger an event at the specified DTime.
  // This is much more accurate than dispatch_after(...), which has a 10% "leeway" by default.
  // However, this method will use battery faster as it avoids most timer coalescing.
  // Use as little as necessary.
  dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, DISPATCH_TIMER_STRICT, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
  dispatch_source_set_event_handler(timer, ^{
    dispatch_source_cancel(timer); // one shot timer
    while (val > [self currentNetworkTime]) {
      sleep(0);
    }
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
    [self calculateTimeOffsetWithHost:peerID];
    
    return;
    
  } else if ([payload[@"command"] isEqualToString:@"syncDone"]) {
    [self.calibratedPeers addObject:peerID];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"peerCalibrated" object:self.calibratedPeers userInfo:@{@"calibratedPeer": peerID}];
    
    return;
  } else if ([payload[@"command"] isEqualToString:@"syncPing"]) {// This is done on the peer with which we are calculating the offset (Host).
    NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncPong",
                                                                                        @"timeReceived": [NSNumber numberWithUnsignedLongLong:[self currentTime]],
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
    
    //uint64_t latencyWithHost = ([self currentTime] - timePingSent)/2;// Calculates the estimated latency for one way travel
    
    // If this calculation doesn't meet our error margin, restart.
    if (((int64_t)[self currentTime] - (int64_t)timePingSent) > 25000000000) {
      NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncPing",
                                                                                          @"timeSent": [NSNumber numberWithUnsignedLongLong:[self currentTime]]
                                                                                          }];
      NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
      
      [self.connectivityManager sendData:payload toPeers:@[peerID] reliable:YES];
      
      return;
    }
    
    int64_t calculatedOffset = ((int64_t)[self currentTime] + (int64_t)timePingSent - (2*(int64_t)timeHostReceivedPing))/2; // WAY 1. Best because it doesn't depend on latency
    //calculatedOffset2 = (int64_t)latencyWithHost - (int64_t)timeHostReceivedPing + (int64_t)timePingSent;// WAY 2
    //calculatedOffset3 = -(int64_t)latencyWithHost - (int64_t)timeHostReceivedPing + (int64_t)[self currentTime];// WAY 3
    
    totalCalculatedOffsets += calculatedOffset;
    calculatedOffsets += 1;

    NSLog(@"Calculated calibration. Total: %f", calculatedOffsets);

    // If the calibration is accurate enough just end it.
    double newOffset = totalCalculatedOffsets/calculatedOffsets;
    
    if (fabs(newOffset-self.hostTimeOffset) < 5000) {
      self.maxNumberOfCalibrations = calculatedOffsets;
      NSLog(@"prematurely ended calibration because accurate enough at value: %f", newOffset);
    }
    
    self.hostTimeOffset = newOffset;
    
    
    // If calculation is done notify the host.
    if (calculatedOffsets >= self.maxNumberOfCalibrations) {
      // Let the host know we calibrated
      NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncDone"}];
      NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
      
      [self.connectivityManager sendData:payload toPeers:@[peerID] reliable:YES];
      
      // Update the bool
      isCalibrating = NO;
      
    } else {
      // Send another calibration request.
      NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncPing",
                                                                                          @"timeSent": [NSNumber numberWithUnsignedLongLong:[self currentTime]]
                                                                                          }];
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
    isCalibrating = NO;
    self.hostTimeOffset = 0;
  }
}

@end
