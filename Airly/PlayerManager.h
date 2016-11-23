//
//  PlayerManager.h
//  Airly
//
//  Created by Georges Kanaan on 2/18/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

// Frameworks
#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>

@protocol PlayerManagerDelegate <NSObject>
@optional
- (void)mediaPicker:(MPMediaPickerController * _Nonnull)mediaPicker didPickMediaItems:(MPMediaItemCollection * _Nullable)mediaItemCollection;
- (void)mediaPickerDidCancel:(MPMediaPickerController * _Nonnull)mediaPicker;
@end

@interface PlayerManager : NSObject <MPMediaPickerControllerDelegate>

@property (nonatomic, assign) id<PlayerManagerDelegate> _Nullable delegate;
@property (strong, nonatomic) MPMusicPlayerController * _Nullable musicController;
@property (strong, nonatomic) MPMediaItemCollection * _Nullable mediaCollection;
@property (strong, nonatomic) MPMediaPickerController * _Nullable picker;

+ (instancetype _Nonnull)sharedInstance;

- (void)presentMediaPickerOnController:(UIViewController * _Nonnull)viewController completion:(void (^ _Nullable)(void))completion;
- (void)loadMediaCollection:(MPMediaItemCollection * _Nonnull)mediaCollection;

// Commands
- (void)play;
- (void)pause;
- (void)skipToNextSong;
- (void)skipToPreviousSong;

- (MPMediaItem * _Nullable)previousMediaItem;
- (MPMediaItem * _Nullable)currentMediaItem;
- (MPMediaItem * _Nullable)nextMediaItem;

- (NSString * _Nullable)currentSongName;
- (NSString * _Nullable)currentSongArtist;
- (UIImage * _Nullable)currentSongAlbumArt;

@end
