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
- (instancetype)initWithData:(_Nonnull id)data type:(PacketType)type action:(PacketAction)action {
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
- (void)encodeWithCoder:(NSCoder * _Nonnull)coder {
    [coder encodeObject:self.data forKey:PacketKeyData];
    [coder encodeInteger:self.type forKey:PacketKeyType];
    [coder encodeInteger:self.action forKey:PacketKeyAction];
}

- (_Nullable instancetype)initWithCoder:(NSCoder * _Nonnull)decoder {
    self = [super init];
    
    if (self) {
        [self setData:[decoder decodeObjectOfClass:[NSData class] forKey:PacketKeyData]];
        [self setType:(PacketType)[decoder decodeIntegerForKey:PacketKeyType]];
        [self setAction:(PacketAction)[decoder decodeIntegerForKey:PacketKeyAction]];
    }
    
    return self;
}

#pragma mark NSSecureCoding Protocol
+ (BOOL)supportsSecureCoding {
    return TRUE;
}

@end
