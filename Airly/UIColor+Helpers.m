//
//  UIColor+Helpers.m
//  Airly
//
//  Created by Georges Kanaan on 14/02/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

#import "UIColor+Helpers.h"

@implementation UIColor (Helpers)

+ (UIColor *)generateRandomColor {
  CGFloat hue = ( arc4random() % 256 / 256.0 );  //  0.0 to 1.0
  CGFloat saturation = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from white
  CGFloat brightness = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from black
  return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
}

// http://stackoverflow.com/questions/11598043/get-slightly-lighter-and-darker-color-from-uicolor
- (UIColor *)lighterColor {
  CGFloat h, s, b, a;
  if ([self getHue:&h saturation:&s brightness:&b alpha:&a]) {
    return [UIColor colorWithHue:h saturation:s brightness:MIN(b * 1.3, 1.0) alpha:a];
  }
  
  return nil;
}

- (UIColor *)darkerColor {
  CGFloat h, s, b, a;
  if ([self getHue:&h saturation:&s brightness:&b alpha:&a]) {
    return [UIColor colorWithHue:h saturation:s brightness:MIN(b * 0.75, 0.6) alpha:a];
  }
  
  return nil;
}

@end
