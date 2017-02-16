//
//  ConnectivityManager.h
//  Airly
//
//  Created by Georges Kanaan on 2/16/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

// Frameworks
#import <Foundation/Foundation.h>
#import <MultipeerConnectivity/MultipeerConnectivity.h>

@protocol ConnectivityManagerDelegate <NSObject>

@optional
- (void)session:(MCSession* _Nonnull)session didFinishReceivingResourceWithName:(NSString* _Nonnull)resourceName fromPeer:(MCPeerID* _Nonnull)peerID atURL:(NSURL* _Nonnull)localURL withError:(NSError* _Nullable)error;
- (void)session:(MCSession* _Nonnull)session didStartReceivingResourceWithName:(NSString* _Nonnull)resourceName fromPeer:(MCPeerID* _Nonnull)peerID withProgress:(NSProgress* _Nonnull)progress;
- (void)session:(MCSession * _Nonnull)session didReceiveData:(NSData * _Nonnull)data fromPeer:(MCPeerID * _Nonnull)peerID;
- (void)session:(MCSession* _Nonnull)session peer:(MCPeerID* _Nonnull)peerID didChangeState:(MCSessionState)state;

- (void)browserViewControllerWasCancelled:(MCBrowserViewController * _Nonnull)browserViewController;
- (void)browserViewControllerDidFinish:(MCBrowserViewController * _Nonnull)browserViewController;

@end


@interface ConnectivityManager : NSObject <MCSessionDelegate, MCAdvertiserAssistantDelegate, MCBrowserViewControllerDelegate>

@property (nonatomic, assign) id<ConnectivityManagerDelegate> _Nullable delegate;
@property (nonatomic, assign) id<ConnectivityManagerDelegate> _Nullable networkManager;
@property (nonatomic, strong) MCBrowserViewController * _Nullable browser;
@property (nonatomic, strong) NSMutableArray * _Nullable sessions;

+ (instancetype _Nullable)sharedManagerWithDisplayName:(NSString * _Nonnull)displayName;

- (NSMutableArray * _Nullable)allPeers;

- (void)setupBrowser;
- (void)advertiseSelfInSessions:(BOOL)advertise;
- (void)disconnect;

- (void)sendData:(NSData * _Nonnull)data toPeers:(NSArray * _Nonnull)peerIDs reliable:(BOOL)reliable;
- (void)sendResourceAtURL:(NSURL * _Nonnull)assetUrl withName:(NSString * _Nonnull)name toPeers:(NSArray * _Nonnull)peerIDs withCompletionHandler:(void(^ _Nullable)(NSError* _Nullable __strong))handler;

@end
