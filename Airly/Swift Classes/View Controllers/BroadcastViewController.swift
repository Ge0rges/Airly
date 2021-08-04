//
//  BroadcastViewController.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//
// This controller is responsible for maintaining the interface and toggling bonjour broadcasting.

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
    
    private let blurEffectView:UIVisualEffectView! = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    private let blurImageView:UIImageView! = UIImageView.init()
    private let connectivityManager:ConnectivityManager! = ConnectivityManager.shared()
    private let syncManager: HostSyncManager! = HostSyncManager.sharedManager

    private var mediaPicker: MPMediaPickerController? = nil
    private var timeAtInterruption: UInt64 = 0
    private var playbackPositionAtInterruption: TimeInterval = 0
    private var shouldResumePlayAfterInterruption: Bool = false
    private var spotifySelected: Bool? = nil
    
    public var playerManager: PlayerManager?  = nil

    
    //MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // Set the sync manager
        self.syncManager.broadcastViewController = self
        
        // Start broadcasting bonjour.
        self.connectivityManager.startBonjourBroadcast()
        
        // Create & configure the media picker
        self.mediaPicker = MPMediaPickerController(mediaTypes: .music)
        self.mediaPicker!.delegate = self
        self.mediaPicker!.showsCloudItems = false
        self.mediaPicker!.showsItemsWithProtectedAssets = false
        self.mediaPicker!.allowsPickingMultipleItems = true
        self.mediaPicker!.prompt = "Only music you own is playable."
        
        // Register for player notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateInterface(notification:)), name: PlayerSongChangedNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateInterface(notification:)), name: PlayerPlayedNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateInterface(notification:)), name: PlayerPausedNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleInterruption(notification:)), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        //NotificationCenter.default.addObserver(self, selector: #selector(self.handleActivated(notification:)), name:AppDelegate.AppDelegateDidBecomeActive, object: nil)
        //NotificationCenter.default.addObserver(self, selector: #selector(self.handleBackgrounded(notification:)), name:AppDelegate.AppDelegateDidBackground, object: nil)
        
        
        // Round & Shadow the album art
        self.albumArtImageView.layer.cornerRadius = self.albumArtImageView.frame.size.width/25
        let shadowPath:UIBezierPath = UIBezierPath(rect: self.albumArtImageView.bounds)
        self.albumArtImageView.layer.shadowColor = UIColor.black.cgColor
        self.albumArtImageView.layer.shadowOffset = CGSize(width: 0, height: 1)
        self.albumArtImageView.layer.shadowOpacity = 0.5
        self.albumArtImageView.layer.shadowPath = shadowPath.cgPath
        
        // Setup the blur view
        if (!UIAccessibility.isReduceTransparencyEnabled &&  self.view.backgroundColor != UIColor.clear) {
            self.view.backgroundColor = UIColor.clear
            
            // Always fill the view
            self.blurEffectView.frame = self.view.frame
            self.blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.blurImageView.frame = self.view.frame
            self.blurImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.blurImageView.contentMode = .scaleAspectFill
            self.blurImageView.clipsToBounds = true
            
            self.view.insertSubview(self.blurEffectView, at: 0)
            self.view.insertSubview(self.blurImageView, at: 0)
        }
        
        // Hide UI controls
        self.playbackButton.isHidden = true
        self.backwardPlaybackButton.isHidden = true
        self.forwardPlaybackButton.isHidden = true
        
        // Update the interface
        self.updateInterface(notification: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.addMusicButtonPressed(nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if self.isMovingFromParent {
            self.dismissBroadcastViewController(nil)
        }
    }
    
    //MARK: - Button Actions
    @IBAction func dismissBroadcastViewController(_ sender: UIButton?) {
        //Stop broadcasting & disconnect.
        self.connectivityManager.stopBonjour()
        self.connectivityManager.disconnectSockets()
        
        // Stop playing
        self.playerManager?.isPlaying(completion: { isPlaying in
            if isPlaying {
                self.playerManager?.pause(completion: { _ in})
            }
        })
        
        self.playerManager?.loadQueueFromItems(songItems: [])
        
        // Dismiss view
        if !self.isMovingFromParent {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func addMusicButtonPressed(_ sender: Any?) {
        if (self.spotifySelected ?? false) {
            self.openSpotifyMusicPicker()
            
        } else if (self.spotifySelected == nil) {
            // Ask whether we'll be using Spotify or Apple Music
            let musicSourceController = UIAlertController(title: "Apple Music or Spotify?", message: "From which service would you like to source your music? Please note that if spotify is selected, all listeners must have a valid spotify account.", preferredStyle: .actionSheet)
            
            // Apple Music
            let appleMusicAction = UIAlertAction(title: "Apple Music", style: UIAlertAction.Style.default) {_ in
                self.openAppleMusicPicker()
                self.spotifySelected = false
            }
            
            // Spotify
            let spotifyAction = UIAlertAction(title: "Spotify", style: UIAlertAction.Style.default) {UIAlertAction in
                self.openSpotifyMusicPicker()
                self.spotifySelected = true
            }
            
            // Add the actions
            musicSourceController.addAction(appleMusicAction)
            musicSourceController.addAction(spotifyAction)
            
            // Present the controller
            self.present(musicSourceController, animated: true, completion: nil)
            
        } else {
            self.openAppleMusicPicker()
        }
    }
    
    func openSpotifyMusicPicker () {
        self.playerManager = SpotifyPlayerManager.sharedManager
        
        if self.addMusicButton.title(for: UIControl.State.normal) == "Open Spotify" {
            UIApplication.shared.open(URL(string: "spotify:")!)

        } else {
            self.playerManager?.authorize(completion: { _ in
                self.playerManager?.currentSong(completion: { songItem in
                    self.updateInterface(notification: nil)
                    self.syncManager.sendCurrentSong(notification: nil)
                })
            })
            
            self.addMusicButton.setTitle("Open Spotify", for: UIControl.State.normal)
            self.addMusicButton.setTitle("Open Spotify", for: UIControl.State.selected)
        }
    }
    
    func openAppleMusicPicker() {
        // Show UI controls
        self.playbackButton.isHidden = false
        self.backwardPlaybackButton.isHidden = false
        self.forwardPlaybackButton.isHidden = false
        
        self.playerManager = ApplePlayerManager.sharedManager

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
        self.playerManager?.authorize(completion: { result in
            DispatchQueue.main.async {// Main Queue
                // Present Media Picker
                self.present(self.mediaPicker!, animated: true, completion: nil)
            }
        })
    }
    
    //MARK: Playback Controls
    @IBAction func backwardPlaybackButtonPressed(_ sender: UIButton) {
        // Rewind to previous song
        self.playerManager?.playPreviousSong(completion: { _ in})
    }
    
    @IBAction func togglePlaybackButtonPressed(_ sender: UIButton) {
        self.playerManager?.isPlaying(completion: { isPlaying in
            if isPlaying {// If playing
                // Pause and Update UI
                self.playerManager?.pause(completion: { _ in})
                self.playbackButton.setImage(#imageLiteral(resourceName: "Play"), for: .normal)
                
            } else {
                // Play and Update UI
                self.playerManager?.play(completion: { _ in})
                self.playbackButton.setImage(#imageLiteral(resourceName: "Pause"), for: .normal)
            }
        })
    }
    
    @IBAction func forwardPlaybackButtonPressed(_ sender: UIButton) {
        // Skip to next song
        self.playerManager!.playNextSong(completion: { _ in})
    }
    
    //MARK: - MPMediaPickerConrollerDelegate
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        // Tell the player to load the items
        var songItems: [SongItem] = []
        for item in mediaItemCollection.items {
            let song: SongItem = SongItem()
            song.artist = item.artist
            song.image = item.artwork?.image(at: CGSize(width: 1024, height: 1024))
            song.path = nil
            song.title = item.title
            
            let mediaItemURL:URL = item.value(forProperty: MPMediaItemPropertyAssetURL) as! URL;
            let playerItem: AVPlayerItem = AVPlayerItem(asset: AVAsset(url: mediaItemURL));
            song.avItem = playerItem

            
            songItems.append(song)
        }
        
        self.playerManager!.loadQueueFromItems(songItems: songItems)
        
        DispatchQueue.main.async {// Main Queue
            // Dismiss Media Picker
            self.dismiss(animated: true, completion: {
                self.mediaPicker = nil
                
                // Create & configure the media picker
                self.mediaPicker = MPMediaPickerController(mediaTypes: .music)
                self.mediaPicker!.delegate = self
                self.mediaPicker!.showsCloudItems = false
                self.mediaPicker!.showsItemsWithProtectedAssets = false
                self.mediaPicker!.allowsPickingMultipleItems = true
                self.mediaPicker!.prompt = "Only music you own is playable."
            })
        }
    }
    
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        DispatchQueue.main.async {// Main Queue
            // Dismiss Media Picker
            self.dismiss(animated: true, completion: {
                self.mediaPicker = nil
                
                // Create & configure the media picker
                self.mediaPicker = MPMediaPickerController(mediaTypes: .music)
                self.mediaPicker!.delegate = self
                self.mediaPicker!.showsCloudItems = false
                self.mediaPicker!.showsItemsWithProtectedAssets = false
                self.mediaPicker!.allowsPickingMultipleItems = true
                self.mediaPicker!.prompt = "Only music you own is playable."
            })
        }
    }
    
    // MARK: - UI Functions
    @objc func updateInterface(notification: Notification?) {
        // Default view
        if self.playerManager == nil {
            self.songNameLabel.text = "Pick a Song"
            self.songArtistLabel.text = ""
            self.albumArtImageView.image = UIImage(named:"Default Music")
            
            self.playbackButton.isEnabled = false
            self.backwardPlaybackButton.isEnabled = false
            self.forwardPlaybackButton.isEnabled = false

            return
        }
        
        // Forward and Rewind buttons
        self.playerManager?.canSkipToNextSong(completion: { canSkipToNextSong in
            self.forwardPlaybackButton.isEnabled = (canSkipToNextSong)
        })
        self.playerManager?.canSkipToPreviousSong(completion: { canSkipToPreviousSong in
            self.backwardPlaybackButton.isEnabled = (canSkipToPreviousSong)
        })
        
        // Toggle Playback button
        self.playerManager?.isPlaying(completion: { isPlaying in
            let playbackImage = (isPlaying) ? #imageLiteral(resourceName: "Pause") : #imageLiteral(resourceName: "Play")
            self.playbackButton.setImage(playbackImage, for: .normal)
        })
        
        self.playerManager?.currentSong(completion: { songItem in
            self.playbackButton.isEnabled = (songItem != nil)
            
            self.albumArtImageView.image = songItem?.image ?? UIImage(named:"Default Music")
            self.songNameLabel.text = songItem?.title ?? "Unknown Title"
            self.songArtistLabel.text = songItem?.artist ?? "Unknown Artist"
            
            // Background blur/color - Only apply the blur if the user hasn't disabled transparency effects
            if !UIAccessibility.isReduceTransparencyEnabled {
                // Set the background album art
                self.blurImageView.image = songItem?.image
                
            } else {
                SLColorArt.processImage(self.albumArtImageView.image, scaledTo: self.albumArtImageView.frame.size, threshold: 0.01) { (colorArt) in
                    self.view.backgroundColor = colorArt?.primaryColor
                }
            }
        })
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
            self.handleBackgrounded(notification: nil)
            
        } else if type == .ended {
            guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                self.handleActivated(notification: nil)
            }
        }
    }
    
    public func handleBackgrounded(notification: Notification?) {
//        // Pause playback, save the time so we can resume later
//        if !self.playerManager?.isSpotify {
//            shouldResumePlayAfterInterruption = false
//
//            self.playerManager!.isPlaying (completion: { [self] isPlaying in
//                if isPlaying {
//                    self.playerManager?.pause(completion: { _ in})
//
//                    if self.connectivityManager.allSockets.count > 0 {// Peers connected we'll have to catch up to them
//                        self.shouldResumePlayAfterInterruption = true
//                        self.timeAtInterruption = self.syncManager.synaction.currentTime()
//
//                        self.playerManager?.currentPlaybackTime(completion: { time in
//                            self.playbackPositionAtInterruption = time
//                        })
//                    }
//                }
//            })
//        }
    }
    
    public func handleActivated(notification: Notification?) {
//        // Resume playback
//        if self.shouldResumePlayAfterInterruption {
//            let timePassedBetweenInterruption: UInt64 = self.syncManager.synaction.currentTime() - timeAtInterruption
//            let timeToForwardSong: TimeInterval = Double.init(exactly: timePassedBetweenInterruption)!/1000000000.0// Convert to seconds
//            let adjustedSongTime: TimeInterval = playbackPositionAtInterruption + timeToForwardSong + self.playerManager.outputLatency// Adjust song time
//
//            BASS_ChannelPlay(self.playerManager.channel, false)
//            self.playerManager.seekToTimeInSeconds(time: adjustedSongTime) { (success) in
//                print("Failed to seek for host interruption play.")
//            }
//        }
    }
}
