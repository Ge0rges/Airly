//
//  ConnectivityManager.h
//  Bass-Sync
//
//  Created by Georges Kanaan on 12/06/2017.
//

// Frameworks
#import <Foundation/Foundation.h>

// Frameworks & Librairies
@import CocoaAsyncSocket;
#import "Packet.h"

@protocol ConnectivityManagerDelegate <NSObject>

@optional
- (void)socket:(GCDAsyncSocket * _Nonnull)socket didAcceptNewSocket:(GCDAsyncSocket * _Nonnull)newSocket;
- (void)didReceivePacket:(Packet * _Nonnull)packet fromSocket:(GCDAsyncSocket *_Nonnull)socket ;
- (void)socketDidDisconnect:(GCDAsyncSocket * _Nonnull)socket withError:(NSError * _Nonnull)error;
- (void)socket:(GCDAsyncSocket * _Nonnull)socket didConnectToHost:(NSString * _Nonnull)host port:(UInt16)port;
- (void)didConnectToService:(NSNetService * _Nonnull)service;
@end


@interface ConnectivityManager : NSObject

@property (nonatomic, weak) id<ConnectivityManagerDelegate> _Nullable delegate;
@property (nonatomic, weak) id<ConnectivityManagerDelegate> _Nullable synaction;

@property (strong, nonatomic) NSMutableArray<GCDAsyncSocket *> * _Nonnull allSockets;
@property (strong, nonatomic) GCDAsyncSocket * _Nullable hostSocket;

@property (readonly, strong, nonatomic) NSString * _Nullable hostName;

+ (instancetype _Nullable)sharedManager;

- (void)sendPacket:(Packet * _Nonnull)packet toSockets:(NSArray<GCDAsyncSocket *> *_Nonnull)sockets;
- (void)startBonjourBroadcast;

- (void)startBrowsingForBonjourBroadcast;
- (void)stopBonjour;
- (void)disconnectSockets;

@end
