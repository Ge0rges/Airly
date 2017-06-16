//
//  Packet.h
//  AirlyAsync
//
//  Created by Georges Kanaan on 12/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const PacketKeyData;
extern NSString * const PacketKeyType;
extern NSString * const PacketKeyAction;

typedef enum {
  PacketTypeUnknown = -1
} PacketType;

typedef enum {
  PacketActionUnknown = -1,
  PacketActionSync = 1,
  PacketActionPlay,
  PacketActionPause,
} PacketAction;

@interface Packet : NSObject

@property (strong, nonatomic) id data;// Must conform to NSCoding
@property (assign, nonatomic) PacketType type;// Optionally assign a type to this packet
@property (assign, nonatomic) PacketAction action;// Optionally assign a action to this packet

- (id)initWithData:(id)data type:(PacketType)type action:(PacketAction)action;

@end
