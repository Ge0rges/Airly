//
//  Packet.m
//  AirlyAsync
//
//  Created by Georges Kanaan on 12/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

#import "Packet.h"

NSString * const PacketKeyData = @"data";
NSString * const PacketKeyType = @"type";
NSString * const PacketKeyAction = @"action";

@implementation Packet

#pragma mark -
#pragma mark Initialization
- (id)initWithData:(id)data type:(PacketType)type action:(PacketAction)action {
  self = [super init];
  
  if (self) {
    self.data = data;
    self.type = type;
    self.action = action;
  }
  
  return self;
}

#pragma mark -
#pragma mark NSCoding Protocol
- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:self.data forKey:PacketKeyData];
  [coder encodeInteger:self.type forKey:PacketKeyType];
  [coder encodeInteger:self.action forKey:PacketKeyAction];
}

- (id)initWithCoder:(NSCoder *)decoder {
  self = [super init];
  
  if (self) {
    [self setData:[decoder decodeObjectForKey:PacketKeyData]];
    [self setType:(PacketType)[decoder decodeIntegerForKey:PacketKeyType]];
    [self setAction:(PacketAction)[decoder decodeIntegerForKey:PacketKeyAction]];
  }
  
  return self;
}

@end
