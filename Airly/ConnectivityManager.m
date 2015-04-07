
//
//  ConnectivityManager.m
//  Airly
//
//  Created by Georges Kanaan on 2/16/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "ConnectivityManager.h"

@implementation ConnectivityManager

@synthesize delegate;

- (instancetype)initWithPeerWithDisplayName:(NSString *)displayName {
    if (self = [super init]) {
        self.peerID = [[MCPeerID alloc] initWithDisplayName:displayName];//set peer id
        self.sessions = [NSMutableArray new];//init the array to store sessions
        [self availableSession];//create a session
    }
    
    return self;
}

- (MCSession *)availableSession {
    
    //Try and use an existing session (_sessions is a mutable array)
    for (MCSession *session in _sessions)
        if ([session.connectedPeers count]<kMCSessionMaximumNumberOfPeers)
            return session;
    
    //Or create a new session
    MCSession *newSession = [self newSession];
    [_sessions addObject:newSession];
    
    return newSession;
}

- (MCSession *)newSession {
    
    MCSession *session = [[MCSession alloc] initWithPeer:self.peerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
    session.delegate = self;
    
    return session;
}

- (void)setupBrowser {
    self.browser = [[MCBrowserViewController alloc] initWithServiceType:@serviceTypeKey session:[self availableSession]];
    self.browser.delegate = self;
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL, MCSession *))invitationHandler {
    
    MCSession *session = [self availableSession];
    invitationHandler(YES,session);
}

- (void)advertiseSelfInSessions:(BOOL)advertise {
    for (MCSession *session in _sessions) {
        if (advertise) {
            self.advertiser = [[MCAdvertiserAssistant alloc] initWithServiceType:@serviceTypeKey discoveryInfo:nil session:session];
            self.advertiser.delegate = self;
            [self.advertiser start];
            
        } else {
            [self.advertiser stop];
            self.advertiser = nil;
        }
    }
}

#pragma mark - MCSessionDelegate
- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    [self.delegate session:session peer:peerID didChangeState:state];
}

-(void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {}

#pragma mark - Sending & Receiving Data
#pragma mark Sending
- (void)sendData:(NSData *)data toPeers:(NSArray *)peerIDs reliable:(BOOL)reliable {
    
    if ([peerIDs count] == 0) return;
    
    NSPredicate *peerNamePred = [NSPredicate predicateWithFormat:@"displayName in %@", [peerIDs valueForKey:@"displayName"]];
    
    MCSessionSendDataMode mode = (reliable) ? MCSessionSendDataReliable : MCSessionSendDataUnreliable;
    
    //Need to match up peers to their session
    for (MCSession *session in _sessions){
        
        NSArray *filteredPeerIDs = [session.connectedPeers filteredArrayUsingPredicate:peerNamePred];
        
        [session sendData:data toPeers:filteredPeerIDs withMode:mode error:nil];
    }
}

- (void)sendResourceAtURL:(NSURL *)assetUrl withName:(NSString *)name toPeers:(NSArray *)peerIDs withCompletionHandler:(void(^)(NSError *error))handler {
    
    if ([peerIDs count]==0) return;
    
    NSPredicate *peerNamePred = [NSPredicate predicateWithFormat:@"displayName in %@", [peerIDs valueForKey:@"displayName"]];
    
    //Need to match up peers to their session
    for (MCSession *session in _sessions){
        NSArray *filteredPeerIDs = [session.connectedPeers filteredArrayUsingPredicate:peerNamePred];
        
        for (MCPeerID *filteredPeerID in filteredPeerIDs) [session sendResourceAtURL:assetUrl withName:name toPeer:filteredPeerID withCompletionHandler:handler];
        NSLog(@"sent resource");
    }
}

#pragma mark Receiving
-(void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    if ([self.delegate respondsToSelector:@selector(session:didStartReceivingResourceWithName:fromPeer:withProgress:)]) {
        [self.delegate session:session didStartReceivingResourceWithName:resourceName fromPeer:peerID withProgress:progress];
    }
}

-(void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    [self.delegate session:session didFinishReceivingResourceWithName:resourceName fromPeer:peerID atURL:localURL withError:error];
}

-(void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    [self.delegate session:session didReceiveData:data fromPeer:peerID];
}

#pragma mark - MCBrowserViewControllerDelegate
-(void)browserViewControllerWasCancelled:(MCBrowserViewController *)browserViewController {
    if ([self.delegate respondsToSelector:@selector(browserViewControllerWasCancelled:)]) {
        [self.delegate browserViewControllerWasCancelled:browserViewController];
    }}

-(void)browserViewControllerDidFinish:(MCBrowserViewController *)browserViewController {
    if ([self.delegate respondsToSelector:@selector(browserViewControllerDidFinish:)]) {
        [self.delegate browserViewControllerDidFinish:browserViewController];
    }
}


@end
