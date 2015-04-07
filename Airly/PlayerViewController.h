//
//  PlayerViewController.h
//  Airly
//
//  Created by Georges Kanaan on 2/19/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "ConnectivityManager.h"

@interface PlayerViewController : UIViewController <ConnectivityManagerDelegate> {
    unsigned long receivingItemMaxCount;
    
    NSString *songTitle;
    NSString *songArtist;
    
    UIImage *albumImage;
}

@property (nonatomic, strong) ConnectivityManager *connectivityManger;
@property (nonatomic, strong) AVPlayer *player;

@property (strong, nonatomic) NSMutableArray *localSongUrls;
@property (strong, nonatomic) IBOutlet UIImageView *albumImageView;
@property (strong, nonatomic) IBOutlet UILabel *songTitleLabel;
@property (strong, nonatomic) IBOutlet UILabel *songArtistLabel;

@end
