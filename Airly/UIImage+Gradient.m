//
//  UIImage+Gradient.m
//  Airly
//
//  Created by Georges Kanaan on 14/02/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

#import "UIImage+Gradient.h"

@implementation UIImage (Gradient)

+ (UIImage *)gradientFromColor:(UIColor *)fromColor toColor:(UIColor *)toColor withSize:(CGSize)size {
  CAGradientLayer *layer = [CAGradientLayer layer];
  layer.frame = CGRectMake(0, 0, size.width, size.height);
  layer.colors = @[(__bridge id)fromColor.CGColor,
                   (__bridge id)toColor.CGColor];
  
  UIGraphicsBeginImageContext(size);
  [layer renderInContext:UIGraphicsGetCurrentContext()];
  UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  return image;
}



@end
