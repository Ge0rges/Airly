//
//  Synaction.h
//  Synaction
//
//  Created by Georges Kanaan on 11/02/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

// Frameworks
#import <Foundation/Foundation.h>

// Managers
#import "ConnectivityManager.h"

#define CalibrationDoneNotificationName  @"CalibrationDone"

typedef void(^ _Nullable calibrationBlock)(NSArray <GCDAsyncSocket *> * _Nullable peers);
 
@interface Synaction : NSObject <ConnectivityManagerDelegate>

+ (instancetype _Nonnull)sharedManager;// Use this to get an instance of Synaction

- (void)askPeersToCalculateOffset:(NSArray <GCDAsyncSocket*>* _Nonnull)peers;// Asks the peers to call -calculateTimeOffsetWithHost, when completed the block of -executeBlockWhenPeerCalibrates will be called on host.
- (void)calculateTimeOffsetWithHost:(GCDAsyncSocket * _Nonnull)hostPeer;// Calculate the time difference in nanoseconds between us and the host device.
- (uint64_t)currentTime;// Current clock time. If on host this is equal to currentNetworkTime
- (uint64_t)currentNetworkTime;// The current host time adjusted for offset (offset = 0 if host).
- (void)atExactTime:(uint64_t)val runBlock:(dispatch_block_t _Nonnull)block;// Run block at the exact host adjusted time val adjusted
- (void)executeBlockWhenAllPeersCalibrate:(NSArray <GCDAsyncSocket *> * _Nonnull)peers block:(calibrationBlock)completionBlock;// Once EVERY peer in the array calibrates this will be called
- (void)executeBlockWhenEachPeerCalibrates:(NSArray <GCDAsyncSocket *> * _Nonnull)peers block:(calibrationBlock)completionBlock;// FOR EACH peer in the array that calibrates this will be called

@property (strong, nonatomic) NSMutableSet <GCDAsyncSocket*> * _Nullable calibratedPeers;// Array of all peers that have already calibrated
@property (nonatomic, readonly) uint64_t maxNumberOfCalibrations;// The number of calibrations to be used to calculate the averaga offset offset
@property (nonatomic, readonly) uint64_t latencyWithHost;// The calculated latency between the peer and host. Only on peer.
@property (nonatomic, readonly) int64_t hostTimeOffset;// The calculated offset between the peer and the host. Only on peer.
@property (strong, nonatomic) ConnectivityManager * _Nonnull connectivityManager;// The accompanying connectivity manager.
@property (readonly, nonatomic) BOOL isCalibrating;// Indicates wether we are currently calibrating with host.

@end
