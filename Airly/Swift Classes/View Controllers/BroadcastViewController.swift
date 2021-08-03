//
//  BroadcastViewController.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import UIKit
import MediaPlayer
import StoreKit

class BroadcastViewController: UIViewController, MPMediaPickerControllerDelegate, SKCloudServiceSetupViewControllerDelegate {
    
    @IBOutlet var backButton: UIButton!
    @IBOutlet public var numberOfClientsLabel: UILabel!
    @IBOutlet var addMusicButton: UIButton!
    @IBOutlet public var albumArtImageView: UIImageView!
    @IBOutlet var songNameLabel: UILabel!
    @IBOutlet var songArtistLabel: UILabel!
    @IBOutlet var backwardPlaybackButton: UIButton!
    @IBOutlet var playbackButton: UIButton!
    @IBOutlet var forwardPlaybackButton: UIButton!
    
    private let blurEffectView:UIVisualEffectView! = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark));
    private let blurImageView:UIImageView! = UIImageView.init();
    private let playerManager:PlayerManager! = PlayerManager.sharedManager;
    private let connectivityManager:ConnectivityManager! = ConnectivityManager.shared();
    private let syncManager: HostSyncManager! = HostSyncManager.sharedManager;

    private var mediaPicker: MPMediaPickerController? = nil;
    private var timeAtInterruption: UInt64 = 0;
    private var playbackPositionAtInterruption: TimeInterval = 0;
    private var shouldResumePlayAfterInterruption: Bool = false;
    

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private let appRemote = (UIApplication.shared.delegate as! AppDelegate).appRemote
    
    //MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad();
                
        // Set the sync manager
        self.syncManager.broadcastViewController = self;
        
        // Start broadcasting bonjour.
        self.connectivityManager.startBonjourBroadcast();
        
        // Create & configure the media picker
        self.mediaPicker = MPMediaPickerController(mediaTypes: .music);
        self.mediaPicker!.delegate = self;
        self.mediaPicker!.showsCloudItems = false;
        self.mediaPicker!.showsItemsWithProtectedAssets = false;
        self.mediaPicker!.allowsPickingMultipleItems = true;
        self.mediaPicker!.prompt = "Only music you own is playable.";
        
        // Register for player notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateInterface(notification:)), name: PlayerManager.PlayerSongChangedNotificationName, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateInterface(notification:)), name: PlayerManager.PlayerPlayedNotificationName, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateInterface(notification:)), name: PlayerManager.PlayerPausedNotificationName, object: nil);
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleInterruption(notification:)), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance());
        //NotificationCenter.default.addObserver(self, selector: #selector(self.handleActivated(notification:)), name:AppDelegate.AppDelegateDidBecomeActive, object: nil);
        //NotificationCenter.default.addObserver(self, selector: #selector(self.handleBackgrounded(notification:)), name:AppDelegate.AppDelegateDidBackground, object: nil);
        
        
        // Round & Shadow the album art
        self.albumArtImageView.layer.cornerRadius = self.albumArtImageView.frame.size.width/25;
        let shadowPath:UIBezierPath = UIBezierPath(rect: self.albumArtImageView.bounds);
        self.albumArtImageView.layer.shadowColor = UIColor.black.cgColor;
        self.albumArtImageView.layer.shadowOffset = CGSize(width: 0, height: 1);
        self.albumArtImageView.layer.shadowOpacity = 0.5;
        self.albumArtImageView.layer.shadowPath = shadowPath.cgPath;
        
        // Setup the blur view
        if (!UIAccessibility.isReduceTransparencyEnabled &&  self.view.backgroundColor != UIColor.clear) {
            self.view.backgroundColor = UIColor.clear
            
            // Always fill the view
            self.blurEffectView.frame = self.view.frame;
            self.blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight];
            self.blurImageView.frame = self.view.frame;
            self.blurImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight];
            self.blurImageView.contentMode = .scaleAspectFill;
            self.blurImageView.clipsToBounds = true;
            
            self.view.insertSubview(self.blurEffectView, at: 0);
            self.view.insertSubview(self.blurImageView, at: 0);
        }
        
        // Update the interface
        self.updateInterface(notification: nil);
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated);
        
        if self.isMovingFromParent {
            self.dismissBroadcastViewController(nil);
        }
    }
    
    //MARK: - Button Actions
    @IBAction func dismissBroadcastViewController(_ sender: UIButton?) {
        //Stop broadcasting & disconnect.
        self.connectivityManager.stopBonjour();
        self.connectivityManager.disconnectSockets();
        
        // Stop playing
        if self.playerManager.isPlaying {
            self.playerManager.pause();
        }
        self.playerManager.loadQueueFromMPMediaItems(mediaItems: nil);
        
        // Dismiss view
        if !self.isMovingFromParent {
            self.navigationController?.popViewController(animated: true);
        }
    }
    
    @IBAction func addMusicButtonPressed(_ sender: Any?) {
        // Ask whether we'll be using Spotify or Apple Music
        let musicSourceController = UIAlertController(title: "Apple Music or Spotify?", message: "From which service would you like to source your music? Please note that if spotify is selected, all listeners must have a valid spotify account.", preferredStyle: .alert)
        
        // Apple Music
        let appleMusicAction = UIAlertAction(title: "Apple Music", style: UIAlertAction.Style.default) {_ in
            
            // Check that the music app is installed
            if !UIApplication.shared.canOpenURL(URL(string: "music://")!) {
                let dialogMessage = UIAlertController(title: "Music not Installed", message: "Airly requires the Apple Music app to be installed on this device. Airly retrieves your songs from the Apple Music app's library. At this timen other music service is supported.", preferredStyle: .alert)
                
                let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil)
                dialogMessage.addAction(okAction)
                
                // Present alert to user
                self.present(dialogMessage, animated: true, completion: nil)
                
                return
            }
            
            // Request authentication to music library
            MPMediaLibrary.requestAuthorization { (authorizationStatus) in
                DispatchQueue.main.async {// Main Queue
                    // Present Media Picker
                    self.present(self.mediaPicker!, animated: true, completion: nil);
                }
            }
        }
        
        // Spotify
        let spotifyAction = UIAlertAction(title: "Spotify", style: UIAlertAction.Style.cancel) {UIAlertAction in
            self.appRemote.authorizeAndPlayURI("")
        }
        
        // Add the actions
        musicSourceController.addAction(appleMusicAction)
        musicSourceController.addAction(spotifyAction)
        
        // Present the controller
        self.present(musicSourceController, animated: true, completion: nil)
        
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
            self.dismiss(animated: true, completion: {
                self.mediaPicker = nil;
                
                // Create & configure the media picker
                self.mediaPicker = MPMediaPickerController(mediaTypes: .music);
                self.mediaPicker!.delegate = self;
                self.mediaPicker!.showsCloudItems = false;
                self.mediaPicker!.showsItemsWithProtectedAssets = false;
                self.mediaPicker!.allowsPickingMultipleItems = true;
                self.mediaPicker!.prompt = "Only music you own is playable.";
            });
        };
    }
    
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        DispatchQueue.main.async {// Main Queue
            // Dismiss Media Picker
            self.dismiss(animated: true, completion: {
                self.mediaPicker = nil;
                
                // Create & configure the media picker
                self.mediaPicker = MPMediaPickerController(mediaTypes: .music);
                self.mediaPicker!.delegate = self;
                self.mediaPicker!.showsCloudItems = false;
                self.mediaPicker!.showsItemsWithProtectedAssets = false;
                self.mediaPicker!.allowsPickingMultipleItems = true;
                self.mediaPicker!.prompt = "Only music you own is playable.";
            });
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
        var artwork: UIImage? = #imageLiteral(resourceName: "Default Music");// Default Image
        var title: String = (self.playerManager.currentSong != nil) ? "Unknown Title" : "Pick a Song";
        var artist: String = (self.playerManager.currentSong != nil) ? "Unknown Artist" : "" ;
        
        if let _ = metadata {
            if let mediaItemArtwork = metadata!["artwork"] as? MPMediaItemArtwork {
                artwork = mediaItemArtwork.image(at: self.albumArtImageView.frame.size);
                
            } else if let mediaItemArtwork = metadata!["artwork"] as? UIImage {
                artwork = mediaItemArtwork;
            }
            
            let mediaItemArtist = metadata!["artist"] as! String?;
            if (mediaItemArtist != nil) {
                artist = mediaItemArtist!;
            }
            
            let mediaItemTitle = metadata!["title"] as! String?;
            if (mediaItemTitle != nil) {
                title = mediaItemTitle!;
            }
        }
        
        self.albumArtImageView.image = artwork;
        self.songNameLabel.text = title;
        self.songArtistLabel.text = artist;
        
        // Background blur/color
        //only apply the blur if the user hasn't disabled transparency effects
        if !UIAccessibility.isReduceTransparencyEnabled {
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
    
    
    //MARK: - Background
    @objc func handleInterruption(notification: NSNotification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            self.handleBackgrounded(notification: nil);
            
        } else if type == .ended {
            guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                self.handleActivated(notification: nil);
            }
        }
    }
    
    public func handleBackgrounded(notification: Notification?) {
        // Pause playback, save the time so we can resume later
        shouldResumePlayAfterInterruption = false;
        if self.playerManager.isPlaying {
            BASS_ChannelPause(self.playerManager.channel);
            
            if self.connectivityManager.allSockets.count > 0 {// Peers connected we'll have to catch up to them
                shouldResumePlayAfterInterruption = true;
                timeAtInterruption = self.syncManager.synaction.currentTime();
                playbackPositionAtInterruption = self.playerManager.currentPlaybackTime;
            }
        }
    }
    
    public func handleActivated(notification: Notification?) {
        // Resume playback
        if self.shouldResumePlayAfterInterruption {
            let timePassedBetweenInterruption: UInt64 = self.syncManager.synaction.currentTime() - timeAtInterruption;
            let timeToForwardSong: TimeInterval = Double.init(exactly: timePassedBetweenInterruption)!/1000000000.0// Convert to seconds
            let adjustedSongTime: TimeInterval = playbackPositionAtInterruption + timeToForwardSong + self.playerManager.outputLatency;// Adjust song time
            
            BASS_ChannelPlay(self.playerManager.channel, false);
            self.playerManager.seekToTimeInSeconds(time: adjustedSongTime) { (success) in
                print("Failed to seek for host interruption play.");
            }
        }
    }
}
