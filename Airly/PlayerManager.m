//
//  PlayerManager.m
//  Airly
//
//  Created by Georges Kanaan on 2/18/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "PlayerManager.h"

@implementation PlayerManager

- (instancetype)init {
  if (self = [super init]) {
    //create the picker
    //create and configure MPMediaPickerController
    picker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeMusic];
    picker.delegate = self;
    picker.allowsPickingMultipleItems = YES;
    picker.showsCloudItems = NO;
    picker.showsItemsWithProtectedAssets = NO;
  }
  
  return self;
}

#pragma mark - MediaItemCollection Management
- (void)presentMediaPickerOnController:(UIViewController *)viewController {
  //show MPMediaPickerControllerDelegate
  [viewController presentViewController:picker animated:YES completion:nil];
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

- (void)nextSong {
  [self.musicController skipToNextItem];
}
- (void)previousSong {
  [self.musicController skipToPreviousItem];
}

#pragma mark - Song Details
- (MPMediaItem *)nextMediaItem {return [[self.mediaCollection items] objectAtIndex:self.musicController.indexOfNowPlayingItem+1];}
- (MPMediaItem *)currentSong {return [self.musicController nowPlayingItem];}
- (NSString *)currentSongName {return [[self.musicController nowPlayingItem] valueForProperty:MPMediaItemPropertyTitle];}
- (NSString *)currentSongArtist {return [[self.musicController nowPlayingItem] valueForProperty:MPMediaItemPropertyArtist];}
- (UIImage *)currentSongAlbumArt {return [[[self.musicController nowPlayingItem] valueForProperty:MPMediaItemPropertyArtwork]  imageWithSize:CGSizeMake(320, 290)];}
- (float)currentSongProgress {return [self.musicController currentPlaybackTime];}

@end
