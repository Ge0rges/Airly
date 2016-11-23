//
//  PlayerManager.m
//  Airly
//
//  Created by Georges Kanaan on 2/18/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "PlayerManager.h"

@implementation PlayerManager

+ (instancetype)sharedInstance {
  static PlayerManager *sharedManager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedManager = [[self alloc] init];
    
    //create the picker
    sharedManager.picker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeMusic];
    sharedManager.picker.delegate = sharedManager;
    sharedManager.picker.allowsPickingMultipleItems = YES;
    
#warning test protected assets, cloud items.
    sharedManager.picker.showsCloudItems = NO;
    sharedManager.picker.showsItemsWithProtectedAssets = NO;
  });
  
  return sharedManager;
}

#pragma mark - MediaItemCollection Management
- (void)presentMediaPickerOnController:(UIViewController *)viewController completion:(void (^ __nullable)(void))completion {
  //show MPMediaPickerControllerDelegate
  [viewController presentViewController:self.picker animated:YES completion:completion];
}

- (void)loadMediaCollection:(MPMediaItemCollection *)mediaCollection {
  //update mediaCollection
  
  self.mediaCollection = mediaCollection;
  
  //check that a musicController exists
  if (!self.musicController) {
    self.musicController = [MPMusicPlayerController applicationMusicPlayer];
  }
  
  //set the queue
  [self.musicController setQueueWithItemCollection:self.mediaCollection];
}

#pragma mark - MPMediaPickerControllerDelegate
- (void)mediaPicker:(MPMediaPickerController *)mediaPicker didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
  [self.delegate mediaPicker:mediaPicker didPickMediaItems:mediaItemCollection];
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
  [self.delegate mediaPickerDidCancel:mediaPicker];
}

#pragma mark - Player Control
- (void)play {
  [self.musicController play];
}

- (void)pause {
  [self.musicController pause];
}

- (void)skipToNextSong {
  [self.musicController skipToNextItem];
}
- (void)skipToPreviousSong {
  [self.musicController skipToPreviousItem];
}

#pragma mark - Song Order
- (MPMediaItem *)nextMediaItem {
  if (self.mediaCollection.items.count-1 >= self.musicController.indexOfNowPlayingItem+1) {
    return [self.mediaCollection.items objectAtIndex:self.musicController.indexOfNowPlayingItem+1];
  
  } else {
    return nil;
  }
}
- (MPMediaItem *)currentMediaItem {
  return self.musicController.nowPlayingItem;
}

- (MPMediaItem * _Nullable)previousMediaItem {
  if (self.musicController.indexOfNowPlayingItem-1 > 0) {
    return [self.mediaCollection.items objectAtIndex:self.musicController.indexOfNowPlayingItem-1];
    
  } else {
    return nil;
  }
}

#pragma mark - Song Details
- (NSString *)currentSongName {
  return self.musicController.nowPlayingItem.title;
}

- (NSString *)currentSongArtist {
  return self.musicController.nowPlayingItem.artist;
}

- (UIImage *)currentSongAlbumArt {
  return [self.musicController.nowPlayingItem.artwork  imageWithSize:CGSizeMake(320, 290)];
}

@end
