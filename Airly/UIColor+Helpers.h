//
//  UIColor+Helpers.h
//  Airly
//
//  Created by Georges Kanaan on 14/02/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIColor (Helpers)
+ (UIColor *)generateRandomColor;
- (UIColor *)lighterColor;
- (UIColor *)darkerColor;
@end
