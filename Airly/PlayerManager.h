//
//  PlayerManager.h
//  Airly
//
//  Created by Georges Kanaan on 2/18/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@protocol PlayerManagerDelegate <NSObject>
@optional
-(void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection;
-(void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker;
@end

@interface PlayerManager : NSObject <MPMediaPickerControllerDelegate> {
    MPMediaPickerController *picker;
}

@property (nonatomic, assign) id<PlayerManagerDelegate> delegate;
@property (strong, nonatomic) MPMusicPlayerController *musicController;
@property (strong, nonatomic) MPMediaItemCollection *mediaCollection;

-(instancetype)init;
-(void)presentMediaPickerOnController:(UIViewController *)viewController;
-(void)loadMediaCollection:(MPMediaItemCollection *)mediaCollection;
-(MPMediaItem *)currentSong;
-(void)play;
-(void)pause;
-(void)nextSong;
-(void)previousSong;
-(MPMediaItem *)nextMediaItem;
-(NSString *)currentSongName;
-(NSString *)currentSongArtist;
-(UIImage *)currentSongAlbumArt;
-(float)currentSongProgress;
@end
