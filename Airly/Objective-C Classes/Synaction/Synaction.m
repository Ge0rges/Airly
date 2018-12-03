//
//  Synaction.m
//  Synaction
//
//  Created by Georges Kanaan on 11/02/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

#import "Synaction.h"

// Frameworks
#import <AVFoundation/AVFoundation.h>
#import <mach/mach_time.h>

@interface Synaction () {
  double calculatedOffsets;
  double totalCalculatedOffsets;
}

@property (nonatomic) int64_t hostTimeOffset;// Offset between this device and the host, in nanoseconds. 0 on host.
@property (nonatomic) uint64_t latencyWithHost;// Calculated latency with host for one ping (one-way) based on offsetWithHost, in nanoseconds.
@property (nonatomic) uint64_t maxNumberOfCalibrations;
@property (nonatomic) BOOL isCalibrating;

@end

@implementation Synaction

+ (instancetype _Nonnull)sharedManager {
  static Synaction *sharedManager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedManager = [[self alloc] init];
    sharedManager.connectivityManager = [ConnectivityManager sharedManager];
    sharedManager.connectivityManager.synaction = sharedManager;
    sharedManager.hostTimeOffset = 0;
    sharedManager.maxNumberOfCalibrations = 5000;
    sharedManager.calibratedPeers = [NSMutableSet new];
    sharedManager->calculatedOffsets = 0;
    sharedManager->totalCalculatedOffsets = 0;
  });
  
  return sharedManager;
}


#pragma mark - Network Time Sync
// Host
- (void)executeBlockWhenAllPeersCalibrate:(NSArray <GCDAsyncSocket *> * _Nonnull)peers block:(calibrationBlock)completionBlock {
  // Check if these peers already had the time to calibrate
  if (self.calibratedPeers.count >= peers.count || (peers.count > self.connectivityManager.allSockets.count && peers.count > self.calibratedPeers.count)) {// Already calibrated
		NSLog(@"Executing block for all peers calibrated, already calibrated!");
    completionBlock(peers);
    return;
  }
  
  // They didn't calibrate. Register to receive notifications. Execute when all are calibrated.
  __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:@"peerCalibrated" object:self.calibratedPeers queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull notification) {
    
    __block BOOL executeBlock = YES;
    
    // Check that every object in peers is contained in calibratedPeers
    [peers enumerateObjectsUsingBlock:^(GCDAsyncSocket * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      if (executeBlock) {// Make sure a NO doesn't get switched to a YES.
        if ([self.connectivityManager.allSockets containsObject:obj]) {// Make sure this peer is still connected
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

- (void)executeBlockWhenEachPeerCalibrates:(NSArray <GCDAsyncSocket *> * _Nonnull)peers block:(calibrationBlock)completionBlock {
  // Check if these peers already had the time to calibrate
  __block NSMutableArray *peersMut = [peers mutableCopy];// Tracks which peers haven't calibrated yet and caused a notification
  NSSet *peersSet = [NSSet setWithArray:peers];
  
  for (GCDAsyncSocket *peer in peersSet) {
    if ([self.calibratedPeers containsObject:peer]) {// Already calibrated
      completionBlock(@[peer]);
      [peersMut removeObject:peer];
    }
  }
  
  // They didn't. Register to receive notifications. Execute when each one is calibrated.
  __block id observer = [[NSNotificationCenter defaultCenter] addObserverForName:@"peerCalibrated" object:self.calibratedPeers queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull notification) {
    for (GCDAsyncSocket *peer in peersSet) {
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

- (void)askPeersToCalculateOffset:(NSArray <GCDAsyncSocket*>* _Nonnull)peers {
  if (!peers) {
    NSLog(@"Peers cannot be nil when calling `-askPeersToCalculateOffset`");
	return;
  }
  
  // Remove all peer calibrated
  for (GCDAsyncSocket *peerID in peers) {
    [self.calibratedPeers removeObject:peerID];
  }
  
  // Send the "sync" command to peers to trigger their offset calculations.
  NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"sync"}];
  NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
  
  Packet *packet = [[Packet alloc] initWithData:payload type:0 action:PacketActionSync];
  [self.connectivityManager sendPacket:packet toSockets:peers];
}

// Meant for peers.
- (void)calculateTimeOffsetWithHost:(GCDAsyncSocket *)hostPeer {
  NSLog(@"Called calibrate function.");
	
  if (!self.isCalibrating) {
	NSLog(@"Calibration request valid sending ping.");
		
    self.isCalibrating = YES;// Used to track the calibration
    calculatedOffsets = 0;// Reset calculated offsets number
    totalCalculatedOffsets = 0;
    
    // Handle 0 calibrations
    if (self.maxNumberOfCalibrations == 0) {
	  NSLog(@"Max calibs 0 so ending now.");
			
      self.isCalibrating = NO;
      
      // Let the host know we calibrated
      NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncDone"}];
      NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
      
      Packet *packet = [[Packet alloc] initWithData:payload type:0 action:PacketActionSync];
      [self.connectivityManager sendPacket:packet toSockets:@[hostPeer]];
      
      return;
    }
		
	NSLog(@"Sending initial ping.");
		
    // Send a starting ping
    NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncPing",
                                                                                        @"timeSent": [NSNumber numberWithUnsignedLongLong:[self currentTime]]
                                                                                        }];
    NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
    
    Packet *packet = [[Packet alloc] initWithData:payload type:0 action:PacketActionSync];
    [self.connectivityManager sendPacket:packet toSockets:@[hostPeer]];
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
  return [self currentTime] - self.hostTimeOffset;
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

- (void)didReceivePacket:(Packet *)packet fromSocket:(GCDAsyncSocket *)socket {
  
  NSDictionary *payload = [NSKeyedUnarchiver unarchiveObjectWithData:packet.data];
  
  // Check if the host is asking us to sync
  if ([payload[@"command"] isEqualToString:@"sync"]) {
		NSLog(@"Host asked us to sync.");
    [self calculateTimeOffsetWithHost:socket];
		
    return;
    
  } else if ([payload[@"command"] isEqualToString:@"syncDone"]) {
	NSLog(@"peer told us sync done");
		
    [self.calibratedPeers addObject:socket];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"peerCalibrated" object:self.calibratedPeers userInfo:@{@"calibratedPeer": socket}];
    
    return;
		
  } else if ([payload[@"command"] isEqualToString:@"syncPing"]) {// This is done on the peer with which we are calculating the offset (Host).
    NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncPong",
                                                                                        @"timeReceived": [NSNumber numberWithUnsignedLongLong:[self currentTime]],
                                                                                        @"timeSent": payload[@"timeSent"],
                                                                                        }];
    
    NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
    
    // Speakers are only connected to the host.
    Packet *packet = [[Packet alloc] initWithData:payload type:0 action:PacketActionSync];
    [self.connectivityManager sendPacket:packet toSockets:@[socket]];
    
    return;
    
    // This is done on the person who callled calculateTimeOffsetWithHost (Player).
  } else if ([payload[@"command"] isEqualToString:@"syncPong"]) {
    
    // Calculate the offset and add it to the calculated offsets.
    uint64_t timePingSent = ((NSNumber*)payload[@"timeSent"]).unsignedLongLongValue;
    uint64_t timeHostReceivedPing = ((NSNumber*)payload[@"timeReceived"]).unsignedLongLongValue;
    
    //uint64_t latencyWithHost = ([self currentTime] - timePingSent)/2;// Calculates the estimated latency for one way travel
    
    // If this calculation doesn't meet our error margin (5s), restart.
    if (((int64_t)[self currentTime] - (int64_t)timePingSent) > 5000000000) {
      NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncPing",
                                                                                          @"timeSent": [NSNumber numberWithUnsignedLongLong:[self currentTime]]
                                                                                          }];
      NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
      
      Packet *packet = [[Packet alloc] initWithData:payload type:0 action:PacketActionSync];
      [self.connectivityManager sendPacket:packet toSockets:@[socket]];
      
      return;
    }
    
    int64_t calculatedOffset = ((int64_t)[self currentTime] + (int64_t)timePingSent - (2*(int64_t)timeHostReceivedPing))/2; // WAY 1. Best because it doesn't depend on latency
	
	// Used to get the average offset.
    totalCalculatedOffsets += calculatedOffset;
    calculatedOffsets += 1;
    
    NSLog(@"Calculated calibration. Total: %f", calculatedOffsets);
    
    // If the calibration is accurate enough just end it.
	BOOL doneCalibrating = false;
    double newOffset = totalCalculatedOffsets/calculatedOffsets;
    
    if (fabs(newOffset-self.hostTimeOffset) < 200 && calculatedOffset > 1) {
	  doneCalibrating = true;
	  NSLog(@"prematurely ended calibration because accurate enough with difference: %f", fabs(newOffset-self.hostTimeOffset));
    }
    
    self.hostTimeOffset = newOffset;
	  
    // If calculation is done notify the host.
    if (calculatedOffsets >= self.maxNumberOfCalibrations || doneCalibrating) {
      NSLog(@"Calibration done with maximum number of calibrations, informing host.");
      
      // Let the host know we calibrated
      NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncDone"}];
      NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
      
      Packet *packet = [[Packet alloc] initWithData:payload type:0 action:PacketActionSync];
      [self.connectivityManager sendPacket:packet toSockets:@[socket]];
      
      // Update the bool
      self.isCalibrating = NO;
			
	  // Post the calibration done notification
	  [[NSNotificationCenter defaultCenter] postNotificationName:CalibrationDoneNotificationName object:self];
			
    } else {
      // Send another calibration request.
      NSMutableDictionary *payloadDic = [[NSMutableDictionary alloc] initWithDictionary:@{@"command": @"syncPing",
                                                                                          @"timeSent": [NSNumber numberWithUnsignedLongLong:[self currentTime]]
                                                                                          }];
      NSData *payload = [NSKeyedArchiver archivedDataWithRootObject:payloadDic];
      
      Packet *packet = [[Packet alloc] initWithData:payload type:0 action:PacketActionSync];
      [self.connectivityManager sendPacket:packet toSockets:@[socket]];
    }
    
    return;
  }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)socket withError:(NSError *)error {
  // Remove any reference to this socket
  if (socket) {
    [self.calibratedPeers removeObject:socket];
  }
  
  self.isCalibrating = NO;
  self.hostTimeOffset = 0;
}

@end
