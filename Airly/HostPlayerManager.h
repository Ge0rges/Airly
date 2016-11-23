//
//  HostPlayerManager.h
//  Airly
//
//  Created by Georges Kanaan on 23/11/2016.
//  Copyright © 2016 Georges Kanaan. All rights reserved.
//

// Frameworks
#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@interface HostPlayerManager : NSObject

+ (NSDate * _Nonnull)synchronisePlayWithCurrentTime:(NSTimeInterval)currentPlaybackTime;
+ (NSDate * _Nonnull)synchronisePause;
+ (NSDate * _Nonnull)sendSongMetadata:(MPMediaItem * _Nonnull)mediaItem toPeers:(NSArray<MCPeerID *> * _Nonnull)peers;
+ (void)sendSong:(MPMediaItem * _Nonnull)mediaItem toPeers:(NSArray<MCPeerID *> * _Nonnull)peers completion:(void(^ _Nullable)(NSError * _Nullable error))handler;


@end
