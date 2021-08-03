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
	
	let blurEffectView:UIVisualEffectView! = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark));
	let blurImageView:UIImageView! = UIImageView.init();
	let playerManager:PlayerManager! = PlayerManager.sharedManager;
	let connectivityManager:ConnectivityManager! = ConnectivityManager.shared();
	let synaction:Synaction! = Synaction.sharedManager();
	
	var lastReceivedHostPlaybackTime: UInt64 = 0;
	var lastReceivedHostSongPlaybackTime: TimeInterval = 0;
	var lastReceivedTimeToExecute: UInt64 = 0;
	var currentSongMetadata: Dictionary<String, Any?>? = nil;
	
	override func viewDidLoad() {
		super.viewDidLoad();
		// Stop browsing for bonjour broadcast.
		self.connectivityManager.stopBonjour();
		
		// Set the delegate
		self.connectivityManager.delegate = self;
		
		// Register for player notifications
		NotificationCenter.default.addObserver(self, selector: #selector(self.updateInterface(notification:)), name: PlayerManager.PlayerSongChangedNotificationName, object: nil);
		NotificationCenter.default.addObserver(self, selector: #selector(self.requestHostState(notification:)), name:NSNotification.Name(rawValue: CalibrationDoneNotificationName), object: nil);
		NotificationCenter.default.addObserver(self, selector: #selector(self.requestHostState(notification:)), name:AppDelegate.AppDelegateDidBecomeActive, object: nil);
		
		// Request the initial host state
		self.requestHostState(notification:  nil);
		
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
		if (!UIAccessibility.isReduceTransparencyEnabled &&  self.view.backgroundColor != UIColor.clear) {
			self.view.backgroundColor = UIColor.clear
			
			// Always fill the view
			self.blurEffectView.frame = self.view.bounds;
			self.blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight];
			self.blurImageView.frame = self.view.bounds;
			self.blurImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight];
			self.blurImageView.clipsToBounds = true;
			
			self.view.insertSubview(self.blurEffectView, at: 0);
			self.view.insertSubview(self.blurImageView, at: 0);
		}
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated);
		
		if self.isMovingFromParent {
			self.dismissReceiverViewController(nil);
		}
	}
	
	//MARK: - Button Actions
	@IBAction func dismissReceiverViewController(_ sender: UIButton?) {
		//Stop broadcasting & disconnect.
		self.connectivityManager.stopBonjour();
		self.connectivityManager.disconnectSockets();
		
		//Stop Playing
		self.playerManager.pause();
		self.playerManager.loadQueueFromMPMediaItems(mediaItems: nil);
		
		// Dismiss view modally
		self.navigationController?.popToRootViewController(animated: true)
		self.dismiss(animated: true, completion: nil)
		
		NotificationCenter.default.removeObserver(self);		
	}
	
	// MARK: - UI Functions
    @objc func updateInterface(notification: Notification?) {
		print("Listener updating UI");
		
		// Album Art
		let metadata:Dictionary<String, Any?>? = self.currentSongMetadata;
		var artwork: UIImage? = #imageLiteral(resourceName: "Default Music");// Default Image
		var title: String = "Unknown Title";
		var artist: String = "Unknown Artist";
		
		if let metadata = metadata {
			print("metadata not nil");
			
			if metadata.index(forKey: "empty") == nil {
				print("Metadata is not empty.");
				
				if let mediaItemArtwork = metadata["artwork"] as? UIImage {
					artwork = mediaItemArtwork;
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
		if !UIAccessibility.isReduceTransparencyEnabled {
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
        let payloadDict: Dictionary<String,Any?> = try! NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(packet.data!) as! Dictionary;
		let command: String! = payloadDict["command"] as? String;
		
		print("Received packet with command: \(String(describing: command))");
		
		if  (command == "play") {// Play command
			print("Received play command.");
			
			// Save the values for next play
			lastReceivedHostPlaybackTime = (payloadDict["timeAtPlaybackTime"] as! UInt64);
			lastReceivedHostSongPlaybackTime = (payloadDict["playbackTime"] as! TimeInterval);
			
			let continuousPlay: Bool = payloadDict["continuousPlay"] as! Bool;
			
			if (continuousPlay) {// Host is playing
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
				self.playerManager.seekToTimeInSeconds(time: (playbackTime+self.playerManager.outputLatency), completionHandler: { (success) in
					if !success {
						print("Failed to seek for sync play.");
					}
				})
			}
			
		} else if (command == "pause") {
			print("Received pause command.");
			
			if self.synaction.isCalibrating {
				lastReceivedTimeToExecute = (payloadDict["timeToExecute"] as! UInt64);
				return;
			}
			
			let timeToExecute: UInt64 = (payloadDict["timeToExecute"] as! UInt64);
			
			self.synaction.atExactTime(timeToExecute, run: {
				self.playerManager.pause();
			});
			
		} else if (command == "load") {
			print("Received load command.");
			
			self.currentSongMetadata = payloadDict["metadata"] as! Dictionary<String, Any?>?;
			self.updateInterface(notification: nil);
			
			let fileData: Data = payloadDict["file"] as! Data;
			
			do {
				try FileManager.default.removeItem(at: self.playerManager.currentSongFilePath!);
				print("Deleted old song file.");
				
			} catch {
				print("Error deleting old song: \(error)");
			}
			
			do {
				try fileData.write(to: self.playerManager.currentSongFilePath!);
				print("Wrote new song to file.");
				
				let asset: AVAsset = AVAsset(url: self.playerManager.currentSongFilePath!);
				
				let playerItem: AVPlayerItem = AVPlayerItem.init(asset: asset);
				self.playerManager.loadSongFromPlayerItem(playerItem: playerItem);
				print("Loaded song into player.");
				
				self.requestHostState(notification:  nil);
				
			} catch {
				print("Error writing song data to file: \(error)");
			}
			
		} else {
			print("Received unparsed command & payload: [\(String(describing: command))] \(payloadDict)");
		}
	}
	
	func socketDidDisconnect(_ socket: GCDAsyncSocket, withError error: Error) {
		self.dismissReceiverViewController(self.backButton);
	}
	
	func adjustedSongTimeForHost() -> TimeInterval {
		let currentNetworkTime: UInt64 = self.synaction.currentNetworkTime()
		let timePassedBetweenSent = currentNetworkTime.subtractingReportingOverflow(lastReceivedHostPlaybackTime);
		
		print("lastReceivedHostTime: \(lastReceivedHostPlaybackTime) currentNetworkTime: \(currentNetworkTime) timePassedBetweenSent: \(timePassedBetweenSent)");
		
		let timeToForwardSong: TimeInterval = TimeInterval(timePassedBetweenSent.0/UInt64(1000000000.0)) // Convert to seconds
		let adjustedSongTime: TimeInterval = lastReceivedHostSongPlaybackTime + timeToForwardSong + self.playerManager.outputLatency;// Adjust song time
		
		print("lastReceivedHostPlaybackTime: \(lastReceivedHostPlaybackTime) + timeToForwardSong: \(timeToForwardSong) = adjustedSongTime: \(adjustedSongTime) ");
		
		return adjustedSongTime;
	}
	
    @objc public func requestHostState(notification: Notification?) {// Ask the host to send us the song if we don't have it, otherwise it's state (play/pause)
		if (self.playerManager.currentSong == nil) {
			let payloadDict: [String : Any] = ["command": "getSong"]  as [String : Any];
			let packet: Packet = try! Packet.init(data: NSKeyedArchiver.archivedData(withRootObject: payloadDict, requiringSecureCoding: false), type: PacketTypeFile, action: PacketActionUnknown);

			print("Asking host to send us the song");
			self.connectivityManager.send(packet, to: [self.connectivityManager.hostSocket!]);
			return;
		}
		
		let payloadDict: [String : Any] = ["command": "status"]  as [String : Any];
		let packet: Packet = try! Packet.init(data: NSKeyedArchiver.archivedData(withRootObject: payloadDict, requiringSecureCoding: false), type: PacketTypeFile, action: PacketActionUnknown);
		
		print("Asking host to send us their status");
		self.connectivityManager.send(packet, to: [self.connectivityManager.hostSocket!]);
	}
}
