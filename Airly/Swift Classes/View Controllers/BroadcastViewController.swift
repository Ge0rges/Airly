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
	
	let blurEffectView:UIVisualEffectView! = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark));
	let blurImageView:UIImageView! = UIImageView.init();
	let mediaPicker:MPMediaPickerController! = MPMediaPickerController(mediaTypes: .music);
	let playerManager:PlayerManager! = PlayerManager.sharedManager;
	let connectivityManager:ConnectivityManager! = ConnectivityManager.shared();
	let syncManager: HostSyncManager! = HostSyncManager.sharedManager;
	
	override func viewDidLoad() {
		super.viewDidLoad();
		// Set the sync manager
		self.syncManager.broadcastViewController = self;
		
		// Start broadcasting bonjour.
		self.connectivityManager.startBonjourBroadcast();
				
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
	
	@IBAction func addMusicButtonPressed(_ sender: Any?) {
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
		var artwork: UIImage? = #imageLiteral(resourceName: "Default Music");// Default Image
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
}
