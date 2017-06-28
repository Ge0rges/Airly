//
//  HostSyncManager.swift
//  Airly
//
//  Created by Georges Kanaan on 22/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

//TODO: Don't send same song twice. + File ID + Delete all end session + no sending twice.

import UIKit
import MediaPlayer
import Flurry_iOS_SDK
import AVFoundation

class HostSyncManager: NSObject, ConnectivityManagerDelegate {
	
	let playerManager:PlayerManager! = PlayerManager.sharedManager;
	let connectivityManager:ConnectivityManager! = ConnectivityManager.shared();
	let synaction:Synaction! = Synaction.sharedManager();
	public var broadcastViewController: BroadcastViewController?;
	
	static let sharedManager = HostSyncManager();
	override private init() {//This prevents others from using the default '()' initializer for this class
		super.init();
		
		// Set ourselves as the delegate
		self.synaction.connectivityManager.delegate = self;
		
		// Register for notifications
		NotificationCenter.default.addObserver(self, selector: #selector(self.sendCurrentSong(notification:)), name: PlayerManager.PlayerSongChangedNotificationName, object: nil);
		NotificationCenter.default.addObserver(self, selector: #selector(self.sendPlayCommand), name: PlayerManager.PlayerPlayedNotificationName, object: nil);
		NotificationCenter.default.addObserver(self, selector: #selector(self.sendPauseCommand), name: PlayerManager.PlayerPausedNotificationName, object: nil);
	}
	
	@objc public func sendPlayCommand() -> UInt64 {
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
	
	@objc public func sendPauseCommand() -> UInt64 {
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
	
	@objc public func sendCurrentSong(notification: Notification?) {
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
					metadataA!["artwork"] = (metadataB["artwork"] as! MPMediaItemArtwork).image(at: self.broadcastViewController!.albumArtImageView.frame.size);
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
		self.broadcastViewController!.numberOfClientsLabel.text = (self.connectivityManager.allSockets.count == 1) ? "to 1 person" : "to \(self.connectivityManager.allSockets.count) people";
		
		print("Socket connected, asking to calibrate");
		self.synaction.askPeers(toCalculateOffset: [newSocket] );
		self.synaction.executeBlock(whenEachPeerCalibrates: [newSocket] ) { (peers) in
			print("Peer calibrated, sending current song.");
			
			self.sendCurrentSong(notification: nil);// It will handle sending player state
		};
	}
	
	func socketDidDisconnect(_ socket: GCDAsyncSocket, withError error: Error) {
		// Update UI
		self.broadcastViewController!.numberOfClientsLabel.text = "to \(self.connectivityManager.allSockets.count) people";
	}
}
