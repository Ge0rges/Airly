//
//  SyncManager.h
//  Airly
//
//  Created by Georges Kanaan on 23/11/2016.
//  Copyright © 2016 Georges Kanaan. All rights reserved.
//

// Frameworks
#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

// Managers
#import "ConnectivityManager.h"

typedef void(^ _Nullable calibrationBlock)(NSArray <MCPeerID *> * _Nullable peers);

@interface SyncManager : NSObject <ConnectivityManagerDelegate>

+ (instancetype _Nonnull)sharedManager;// Use this to get an instance of Synaction

- (uint64_t)synchronisePlayWithCurrentPlaybackTime:(NSTimeInterval)currentPlaybackTime whileHostPlaying:(BOOL)hostIsPlaying;
- (uint64_t)synchronisePause;
- (uint64_t)sendSongMetadata:(MPMediaItem * _Nonnull)mediaItem toPeers:(NSArray<MCPeerID *> * _Nonnull)peers;
- (void)sendSong:(MPMediaItem * _Nonnull)mediaItem toPeers:(NSArray<MCPeerID *> * _Nonnull)peers progress:(void(^ _Nullable)(NSArray <NSProgress *>* _Nullable progressArray))progressHandler completion:(void(^ _Nullable)(NSError * _Nullable error))handler;

- (void)askPeersToCalculateOffset:(NSArray <MCPeerID*>* _Nonnull)peers;// Asks the peers to call -calculateTimeOffsetWithHost, when completed the block of -executeBlockWhenPeerCalibrates will be called on host.
- (void)calculateTimeOffsetWithHost;// Calculate the time difference in nanoseconds between us and the host device.
- (uint64_t)currentNetworkTime;// The current host time adjusted for offset (offset = 0 if host)
- (void)atExactTime:(uint64_t)val runBlock:(dispatch_block_t _Nonnull)block;// Run block at the exact host adjusted time val adjusted
- (void)executeBlockWhenAllPeersCalibrate:(NSArray <MCPeerID *> * _Nonnull)peers block:(calibrationBlock)completionBlock;// Once EVERY peer in the array calibrates this will be called
- (void)executeBlockWhenEachPeerCalibrates:(NSArray <MCPeerID *> * _Nonnull)peers block:(calibrationBlock)completionBlock;// FOR EACH peer in the array that calibrates this will be called


@property (strong, nonatomic) NSMutableSet <MCPeerID*> * _Nullable calibratedPeers;// Array of all peers that have already calibrated
@property (nonatomic) uint64_t numberOfCalibrations;// The number of calibrations to be used to calculate the average offset. only makes sense on peer.
@property (readonly, nonatomic) int64_t offsetWithHost;// Offset between this device and the host, in nanoseconds. 0 on host.
@property (readonly, nonatomic) int64_t latencyWithHost;// Calculated latency with host for one ping (one-way) based on offsetWithHost

@end
