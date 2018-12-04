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
		NotificationCenter.default.addObserver(self, selector: #selector(self.sendPlayCommand(notification:)), name: PlayerManager.PlayerPlayedNotificationName, object: nil);
		NotificationCenter.default.addObserver(self, selector: #selector(self.sendPauseCommand(calibrate:)), name: PlayerManager.PlayerPausedNotificationName, object: nil);
	}
	
	@objc public func sendPlayCommand(notification: Notification?) -> UInt64 {
		print("Sending play command.");
		
		if self.playerManager.currentSong == nil {
			print("Canceled send play, current song was nil: %@", self.playerManager.currentSong as Any);
			return 0;
		}
		
		let deviceTimeAtPlaybackTime: UInt64 = self.synaction.currentTime();
		let timeToExecute: UInt64 = deviceTimeAtPlaybackTime + 1000000000;
		
		let dictionaryPayload = ["command": "play",
		                         "timeToExecute": timeToExecute,
		                         "playbackTime": self.playerManager.currentPlaybackTime,
		                         "continuousPlay": self.playerManager.isPlaying,
		                         "timeAtPlaybackTime": deviceTimeAtPlaybackTime,
		                         "song": (self.playerManager.currentSongMetadata?["title"] ?? "Unknown Song Name")!
			] as [String : Any];
		
		let payloadData = NSKeyedArchiver.archivedData(withRootObject: dictionaryPayload);
		let packet: Packet = Packet.init(data: payloadData, type: PacketTypeControl, action: PacketActionPlay);
		self.synaction.connectivityManager.send(packet, to: self.connectivityManager.allSockets as! [GCDAsyncSocket]);
		
		return timeToExecute;
	}
	
	@objc public func sendPauseCommand(calibrate: Any) -> UInt64 {
		print("Sending pause command.");
		
		let timeToExecute = self.synaction.currentTime();
		
		let dictionaryPayload = ["command": "pause",
		                         "timeToExecute": timeToExecute,
		                         "song": (self.playerManager.currentSongMetadata?["title"] ?? "")!
			] as [String : Any];
		
		let payloadData = NSKeyedArchiver.archivedData(withRootObject: dictionaryPayload);
		let packet: Packet = Packet.init(data: payloadData, type: PacketTypeControl, action: PacketActionPlay);
		self.synaction.connectivityManager.send(packet, to: self.connectivityManager.allSockets as! [GCDAsyncSocket]);
		
		if (calibrate is Bool) {
			if (calibrate as! Bool == true) {
				print("Asking peers to calibrate after pause");
				self.synaction.askPeers(toCalculateOffset: self.connectivityManager.allSockets as! [GCDAsyncSocket]);
			}
		}
		
		return timeToExecute;
	}
	
	@objc public func sendCurrentSong(notification: Notification?) {
		print("sendCurrentSong called on thread: \(Thread.current)");
		
		// Pause command
		let _ = self.sendPauseCommand(calibrate: false);
		
		// Send the file
		do {
			let fileData = try Data.init(contentsOf: self.playerManager.currentSongFilePath!);
			
			var metadataA: [String: Any?]? = self.playerManager.currentSongMetadata;
			if let _ = metadataA {// Check that metadata is not nil
				if let artwork = metadataA?["artwork"] as? MPMediaItemArtwork {// Check that atwork is not nil & exists
                    let imageSize: CGSize = (self.broadcastViewController == nil) ? CGSize(width: 1024, height: 1024) : self.broadcastViewController!.albumArtImageView.frame.size;
					metadataA?["artwork"] = artwork.image(at: imageSize);
                    
                }
            }
            
			print("Building current song packet with song data: \(fileData)");
			
			let payloadDict: [String : Any] = ["command": "load", "file": fileData, "metadata": (metadataA ?? ["empty": true])]  as [String : Any];
			let packet: Packet = Packet.init(data: NSKeyedArchiver.archivedData(withRootObject: payloadDict), type: PacketTypeFile, action: PacketActionUnknown);
			
			self.synaction.executeBlock(whenAllPeersCalibrate: self.connectivityManager.allSockets as! [GCDAsyncSocket], block: { (sockets) in
				print("Sending current song: \(payloadDict)");
				self.connectivityManager.send(packet, to: self.connectivityManager.allSockets as! [GCDAsyncSocket]);
			});
			
		} catch {
			print("failed to get data of file on host \(error)");
		}
	}
	
	func socket(_ socket: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
		// Update UI
		self.broadcastViewController!.numberOfClientsLabel.text = (self.connectivityManager.allSockets.count == 1) ? "to 1 person" : "to \(self.connectivityManager.allSockets.count) people";
		
		print("Socket connected, asking to calibrate");
		self.synaction.askPeers(toCalculateOffset: [newSocket] );
	}
	
	func socketDidDisconnect(_ socket: GCDAsyncSocket, withError error: Error) {
		// Update UI
		self.broadcastViewController!.numberOfClientsLabel.text = "to \(self.connectivityManager.allSockets.count) people";
	}
	
	func didReceive(_ packet: Packet, from socket: GCDAsyncSocket) {
		let payloadDict: Dictionary<String,Any?> = NSKeyedUnarchiver.unarchiveObject(with: packet.data as! Data) as! Dictionary;
		let command: String! = payloadDict["command"] as! String;
		
		if (command == "status") {// Send our current status to this peer
			print("A peer requested host status. Sending.");
			
			if self.playerManager.isPlaying {
				let _ = self.sendPlayCommand(notification: nil);
				
			} else {
				let _ = self.sendPauseCommand(calibrate: false);
			}
			
		} else if (command == "getSong") {
			print("A peer requested the song. Sending.");
			self.sendCurrentSong(notification: nil);// It will handle sending player state
		}
	}
}
