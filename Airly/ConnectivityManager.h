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
- (void)session:(MCSession*)session didFinishReceivingResourceWithName:(NSString*)resourceName fromPeer:(MCPeerID*)peerID atURL:(NSURL*)localURL withError:(NSError*)error;
- (void)session:(MCSession*)session didStartReceivingResourceWithName:(NSString*)resourceName fromPeer:(MCPeerID*)peerID withProgress:(NSProgress*)progress;
- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID;
- (void)session:(MCSession*)session peer:(MCPeerID*)peerID didChangeState:(MCSessionState)state;

- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController;
- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController;

@end


@interface ConnectivityManager : NSObject <MCSessionDelegate, MCAdvertiserAssistantDelegate, MCBrowserViewControllerDelegate>

@property (nonatomic, assign) id<ConnectivityManagerDelegate> delegate;
@property (nonatomic, assign) id<ConnectivityManagerDelegate> networkPlayerManager;
@property (nonatomic, strong) MCBrowserViewController *browser;
@property (nonatomic, strong) NSMutableArray *sessions;

+ (instancetype)sharedManagerWithDisplayName:(NSString *)displayName;

- (MCSession *)availableSession;
- (NSMutableArray *)allPeers;

- (void)setupBrowser;
- (void)advertiseSelfInSessions:(BOOL)advertise;

- (void)sendData:(NSData *)data toPeers:(NSArray *)peerIDs reliable:(BOOL)reliable;
- (void)sendResourceAtURL:(NSURL *)assetUrl withName:(NSString *)name toPeers:(NSArray *)peerIDs withCompletionHandler:(void(^)(NSError*__strong))handler;

@end
