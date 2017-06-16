//
//  PlayerManager.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import Foundation
import AVKit
import AVFoundation
import MediaPlayer

//TODO: AVURLAssetPreferPreciseDurationAndTimingKey
class PlayerManager: NSObject {
  public let player = AVPlayer.init();
  public var queue: [AVPlayerItem] = [];
  public var queueMetadata: [Dictionary<String, Any?>] = [];
  
  public var isPlaying: Bool {
    return (self.player.rate != 0 && self.player.error == nil && self.queue.count > 0);
  }
  
  public var currentSong: AVPlayerItem? {
    return (self.queue.count > 0 && currentSongIndex < self.queue.count) ? self.queue[currentSongIndex] : nil;
  }
  
  public var currentMediaItem: MPMediaItem? {
    return (self.queueMediaItems!.count > 0 && currentSongIndex < self.queueMediaItems!.count) ? self.queueMediaItems![currentSongIndex] : nil;
  }
  
  public var previousSong: AVPlayerItem? {
    return (currentSongIndex > 0 && self.queue.count > 1) ? self.queue[currentSongIndex-1] : nil;
  }
  
  public var nextSong: AVPlayerItem? {
    return (currentSongIndex < self.queue.count-1 && self.queue.count > 1) ? self.queue[currentSongIndex+1] : nil;
  }
  
  public var currentSongMetadata: Dictionary<String, Any?>? {
    return (self.queueMetadata.count > currentSongIndex) ? self.queueMetadata[currentSongIndex] : nil;
  }
  
  private let session = AVAudioSession.sharedInstance();
  private var currentSongIndex = 0;
  private var queueMediaItems: [MPMediaItem]? = nil;
  
  public static let PlayerSongChangedNotificationName = NSNotification.Name(rawValue: "PlayerSongChanged");
  public static let PlayerQueueChangedNotificationName = NSNotification.Name(rawValue: "PlayerQueueChanged");
  
  static let sharedManager = PlayerManager();
  override private init() {//This prevents others from using the default '()' initializer for this class
    super.init();
    
    // Setup the session
    do {
      try self.session.setCategory(AVAudioSessionCategoryPlayback);
      try self.session.setActive(true);
      
    } catch let error as NSError {
      print("Unable to activate audio session:  \(error.localizedDescription)");
    }
    
    // Register for notifications of song end
    NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying(notification:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil);
  }
  
  public func play() {
    self.player.playImmediately(atRate: 1.0)// Play at default rate
  }
  
  public func pause() {
    self.player.pause();
  }
  
  public func loadQueueFromMPMediaItems(mediaItems: Array<MPMediaItem>?) -> Void {
    self.queueMediaItems = mediaItems!;// Save the media items.
    self.queue.removeAll();// Remove old queue.
    self.queueMetadata.removeAll();// Clear old album artwork.
    currentSongIndex = 0;
    
    if (mediaItems == nil || mediaItems!.count == 0) {
      return;
    }
    
    // For every item, get the AVPlayerItem and set it in the array.
    for mediaItem in mediaItems! {
      let mediaItemURL:URL = mediaItem.value(forProperty: MPMediaItemPropertyAssetURL) as! URL;
      let playerItem: AVPlayerItem = AVPlayerItem(asset: AVAsset(url: mediaItemURL));
      self.queue.append(playerItem);
      
      let metadata: Dictionary = ["artwork": mediaItem.artwork as Any, "artist": mediaItem.artist as Any, "title": mediaItem.title as Any] as [String : Any];
      self.queueMetadata.append(metadata);
    }
    
    self.player.replaceCurrentItem(with: queue[0]);
    NotificationCenter.default.post(name: PlayerManager.PlayerQueueChangedNotificationName, object: self, userInfo: ["queue": self.queue]);
    
    // Update notification
    self.playerDidFinishPlaying(notification: nil);
  }
  
  public func loadSongFromPlayerItem(playerItem: AVPlayerItem!) {
    self.queueMediaItems = nil;// Save the media items.
    self.queue.removeAll();// Remove old queue.
    self.queueMetadata.removeAll();// Clear old album artwork.
    currentSongIndex = 0;
    
    self.player.replaceCurrentItem(with: playerItem);
  }
  
  public func playNextSong() {
    currentSongIndex += 1;
    if (currentSongIndex > self.queue.count-1) {
      currentSongIndex = self.queue.count-1;
      return;
    }
    
    self.player.replaceCurrentItem(with: queue[currentSongIndex]);
    
    // Update notification
    self.playerDidFinishPlaying(notification: nil);
  }
  
  public func playPreviousSong() {
    currentSongIndex -= 1;
    if (currentSongIndex < 0) {
      currentSongIndex = 0;
      return;
    }
    
    self.player.replaceCurrentItem(with: queue[currentSongIndex]);
    
    // Update notification
    self.playerDidFinishPlaying(notification: nil);
  }
  
  public func seekToTimeInSeconds(time: TimeInterval, completionHandler: @escaping (Bool) -> Void) {
    // Seek to time with max precision for syncing
    self.player.seek(to: CMTimeMakeWithSeconds(time, 1000000000), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: completionHandler);
  }
  
  @objc private func playerDidFinishPlaying(notification: Notification?) {
    // Post the song changed notification
    NotificationCenter.default.post(name: PlayerManager.PlayerSongChangedNotificationName, object: self);
  }
}
