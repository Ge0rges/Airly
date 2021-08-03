//
//  Packet.h
//  AirlyAsync
//
//  Created by Georges Kanaan on 12/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

#import <Foundation/Foundation.h>

extern  NSString * _Nonnull  const PacketKeyData;
extern  NSString * _Nonnull const PacketKeyType;
extern  NSString * _Nonnull const PacketKeyAction;

typedef enum {
  PacketTypeUnknown = -1,
  PacketTypeControl = 0,
  PacketTypeFile,
  PacketTypeMetadata,
  
} PacketType;

typedef enum {
  PacketActionUnknown = -1,
  PacketActionSync = 0,
  PacketActionPlay,
  PacketActionPause,
} PacketAction;

@interface Packet : NSObject <NSCoding, NSSecureCoding>

@property (strong, nonatomic) NSData * _Nullable data;// Must conform to NSCoding
@property (assign, nonatomic) PacketType type;// Optionally assign a type to this packet
@property (assign, nonatomic) PacketAction action;// Optionally assign a action to this packet

- (_Nonnull instancetype)initWithData:(_Nonnull id)data type:(PacketType)type action:(PacketAction)action;
- (_Nullable instancetype)initWithCoder:(NSCoder * _Nonnull)coder;
- (void)encodeWithCoder:(NSCoder * _Nonnull)coder;

@end
