//
//  HostViewController.h
//  Airly
//
//  Created by Georges Kanaan on 2/17/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "ConnectivityManager.h"
#import "PlayerManager.h"

@interface HostViewController : UIViewController <ConnectivityManagerDelegate, PlayerManagerDelegate> {
    BOOL shouldNilOut;
}

@property (nonatomic, strong) ConnectivityManager *connectivityManger;
@property (nonatomic, strong) PlayerManager *playerManager;

@property (strong, nonatomic) IBOutlet UIImageView *albumImageView;
@property (strong, nonatomic) IBOutlet UILabel *songTitleLabel;
@property (strong, nonatomic) IBOutlet UILabel *songArtistLabel;

@end
