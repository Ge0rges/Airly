//
//  AppDelegate.h
//  Airly
//
//  Created by Georges Kanaan on 2/16/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ConnectivityManager.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic, strong) ConnectivityManager *connectivityManager;

@end

