//
//  UIImage+Gradient.h
//  Airly
//
//  Created by Georges Kanaan on 14/02/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Gradient)
+ (UIImage *)gradientFromColor:(UIColor *)fromColor toColor:(UIColor *)toColor withSize:(CGSize)size;
@end
