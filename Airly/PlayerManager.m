//
//  PlayerManager.m
//  Airly
//
//  Created by Georges Kanaan on 2/18/15.
//  Copyright (c) 2015 Georges Kanaan. All rights reserved.
//

#import "PlayerManager.h"

// Managers
#import "SyncManager.h"

@interface PlayerManager ()

@property (strong, nonatomic) SyncManager *syncManager;

@end

@implementation PlayerManager

+ (instancetype)sharedManager {
  static PlayerManager *sharedManager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedManager = [[self alloc] init];
    
    // Create the music picker
    sharedManager.picker = [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeMusic];
    sharedManager.picker.delegate = sharedManager;
    sharedManager.picker.allowsPickingMultipleItems = YES;
    sharedManager.picker.showsCloudItems = NO;
    sharedManager.picker.showsItemsWithProtectedAssets = NO;
    sharedManager.picker.prompt = NSLocalizedString(@"Add Songs",);
    
    // Create the player
    sharedManager.musicController = [MPMusicPlayerController systemMusicPlayer];
    sharedManager.musicController.repeatMode = MPMusicRepeatModeNone;
    sharedManager.musicController.shuffleMode = MPMusicShuffleModeOff;
    
    // Get the sync manager
    sharedManager.syncManager = [SyncManager sharedManager];
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
- (void)playAtPlaybackTime:(NSTimeInterval)playbackTime locallyAndOnHosts:(NSArray<MCPeerID *> * _Nonnull)peers completion:(completionBlock)block {  
#warning what could happen is that one will fail to calibrate. This block will never get called.
  // Ask peers to calibrate first.
  [self.syncManager askPeersToCalculateOffset:peers];
  [self.syncManager executeBlockWhenAllPeersCalibrate:peers block:^(NSArray <MCPeerID *> * _Nullable sentPeers) {
    // Order a Synchronize play
    uint64_t timeToPlay = [self.syncManager synchronisePlayWithCurrentPlaybackTime:playbackTime whileHostPlaying:NO];
    
    // Play at specified date
    [self.syncManager atExactTime:timeToPlay runBlock:^{
      // Set the playback time on the current device
      if (playbackTime != self.musicController.currentPlaybackTime) {
        self.musicController.currentPlaybackTime = playbackTime;
      }
      
      // Play
      [self.musicController play];
      
      // Execute the block
      dispatch_async(dispatch_get_main_queue(), ^{
        if (block) {
          block();
        }
      });
    }];
  }];
}

- (void)pauseLocallyAndOnHosts:(NSArray<MCPeerID *> *)peers completion:(completionBlock)block {
  // Order a synchronized pause
  uint64_t timeToPause = [self.syncManager synchronisePause];
  
  // Pause at specified date
  [self.syncManager atExactTime:timeToPause runBlock:^{
    
    //Pause
    [self.musicController pause];
    
    // Execute the block
    dispatch_async(dispatch_get_main_queue(), ^{
      if (block) {
        block();
      }
    });
  }];
}

- (void)skipToNextSongLocally {
  // Reset to playback time to 0
  self.musicController.currentPlaybackTime = (NSTimeInterval)0;
  
  // Go to next song
  [self.musicController skipToNextItem];
}

- (void)skipToPreviousSongLocally {
  // Reset to playback time to 0
  self.musicController.currentPlaybackTime = (NSTimeInterval)0;
  
  // Go to next song
  [self.musicController skipToPreviousItem];
}

#pragma mark - Song Order
- (MPMediaItem *)nextMediaItem {
  if (self.mediaCollection.items.count > self.musicController.indexOfNowPlayingItem+1  && self.musicController.indexOfNowPlayingItem != NSNotFound) {
    return [self.mediaCollection.items objectAtIndex:self.musicController.indexOfNowPlayingItem+1];
    
  } else {
    return nil;
  }
}
- (MPMediaItem *)currentMediaItem {
  return self.musicController.nowPlayingItem;
}

- (MPMediaItem * _Nullable)previousMediaItem {
  if (self.musicController.indexOfNowPlayingItem >= 1 && self.musicController.indexOfNowPlayingItem != NSNotFound) {
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
