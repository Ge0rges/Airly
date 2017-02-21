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

typedef void(^ _Nullable calibrationBlock)(MCPeerID * _Nullable peer);

@interface SyncManager : NSObject <ConnectivityManagerDelegate>

+ (instancetype _Nonnull)sharedManager;

- (uint64_t)synchronisePlayWithCurrentPlaybackTime:(NSTimeInterval)currentPlaybackTime;
- (uint64_t)synchronisePause;
- (uint64_t)sendSongMetadata:(MPMediaItem * _Nonnull)mediaItem toPeers:(NSArray<MCPeerID *> * _Nonnull)peers;
- (void)sendSong:(MPMediaItem * _Nonnull)mediaItem toPeers:(NSArray<MCPeerID *> * _Nonnull)peers completion:(void(^ _Nullable)(NSError * _Nullable error))handler;

- (void)askPeersToCalculateOffset;
- (void)calculateTimeOffsetWithHostFromStart:(BOOL)resetBools;
- (uint64_t)currentNetworkTime;
- (void)atExactTime:(uint64_t)val runBlock:(dispatch_block_t _Nonnull)block;
- (void)executeBlockWhenPeerCalibrates:(MCPeerID * _Nonnull)peer block:(calibrationBlock)completionBlock;

@property (strong, nonatomic) NSMutableSet <MCPeerID*> * _Nullable calibratedPeers;

@end
