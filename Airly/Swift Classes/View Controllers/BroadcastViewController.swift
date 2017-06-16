//
//  BroadcastViewController.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import UIKit
import MediaPlayer

class BroadcastViewController: UIViewController, MPMediaPickerControllerDelegate {
  
  @IBOutlet var backButton: UIButton!
  @IBOutlet var numberOfClientsLabel: UILabel!
  @IBOutlet var addMusicButton: UIButton!
  @IBOutlet var albumArtImageView: UIImageView!
  @IBOutlet var songNameLabel: UILabel!
  @IBOutlet var songArtistLabel: UILabel!
  @IBOutlet var backwardPlaybackButton: UIButton!
  @IBOutlet var playbackButton: UIButton!
  @IBOutlet var forwardPlaybackButton: UIButton!
  
  let playerManager:PlayerManager = PlayerManager.sharedManager;
  let mediaPicker = MPMediaPickerController(mediaTypes: .music);
  
  override func viewDidLoad() {
    //TODO: To do Start Broadcasting Bonjour.
    
    // Configure the media picker
    mediaPicker.delegate = self;
    mediaPicker.showsCloudItems = false;
    mediaPicker.showsItemsWithProtectedAssets = false;
    mediaPicker.allowsPickingMultipleItems = true;
    
    // Register for player notifications
    NotificationCenter.default.addObserver(self, selector: #selector(self.updateInterface(notification:)), name: PlayerManager.PlayerSongChangedNotificationName, object: nil);
  }
  
  //MARK: - Button Actions
  @IBAction func dismissBroadcastViewController(_ sender: UIButton) {
    //TODO: Stop broadcasting & disconnect.
    
    // Pause
    self.playerManager.pause();
    
    // Dismiss
    self.navigationController?.popViewController(animated: true);
  }
  
  @IBAction func addMusicButtonPressed(_ sender: UIButton) {
    // Request authentication to music library
    MPMediaLibrary.requestAuthorization { (authorizationStatus) in
      DispatchQueue.main.async {// Main Queue
        // Present Media Picker
        self.present(self.mediaPicker, animated: true, completion: nil);
      }
    }
  }
  
  //MARK: Playback Controls
  @IBAction func backwardPlaybackButtonPressed(_ sender: UIButton) {
    // Rewind to previous song
    self.playerManager.playPreviousSong();
  }
  
  @IBAction func togglePlaybackButtonPressed(_ sender: UIButton) {
    if self.playerManager.isPlaying {// If playing
      // Pause and Update UI
      self.playerManager.pause();
      self.playbackButton.setImage(#imageLiteral(resourceName: "Play"), for: .normal);
      
    } else {
      // Play and Update UI
      self.playerManager.play();
      self.playbackButton.setImage(#imageLiteral(resourceName: "Pause"), for: .normal);
    }
  }
  
  @IBAction func forwardPlaybackButtonPressed(_ sender: UIButton) {
    // Skip to next song
    self.playerManager.playNextSong();
  }
  
  //MARK: - MPMediaPickerConrollerDelegate
  func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
    // Tell the player to load the items
    self.playerManager.loadQueueFromMPMediaItems(mediaItems: mediaItemCollection.items);
    
    DispatchQueue.main.async {// Main Queue
      // Dismiss Media Picker
      self.dismiss(animated: true, completion: nil);
    };
  }
  
  func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
    DispatchQueue.main.async {// Main Queue
      // Dismiss Media Picker
      self.dismiss(animated: true, completion: nil);
    };
  }
  
  // MARK: - UI Functions
  @objc func updateInterface(notification: Notification) {
    // Toggle Playback button
    let playbackImage = (self.playerManager.isPlaying) ? #imageLiteral(resourceName: "Pause") : #imageLiteral(resourceName: "Play");
    self.playbackButton.setImage(playbackImage, for: .normal);
    self.playbackButton.isEnabled = (self.playerManager.currentSong != nil);
    
    // Forward and Rewind buttons
    self.forwardPlaybackButton.isEnabled = (self.playerManager.nextSong != nil);
    self.backwardPlaybackButton.isEnabled = (self.playerManager.previousSong != nil);
    
    // Album Art
    let metadata:Dictionary<String, Any?>? = self.playerManager.currentSongMetadata;
    var artwork: UIImage? = nil;//TODO: Default Image
    var title: String = "Unknown Song Name";
    var artist: String = "Unknown Artist";
    
    if let metadata = metadata {
      let mediaItemArtwork = metadata["artwork"] as! MPMediaItemArtwork?;
      if (mediaItemArtwork != nil) {
        artwork = mediaItemArtwork!.image(at: self.albumArtImageView.frame.size);
      }
      
      let mediaItemArtist = metadata["artist"] as! String?;
      if (mediaItemArtist != nil) {
        artist = mediaItemArtist!;
      }
      
      let mediaItemTitle = metadata["title"] as! String?;
      if (mediaItemTitle != nil) {
        title = mediaItemTitle!;
      }
    }
    
    self.albumArtImageView.image = artwork;
    self.songNameLabel.text = title;
    self.songArtistLabel.text = artist;
  }
}
