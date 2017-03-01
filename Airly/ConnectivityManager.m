
//
//  ConnectivityManager.m
//  Airly
//
//  Created by Georges Kanaan on 2/16/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "ConnectivityManager.h"

#define serviceTypeKey @"Airly"

@interface ConnectivityManager ()

@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCAdvertiserAssistant *advertiser;

@end

@implementation ConnectivityManager

@synthesize delegate;

+ (instancetype)sharedManagerWithDisplayName:(NSString * _Nonnull)displayName {
  static ConnectivityManager *sharedManager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedManager = [[self alloc] init];
    
    sharedManager.peerID = [[MCPeerID alloc] initWithDisplayName:displayName];
    sharedManager.sessions = [NSMutableArray new];// Init the array to store sessions
    [sharedManager availableSession];// Create a session
  });
  
  return sharedManager;
}

- (MCSession *)availableSession {
  // Try and use an existing session (self.sessions is a mutable array)
  for (MCSession *session in self.sessions) {
    if ([session.connectedPeers count] < kMCSessionMaximumNumberOfPeers) {
      return session;
    }
  }
  
  // Or create a new session
  MCSession *newSession = [self newSession];
  [self.sessions addObject:newSession];
  
  return newSession;
}

- (MCSession *)newSession {
  MCSession *session = [[MCSession alloc] initWithPeer:self.peerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
  session.delegate = self;
  
  return session;
}

- (void)setupBrowser {
  self.browser = [[MCBrowserViewController alloc] initWithServiceType:serviceTypeKey session:[self availableSession]];
  self.browser.delegate = self;
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession *))invitationHandler {
  
  MCSession *session = [self availableSession];
  if (invitationHandler) invitationHandler(YES, session);
}

- (void)advertiseSelfInSessions:(BOOL)advertise {
  for (MCSession *session in self.sessions) {
    if (advertise) {
      self.advertiser = [[MCAdvertiserAssistant alloc] initWithServiceType:serviceTypeKey discoveryInfo:nil session:session];
      self.advertiser.delegate = self;
      [self.advertiser start];
      
    } else {
      [self.advertiser stop];
      self.advertiser = nil;
    }
  }
}

- (void)disconnect {
  for (MCSession *session in self.sessions) {
    [session disconnect];
  }
}

- (NSMutableArray * _Nullable)allPeers {
  // Get all peers
  NSMutableArray *peers = [NSMutableArray new];
  for (MCSession *session in self.sessions) {
    for (MCPeerID *peerID in session.connectedPeers) {
      [peers addObject:peerID];
    }
  }
  
  return peers;
}

#pragma mark - MCSessionDelegate
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
  if ([self.delegate respondsToSelector:@selector(session:peer:didChangeState:)]) {
    [self.delegate session:session peer:peerID didChangeState:state];
  }
  
  if ([self.syncManager respondsToSelector:@selector(session:peer:didChangeState:)]) {
    [self.syncManager session:session peer:peerID didChangeState:state];
  }
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
#warning implement
}

#pragma mark - Sending & Receiving Data
#pragma mark Sending
- (void)sendData:(NSData *)data toPeers:(NSArray *)peerIDs reliable:(BOOL)reliable {
  if ([peerIDs count] == 0) return;
  
  NSPredicate *peerNamePred = [NSPredicate predicateWithFormat:@"displayName in %@", [peerIDs valueForKey:@"displayName"]];
  
  // Need to match up peers to their session
  for (MCSession *session in self.sessions){
    
    NSArray *filteredPeerIDs = [session.connectedPeers filteredArrayUsingPredicate:peerNamePred];
    
    [session sendData:data toPeers:filteredPeerIDs withMode:(reliable) ? MCSessionSendDataReliable : MCSessionSendDataUnreliable error:nil];
  }
}

- (void)sendResourceAtURL:(NSURL *)assetUrl withName:(NSString *)name toPeers:(NSArray *)peerIDs withCompletionHandler:(void(^)(NSError *error))handler {
  if ([peerIDs count] == 0) return;
  
  NSPredicate *peerNamePred = [NSPredicate predicateWithFormat:@"displayName in %@", [peerIDs valueForKey:@"displayName"]];
  
  //Need to match up peers to their session
  for (MCSession *session in self.sessions){
    NSArray *filteredPeerIDs = [session.connectedPeers filteredArrayUsingPredicate:peerNamePred];
    
    for (MCPeerID *filteredPeerID in filteredPeerIDs) [session sendResourceAtURL:assetUrl withName:name toPeer:filteredPeerID withCompletionHandler:handler];
  }
}

#pragma mark Receiving
- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
  if ([self.delegate respondsToSelector:@selector(session:didStartReceivingResourceWithName:fromPeer:withProgress:)]) {
    [self.delegate session:session didStartReceivingResourceWithName:resourceName fromPeer:peerID withProgress:progress];
  }
  
  if ([self.syncManager respondsToSelector:@selector(session:didStartReceivingResourceWithName:fromPeer:withProgress:)]) {
    [self.syncManager session:session didStartReceivingResourceWithName:resourceName fromPeer:peerID withProgress:progress];
  }
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
  if ([self.delegate respondsToSelector:@selector(session:didFinishReceivingResourceWithName:fromPeer:atURL:withError:)]) {
    [self.delegate session:session didFinishReceivingResourceWithName:resourceName fromPeer:peerID atURL:localURL withError:error];
  }
  
  if ([self.syncManager respondsToSelector:@selector(session:didFinishReceivingResourceWithName:fromPeer:atURL:withError:)]) {
    [self.syncManager session:session didFinishReceivingResourceWithName:resourceName fromPeer:peerID atURL:localURL withError:error];
  }
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
  if ([self.delegate respondsToSelector:@selector(session:didReceiveData:fromPeer:)]) {
    [self.delegate session:session didReceiveData:data fromPeer:peerID];
  }
  
  if ([self.syncManager respondsToSelector:@selector(session:didReceiveData:fromPeer:)]) {
    [self.syncManager session:session didReceiveData:data fromPeer:peerID];
  }
}

#pragma mark - MCBrowserViewControllerDelegate
- (void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
  if ([self.delegate respondsToSelector:@selector(browserViewControllerWasCancelled:)]) {
    [self.delegate browserViewControllerWasCancelled:browserViewController];
  }}

- (void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
  if ([self.delegate respondsToSelector:@selector(browserViewControllerDidFinish:)]) {
    [self.delegate browserViewControllerDidFinish:browserViewController];
  }
}

@end
