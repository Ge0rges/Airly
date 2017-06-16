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

  override func viewDidLoad() {
    super.viewDidLoad();
    // Start browsing for bonjour broadcast.
    self.connectivityManager.startBrowsingForBonjourBroadcast();
    
    // Register for player notifications
    NotificationCenter.default.addObserver(self, selector: #selector(self.updateInterface(notification:)), name: PlayerManager.PlayerSongChangedNotificationName, object: nil);
    
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
    self.navigationController?.popViewController(animated: true);
  }
  
  // MARK: - UI Functions
  @objc func updateInterface(notification: Notification?) {
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
  func didReceive(_ packet: Packet, from socket: GCDAsyncSocket) {
    let payloadDict: Dictionary<String,Any?> = NSKeyedUnarchiver.unarchiveObject(with: packet.data as! Data) as! Dictionary;
    let command: String! = payloadDict["command"] as! String;
    
    if  (command == "play") {// Play command
      let continuousPlay: Bool = payloadDict["continuousPlay"] as! Bool;
      
      if continuousPlay {// Host is playing
        // Calculate time passed on host
        let timePassedBetweenSent: UInt64 = self.synaction.currentNetworkTime() - (payloadDict["timeAtPlaybackTime"] as! UInt64);
        let timeToForwardSong:TimeInterval = Double(timePassedBetweenSent)/1000000000.0// Convert to seconds
        
        let adjustedSongTime: TimeInterval = (payloadDict["playbackTime"] as! TimeInterval) + timeToForwardSong;// Adjust song time
        self.playerManager.play();// Play locally
        
        // Seek to adjusted song time
        self.playerManager.seekToTimeInSeconds(time: adjustedSongTime, completionHandler: { (success) in
          if !success {
            print("Failed to seek for continuous play.");
          }
        });
        
      } else {// Play in sync
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
      let timeToExecute: UInt64 = (payloadDict["timeToExecute"] as! UInt64);
      
      self.synaction.atExactTime(timeToExecute, run: {
        self.playerManager.pause();
      });
      
    } else if (command == "load") {
      let songPath: URL = NSURL.fileURL(withPath: NSTemporaryDirectory()).appendingPathComponent("song.caf", isDirectory: false);
      
      let fileData: Data = payloadDict["file"] as! Data;
      FileManager.default.createFile(atPath: songPath.absoluteString, contents: fileData, attributes: nil);
      
      let playerItem: AVPlayerItem = AVPlayerItem.init(url: songPath);
      self.playerManager.loadSongFromPlayerItem(playerItem: playerItem);
    }
  }
  
  func socket(_ socket: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
    self.hostLabel.text = "from \"\(host)\"";
  }
}
