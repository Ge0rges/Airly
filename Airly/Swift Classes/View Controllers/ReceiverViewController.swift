//
//  ReceiverViewController.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import UIKit
import MediaPlayer

class ReceiverViewController: UIViewController, ConnectivityManagerDelegate {
  
  @IBOutlet var backButton: UIButton!
  @IBOutlet var hostLabel: UILabel!
  @IBOutlet var albumArtImageView: UIImageView!
  @IBOutlet var songNameLabel: UILabel!
  @IBOutlet var songArtistLabel: UILabel!
  
  let blurEffectView:UIVisualEffectView! = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark));
  let blurImageView:UIImageView! = UIImageView.init();
  let playerManager:PlayerManager! = PlayerManager.sharedManager;
  let connectivityManager:ConnectivityManager! = ConnectivityManager.shared();
  let synaction:Synaction! = Synaction.sharedManager();
  
  var lastReceivedHostTime: UInt64 = 0;
  var lastReceivedHostPlaybackTime: TimeInterval = 0;
  var lastReceivedTimeToExecute: UInt64 = 0;
  var currentSongMetadata: Dictionary<String, Any?>? = nil;
  var pendingCommand: String? = nil;

  override func viewDidLoad() {
    super.viewDidLoad();
    // Stop browsing for bonjour broadcast.
    self.connectivityManager.stopBonjour();
    
    // Set the delegate
    self.connectivityManager.delegate = self;
    
    // Register for player notifications
    NotificationCenter.default.addObserver(self, selector: #selector(self.updateInterface(notification:)), name: PlayerManager.PlayerSongChangedNotificationName, object: nil);
    NotificationCenter.default.addObserver(self, selector: #selector(self.executePendingCommand), name:NSNotification.Name(rawValue: "CalibrationDone"), object: nil);
    
    // Update the interface
    self.updateInterface(notification: nil);
    
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
    
  }
  
  //MARK: - Button Actions
  @IBAction func dismissBroadcastViewController(_ sender: UIButton) {
    //Stop broadcasting & disconnect.
    self.connectivityManager.stopBonjour();
    self.connectivityManager.disconnectSockets();
    
    //Stop Playing
    self.playerManager.pause();
    self.playerManager.loadQueueFromMPMediaItems(mediaItems: nil);
    
    // Dismiss view
    self.navigationController?.popToRootViewController(animated: true);
  }
  
  // MARK: - UI Functions
  @objc func updateInterface(notification: Notification?) {
    print("Listener updating UI called.");
    
    // Album Art
    let metadata:Dictionary<String, Any?>? = self.currentSongMetadata;
    var artwork: UIImage? = nil;//TODO: Default Image
    var title: String = "Unknown Song Name";
    var artist: String = "Unknown Artist";
    
    if let metadata = metadata {
      print("metadata not nil");
      
      if metadata.index(forKey: "empty") == nil {
        print("Metadata had empty key nil.");
        
        let mediaItemArtwork = metadata["artwork"] as! UIImage?;
        if (mediaItemArtwork != nil) {
          artwork = mediaItemArtwork!
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
    
    // Update host name
    self.hostLabel.text = "from \"\(self.connectivityManager.hostName ?? "host")\"";
  }
  
  // We prefer a white status bar
  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }
  
  //MARK: - Communication
  func didReceive(_ packet: Packet, from socket: GCDAsyncSocket) {
    let payloadDict: Dictionary<String,Any?> = NSKeyedUnarchiver.unarchiveObject(with: packet.data as! Data) as! Dictionary;
    let command: String! = payloadDict["command"] as! String;
    
    if  (command == "play") {// Play command
      print("Received play command.");
      
      // Save the values for next play
      lastReceivedHostTime = (payloadDict["timeAtPlaybackTime"] as! UInt64);
      lastReceivedHostPlaybackTime = (payloadDict["playbackTime"] as! TimeInterval);
      
      if ((payloadDict["song"] as? String) != self.songNameLabel.text || self.synaction.isCalibrating) {
        print("Pending command is play command.");
        
        self.pendingCommand = "play";
        return;
      }
      
      self.pendingCommand = nil;
      let continuousPlay: Bool = payloadDict["continuousPlay"] as! Bool;
      
      if continuousPlay {// Host is playing
        print("Executing play as continuous command.");
        
        self.playerManager.play();// Play locally
        
        // Seek to adjusted song time
        self.playerManager.seekToTimeInSeconds(time: self.adjustedSongTimeForHost(), completionHandler: { (success) in
          if !success {
            print("Failed to seek for continuous play.");
          }
        });
        
      } else {// Play in sync
        print("Executing play as start-stop command.");
        
        let timeToExecute: UInt64 = (payloadDict["timeToExecute"] as! UInt64);// Get the time to execute
        
        // Play at exact time
        self.synaction.atExactTime(timeToExecute, run: {
          self.playerManager.play();
        });
        
        // Seek to the playback time
        let playbackTime: TimeInterval = (payloadDict["playbackTime"] as! TimeInterval);
        self.playerManager.seekToTimeInSeconds(time: playbackTime, completionHandler: { (success) in
          if !success {
            print("Failed to seek for sync play.");
          }
        })
      }
      
    } else if (command == "pause") {
      print("Received pause command.");
      
      if self.synaction.isCalibrating {
        self.pendingCommand = "pause";
        lastReceivedTimeToExecute = (payloadDict["timeToExecute"] as! UInt64);
      }
      
      self.pendingCommand = nil;
      let timeToExecute: UInt64 = (payloadDict["timeToExecute"] as! UInt64);
      
      self.synaction.atExactTime(timeToExecute, run: {
        self.playerManager.pause();
      });
      
    } else if (command == "load") {
      print("Received load command.");
      
      self.currentSongMetadata = payloadDict["metadata"] as! Dictionary<String, Any?>?;
      self.updateInterface(notification: nil);
      
      let songPath: URL = NSURL.fileURL(withPath: NSTemporaryDirectory()).appendingPathComponent("song.caf", isDirectory: false);
      let fileData: Data = payloadDict["file"] as! Data;
      
      do {
        try FileManager.default.removeItem(at: songPath);
      } catch {
        print("Error deleting old song: \(error)");
      }
      
      do {
        try fileData.write(to: songPath);
        
        let asset: AVAsset = AVAsset(url: songPath);
        
        let playerItem: AVPlayerItem = AVPlayerItem.init(asset: asset);
        self.playerManager.loadSongFromPlayerItem(playerItem: playerItem);
        
        self.executePendingCommand();
        
      } catch {
        print("Error writing song data to file: \(error)");
      }
    }
  }

  @objc func executePendingCommand() {
    if (self.pendingCommand == "play") {
      print("Executing play as pending command.");
      
      self.playerManager.play();// Play locally
      
      // Seek to adjusted song time
      self.playerManager.seekToTimeInSeconds(time: self.adjustedSongTimeForHost(), completionHandler: { (success) in
        if !success {
          print("Failed to seek for continuous play.");
        }
      });
      
    } else if self.pendingCommand == "pause" {
      self.synaction.atExactTime(lastReceivedTimeToExecute, run: {
        self.playerManager.pause();
      });
      
    } else {
      print("Couldn't handle pending command: \(String(describing: self.pendingCommand))");
    }
    
    self.pendingCommand = nil;
  }

  func socketDidDisconnect(_ socket: GCDAsyncSocket, withError error: Error) {
    self.dismissBroadcastViewController(self.backButton);
  }
  
  func adjustedSongTimeForHost() -> TimeInterval {
    let currentNetworkTime = self.synaction.currentNetworkTime()
    let timePassedBetweenSent = currentNetworkTime.subtractingReportingOverflow(lastReceivedHostTime);
    
    print("timePassedBetweenSent overflowed: \(timePassedBetweenSent.overflow)");
    
    let timeToForwardSong: TimeInterval = Double.init(exactly: timePassedBetweenSent.partialValue)!/1000000000.0// Convert to seconds
    let adjustedSongTime: TimeInterval = lastReceivedHostPlaybackTime + timeToForwardSong;// Adjust song time
    
    return adjustedSongTime
  }
}
