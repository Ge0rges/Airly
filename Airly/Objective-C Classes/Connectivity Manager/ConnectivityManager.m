
//
//  ConnectivityManager.m
//  Synaction
//
//  Created by Georges Kanaan on 2/16/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "ConnectivityManager.h"

@interface ConnectivityManager () <NSNetServiceDelegate, NSNetServiceBrowserDelegate, GCDAsyncSocketDelegate>

@property (strong, nonatomic) GCDAsyncSocket *socket;
@property (strong, nonatomic) NSNetService *service;
@property (strong, nonatomic) NSMutableArray *services;
@property (strong, nonatomic) NSNetServiceBrowser *serviceBrowser;

@end

@implementation ConnectivityManager

+ (instancetype)sharedManager {
  static ConnectivityManager *sharedManager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedManager = [[self alloc] init];
    
    sharedManager.services = [NSMutableArray new];
    sharedManager.allSockets = [NSMutableArray new];
  });
  
  return sharedManager;
}

#pragma mark - Host
- (void)startBonjourBroadcast {
  // Initialize GCDAsyncSocket
  self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];

  // Start Listening for Incoming Connections
  NSError *error = nil;
  if ([self.socket acceptOnPort:0 error:&error]) {
    // Initialize Service
    self.service = [[NSNetService alloc] initWithDomain:@"local." type:@"_airly._tcp." name:@"" port:self.socket.localPort];

    // Configure Service
    [self.service setDelegate:self];

    // Publish Service
    [self.service publish];

  } else {
    NSLog(@"Unable to create socket. Error %@ with user info %@.", error, [error userInfo]);
  }
}


#pragma mark - Peer
- (void)startBrowsingForBonjourBroadcast {
  if (self.services) {
    [self.services removeAllObjects];
    
  } else {
    self.services = [[NSMutableArray alloc] init];
  }

  // Initialize Service Browser
  self.serviceBrowser = [[NSNetServiceBrowser alloc] init];

  // Configure Service Browser
  [self.serviceBrowser setDelegate:self];
  [self.serviceBrowser searchForServicesOfType:@"_airly._tcp." inDomain:@"local."];
}

- (void)stopBonjour {
  [self.service stop];

  if (self.serviceBrowser) {
    [self.serviceBrowser stop];
    [self.serviceBrowser setDelegate:nil];
    [self setServiceBrowser:nil];
  }
}


- (BOOL)connectWithService:(NSNetService *)service {
  BOOL _isConnected = NO;

  // Copy Service Addresses
  NSArray *addresses = [[service addresses] mutableCopy];

  if (!self.socket || ![self.socket isConnected]) {
    // Initialize Socket
    self.allSockets[0] = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];

    // Connect
    while (!_isConnected && [addresses count]) {
      NSData *address = [addresses objectAtIndex:0];

      NSError *error = nil;
      if ([self.allSockets[0] connectToAddress:address error:&error]) {
        _isConnected = YES;

      } else if (error) {
        NSLog(@"Unable to connect to address. Error %@ with user info %@.", error, [error userInfo]);
      }
    }

  } else {
    _isConnected = [self.allSockets[0] isConnected];
  }

  return _isConnected;
}

#pragma mark - Sending & Receiving
- (void)sendPacket:(Packet *)packet toSockets:(NSArray<GCDAsyncSocket *> *)sockets{
  // Encode Packet Data
  NSMutableData *packetData = [[NSMutableData alloc] init];
  NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:packetData];
  [archiver encodeObject:packet forKey:@"packet"];
  [archiver finishEncoding];

  // Initialize Buffer
  NSMutableData *buffer = [[NSMutableData alloc] init];

  // Fill Buffer
  uint64_t headerLength = [packetData length];
  [buffer appendBytes:&headerLength length:sizeof(uint64_t)];
  [buffer appendBytes:[packetData bytes] length:[packetData length]];

  // Write Buffer
  for (GCDAsyncSocket *socket in sockets) {
    [socket writeData:buffer withTimeout:-1.0 tag:0];
  }
}

- (uint64_t)parseHeader:(NSData *)data {
  uint64_t headerLength = 0;
  memcpy(&headerLength, [data bytes], sizeof(uint64_t));

  return headerLength;
}

- (Packet *)parseBody:(NSData *)data {
  NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
  Packet *packet = [unarchiver decodeObjectForKey:@"packet"];
  [unarchiver finishDecoding];

  NSLog(@"Parsed Packet Data > %@", packet.data);
  NSLog(@"Parsed Packet Type > %i", packet.type);
  NSLog(@"Parsed Packet Action > %i", packet.action);

  return packet;
}

#pragma mark - NSNetServiceDelegate
- (void)netServiceDidPublish:(NSNetService *)service {
  NSLog(@"Bonjour Service Published: domain(%@) type(%@) name(%@) port(%i)", service.domain, service.type, service.name, (int)service.port);
}

- (void)netService:(NSNetService *)service didNotPublish:(NSDictionary *)errorDict {
  NSLog(@"Failed to Publish Service: domain(%@) type(%@) name(%@) - %@", service.domain, service.type, service.name, errorDict);
}

- (void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)errorDict {
  [service setDelegate:nil];
}

- (void)netServiceDidResolveAddress:(NSNetService *)service {
  // Connect With Service
  if ([self connectWithService:service]) {
    NSLog(@"Did Connect with Service: domain(%@) type(%@) name(%@) port(%i)", service.domain, service.type, service.name, (int)service.port);
  } else {
    NSLog(@"Unable to Connect with Service: domain(%@) type(%@) name(%@) port(%i)", service.domain, service.type, service.name, (int)service.port);
  }
}

#pragma mark NSNetServiceBrowserDelegate
- (void)netServiceBrowser:(NSNetServiceBrowser *)serviceBrowser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing {
  // Update Services
  [self.services addObject:service];

  if(!moreComing) {
    // Sort Services
    [self.services sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];

    // Update UI

    // Connect
    NSNetService *service = self.services[0];

    // Resolve Service
    [service setDelegate:self];
    [service resolveWithTimeout:10.0];
  }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)serviceBrowser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing {
  // Update Services
  [self.services removeObject:service];
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)serviceBrowser {
  [self stopBonjour];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aBrowser didNotSearch:(NSDictionary *)userInfo {
  [self stopBonjour];
}

#pragma mark - GCDAsyncSocketDelegate
- (void)socket:(GCDAsyncSocket *)socket didAcceptNewSocket:(GCDAsyncSocket *)newSocket {
  NSLog(@"Accepted New Socket from %@:%hu", [newSocket connectedHost], [newSocket connectedPort]);

  // Add socket to our array
  [self.allSockets addObject:newSocket];
  
  // Read Data from Socket
  [newSocket readDataToLength:sizeof(uint64_t) withTimeout:-1.0 tag:0];

  // Call Delegates
  if ([self.delegate respondsToSelector:@selector(socket:didAcceptNewSocket:)]) {
    [self.delegate socket:socket didAcceptNewSocket:newSocket];
  }

  if ([self.synaction respondsToSelector:@selector(socket:didAcceptNewSocket:)]) {
    [self.synaction socket:socket didAcceptNewSocket:newSocket];
  }
}

- (void)socket:(GCDAsyncSocket *)socket didConnectToHost:(NSString *)host port:(UInt16)port {
  NSLog(@"Socket Did Connect to Host: %@ Port: %hu", host, port);

  // Start Reading
  [socket readDataToLength:sizeof(uint64_t) withTimeout:-1.0 tag:0];
  
  if ([self.delegate respondsToSelector:@selector(socket:didConnectToHost:port:)]) {
    [self.delegate socket:socket didConnectToHost:host port:port];
  }
  
  if ([self.synaction respondsToSelector:@selector(socket:didConnectToHost:port:)]) {
    [self.synaction socket:socket didConnectToHost:host port:port];
  }
}

- (void)socket:(GCDAsyncSocket *)socket didReadData:(NSData *)data withTag:(long)tag {
  if (tag == 0) {
    uint64_t bodyLength = [self parseHeader:data];
    [socket readDataToLength:bodyLength withTimeout:-1.0 tag:1];

  } else if (tag == 1) {
    Packet *packet = [self parseBody:data];

    if ([self.delegate respondsToSelector:@selector(didReceivePacket:fromSocket:)]) {
      [self.delegate didReceivePacket:packet fromSocket:socket];
    }

    if ([self.synaction respondsToSelector:@selector(didReceivePacket:fromSocket:)]) {
      [self.synaction didReceivePacket:packet fromSocket:socket];
    }

    [socket readDataToLength:sizeof(uint64_t) withTimeout:-1 tag:0];
  }
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)socket withError:(NSError *)error {
  NSLog(@"%s error: %@", __PRETTY_FUNCTION__, error);
  
  [self.allSockets removeObject:socket];
  
  if ([self.delegate respondsToSelector:@selector(socketDidDisconnect:withError:)]) {
    [self.delegate socketDidDisconnect:socket withError:error];
  }
  
  if ([self.synaction respondsToSelector:@selector(socketDidDisconnect:withError:)]) {
    [self.synaction socketDidDisconnect:socket withError:error];
  }
}

@end
