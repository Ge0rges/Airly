//
//  BroadcastViewController.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import UIKit
import MediaPlayer
import Flurry_iOS_SDK

class BroadcastViewController: UIViewController, MPMediaPickerControllerDelegate, ConnectivityManagerDelegate {
  
  @IBOutlet var backButton: UIButton!
  @IBOutlet var numberOfClientsLabel: UILabel!
  @IBOutlet var addMusicButton: UIButton!
  @IBOutlet var albumArtImageView: UIImageView!
  @IBOutlet var songNameLabel: UILabel!
  @IBOutlet var songArtistLabel: UILabel!
  @IBOutlet var backwardPlaybackButton: UIButton!
  @IBOutlet var playbackButton: UIButton!
  @IBOutlet var forwardPlaybackButton: UIButton!
  
  let blurEffectView:UIVisualEffectView! = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark));
  let blurImageView:UIImageView! = UIImageView.init();
  let mediaPicker:MPMediaPickerController! = MPMediaPickerController(mediaTypes: .music);
  let playerManager:PlayerManager! = PlayerManager.sharedManager;
  let connectivityManager:ConnectivityManager! = ConnectivityManager.shared();
  let synaction:Synaction! = Synaction.sharedManager();
  
  override func viewDidLoad() {
    super.viewDidLoad();
    // Start broadcasting bonjour.
    self.connectivityManager.startBonjourBroadcast();
    
    // Set the delegate for the connectivity manager
    self.synaction.connectivityManager.delegate = self;
    
    // Clear the music queue
    self.playerManager.loadQueueFromMPMediaItems(mediaItems: nil);
    
    // Configure the media picker
    mediaPicker.delegate = self;
    mediaPicker.showsCloudItems = false;
    mediaPicker.showsItemsWithProtectedAssets = false;
    mediaPicker.allowsPickingMultipleItems = true;
    
    // Register for player notifications
    NotificationCenter.default.addObserver(self, selector: #selector(self.updateInterface(notification:)), name: PlayerManager.PlayerSongChangedNotificationName, object: nil);
    NotificationCenter.default.addObserver(self, selector: #selector(self.updateInterface(notification:)), name: PlayerManager.PlayerPlayedNotificationName, object: nil);
    NotificationCenter.default.addObserver(self, selector: #selector(self.updateInterface(notification:)), name: PlayerManager.PlayerPausedNotificationName, object: nil);
		NotificationCenter.default.addObserver(self, selector: #selector(self.sendCurrentSong(notification:)), name: PlayerManager.PlayerSongChangedNotificationName, object: nil);
    NotificationCenter.default.addObserver(self, selector: #selector(self.sendPlayCommand), name: PlayerManager.PlayerPlayedNotificationName, object: nil);
    NotificationCenter.default.addObserver(self, selector: #selector(self.sendPauseCommand), name: PlayerManager.PlayerPausedNotificationName, object: nil);
    
    
    // Round & Shadow the album art
    self.albumArtImageView.layer.cornerRadius = self.albumArtImageView.frame.size.width/25;
    let shadowPath:UIBezierPath = UIBezierPath(rect: self.albumArtImageView.bounds);
    self.albumArtImageView.layer.shadowColor = UIColor.black.cgColor;
    self.albumArtImageView.layer.shadowOffset = CGSize(width: 0, height: 1);
    self.albumArtImageView.layer.shadowOpacity = 0.5;
    self.albumArtImageView.layer.shadowPath = shadowPath.cgPath;
    
    // Setup the blur view
    if (!UIAccessibilityIsReduceTransparencyEnabled() &&  self.view.backgroundColor != UIColor.clear) {
      self.view.backgroundColor = UIColor.clear
      
      // Always fill the view
      self.blurEffectView.frame = self.view.bounds;
      self.blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight];
      self.blurImageView.frame = self.view.bounds;
      self.blurImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight];
      self.blurImageView.contentMode = .scaleAspectFill;
            
      self.view.insertSubview(self.blurEffectView, at: 0);
      self.view.insertSubview(self.blurImageView, belowSubview: self.blurEffectView);
    }
    
    // Update the interface
    self.updateInterface(notification: nil);
    
    // Log
    DispatchQueue.main.async {
      Flurry.logEvent("startedBroadcast", timed: true);
    }
  }
  
  //MARK: - Button Actions
  @IBAction func dismissBroadcastViewController(_ sender: UIButton) {
    //Stop broadcasting & disconnect.
    self.connectivityManager.stopBonjour();
    self.connectivityManager.disconnectSockets();
    
    // Stop playing
    if self.playerManager.isPlaying {
      self.playerManager.pause();
    }
    self.playerManager.loadQueueFromMPMediaItems(mediaItems: nil);
    
    // Dismiss view
    self.navigationController?.popViewController(animated: true);
    
    // Log
    DispatchQueue.main.async {
      Flurry.endTimedEvent("startedBroadcast", withParameters: nil);
    }
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
  @objc func updateInterface(notification: Notification?) {
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
    
    // Background blur/color
    //only apply the blur if the user hasn't disabled transparency effects
    if !UIAccessibilityIsReduceTransparencyEnabled() {
      // Set the background album art
      self.blurImageView.image = artwork;
      
    } else {
      SLColorArt.processImage(self.albumArtImageView.image, scaledTo: self.albumArtImageView.frame.size, threshold: 0.01) { (colorArt) in
        self.view.backgroundColor = colorArt?.primaryColor;
      };
    }
  }
  
  // We prefer a white status bar
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  //MARK: - Communication
  @objc func sendPlayCommand() -> UInt64 {
    print("Sending play command.");
    
    if self.playerManager.currentSong == nil {
      print("Canceled send play, current song was nil: %@", self.playerManager.currentSong as Any);
      return 0;
    }
    
    let playbackTime: TimeInterval = CMTimeGetSeconds(self.playerManager.currentSong!.currentTime());
    let deviceTimeAtPlaybackTime: UInt64 = self.synaction.currentTime();
    let timeToExecute: UInt64 = deviceTimeAtPlaybackTime + 1000000000;
    
    let dictionaryPayload = ["command": "play",
                             "timeToExecute": timeToExecute,
                             "playbackTime": playbackTime,
                             "continuousPlay": self.playerManager.isPlaying,
                             "timeAtPlaybackTime": deviceTimeAtPlaybackTime,
                             "song": self.playerManager.currentSongMetadata?["title"] as Any
      ] as [String : Any];
    
    let payloadData = NSKeyedArchiver.archivedData(withRootObject: dictionaryPayload);
    let packet: Packet = Packet.init(data: payloadData, type: PacketTypeControl, action: PacketActionPlay);
    self.synaction.connectivityManager.send(packet, to: self.connectivityManager.allSockets as! [GCDAsyncSocket]);
    
    return timeToExecute;
  }
  
  @objc func sendPauseCommand() -> UInt64 {
    print("Sending pause command.");
    
    let timeToExecute = self.synaction.currentTime();
    
    let dictionaryPayload = ["command": "pause",
                             "timeToExecute": timeToExecute,
                             "song": (self.playerManager.currentSongMetadata?["title"] ?? "")!
      ] as [String : Any];
    
    let payloadData = NSKeyedArchiver.archivedData(withRootObject: dictionaryPayload);
    let packet: Packet = Packet.init(data: payloadData, type: PacketTypeControl, action: PacketActionPlay);
    self.synaction.connectivityManager.send(packet, to: self.connectivityManager.allSockets as! [GCDAsyncSocket]);
    
    print("Asking peers to calibrate after pause");
    self.synaction.askPeers(toCalculateOffset: self.connectivityManager.allSockets as! [GCDAsyncSocket]);
    
    return timeToExecute;
  }
  
	@objc func sendCurrentSong(notification: Notification?) {
    print("Sending pause command from current song.");
    
    // Pause command
    let _ = self.sendPauseCommand();
    
    // Get the path for the song
    let tempPath: URL = NSURL.fileURL(withPath: NSTemporaryDirectory());
    let songURL: URL = tempPath.appendingPathComponent("song.caf", isDirectory: false);
    
    // Delete old song
    do {
      try FileManager.default.removeItem(at: songURL);
      
    } catch {
      print("Failed to delete old song for export. Error: \(error)");
    }
    
    // If no new song return.
    if (self.playerManager.currentSong == nil) {
      return;
    }
    
    // Export the current song to a file and send the file to the peer
    let currentSongAsset: AVAsset = self.playerManager.currentSong!.asset;
    let exporter: AVAssetExportSession = AVAssetExportSession.init(asset: currentSongAsset, presetName: AVAssetExportPresetPassthrough)!;
    exporter.outputFileType = "com.apple.coreaudio-format";
    exporter.outputURL = songURL;
    
    print("Exporting current song host");
    
    exporter.exportAsynchronously {
      // Send the file
      do {
        let fileData = try Data.init(contentsOf: exporter.outputURL!);
        
        var metadataA: [String: Any?]? = self.playerManager.currentSongMetadata;
        if let metadataB = metadataA {
          metadataA!["artwork"] = (metadataB["artwork"] as! MPMediaItemArtwork).image(at: self.albumArtImageView.frame.size);
        }
        
        print("Sending current song.");
        
        let payloadDict: [String : Any] = ["command": "load", "index": "0", "file": fileData, "metadata": (metadataA ?? ["empty": true])]  as [String : Any];
        let packet: Packet = Packet.init(data: NSKeyedArchiver.archivedData(withRootObject: payloadDict), type: PacketTypeFile, action: PacketActionUnknown);
        self.connectivityManager.send(packet, to: self.connectivityManager.allSockets as! [GCDAsyncSocket]);
				
				// Update the player with our current state
				if self.playerManager.isPlaying {// Pause was sent previously
					print("Sending play after sending current song in function");
					let _ = self.sendPlayCommand();
				}
				
      } catch {
        print("failed to get data of file on host");
      }
    }
  }
  
  func socket(_ socket: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
    // Update UI
    self.numberOfClientsLabel.text = (self.connectivityManager.allSockets.count == 1) ? "to 1 person" : "to \(self.connectivityManager.allSockets.count) people";
    
    print("Socket connected, asking to calibrate");
    self.synaction.askPeers(toCalculateOffset: [newSocket] );
    self.synaction.executeBlock(whenEachPeerCalibrates: [newSocket] ) { (peers) in
      print("Peer calibrated, sending current song.");
      
			self.sendCurrentSong(notification: nil);// It will handle sending player state
    };
  }
  
  func socketDidDisconnect(_ socket: GCDAsyncSocket, withError error: Error) {
    // Update UI
    self.numberOfClientsLabel.text = "to \(self.connectivityManager.allSockets.count) people";
  }
}
