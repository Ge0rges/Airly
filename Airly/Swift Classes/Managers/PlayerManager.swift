//
//  PlayerManager.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import Foundation
import AVKit
import AVFoundation
import MediaPlayer

class PlayerManager: NSObject {
	public var queue: [AVPlayerItem] = [];
	public var queueMetadata: [Dictionary<String, Any?>] = [];
	
	public var isPlaying: Bool {
		return (BASS_ChannelIsActive(self.channel) == DWORD(BASS_ACTIVE_PLAYING));
	}
	
	public var currentSong: AVPlayerItem? {
		return (currentSongIndex >= 0 && currentSongIndex < self.queue.count) ? self.queue[currentSongIndex] : nil;
	}
	
	public var currentMediaItem: MPMediaItem? {
		return (self.queueMediaItems!.count > 0 && currentSongIndex < self.queueMediaItems!.count) ? self.queueMediaItems![currentSongIndex] : nil;
	}
	
	public var previousSong: AVPlayerItem? {
		return (currentSongIndex-1 >= 0 && self.queue.count > 1) ? self.queue[currentSongIndex-1] : nil;
	}
	
	public var nextSong: AVPlayerItem? {
		return (currentSongIndex+1 < self.queue.count && self.queue.count > 0) ? self.queue[currentSongIndex+1] : nil;
	}
	
	public var currentSongMetadata: Dictionary<String, Any?>? {
		return (self.queueMetadata.count > currentSongIndex) ? self.queueMetadata[currentSongIndex] : nil;
	}
	
	public var outputLatency: TimeInterval {
		return self.session.outputLatency;
	}
	
	public var currentSongFilePath: URL! {
		// Get the path for the song
		let tempPath: URL = NSURL.fileURL(withPath: NSTemporaryDirectory());
		let songURL: URL = tempPath.appendingPathComponent("song.caf", isDirectory: false);
		
		return songURL;
	}
	
	public var currentPlaybackTime: TimeInterval {
		return BASS_ChannelBytes2Seconds(self.channel, BASS_ChannelGetPosition(self.channel, DWORD(BASS_POS_BYTE)));
	}
	
	public var shouldPlay = true;
	public var channel: HSTREAM = 0;
	private let session: AVAudioSession = AVAudioSession.sharedInstance();
	private var currentSongIndex: Int = 0;
	private var queueMediaItems: [MPMediaItem]? = nil;
	
	public static let PlayerSongChangedNotificationName = NSNotification.Name(rawValue: "PlayerSongChanged");
	public static let PlayerQueueChangedNotificationName = NSNotification.Name(rawValue: "PlayerQueueChanged");
	public static let PlayerPlayedNotificationName = NSNotification.Name(rawValue: "PlayerPlayed");
	public static let PlayerPausedNotificationName = NSNotification.Name(rawValue: "PlayerPaused");
	
	
	static let sharedManager = PlayerManager();
	override private init() {//This prevents others from using the default '()' initializer for this class
		super.init();
		
		// Setup the session
		do {
			try self.session.setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)), mode: .default);
			try self.session.setActive(true);
			try self.session.setPreferredIOBufferDuration(0.005);
			
		} catch let error as NSError {
			print("Unable to activate audio session:  \(error.localizedDescription)");
		}
		
		// Initialize BASS
		BASS_Init(-1, 44100, 0, nil, nil);
		BASS_SetConfig(DWORD(BASS_CONFIG_IOS_NOCATEGORY), 1);
		BASS_SetVolume(1);
	}
	
	public func play() {
		// Play at default rate
		BASS_ChannelPlay(self.channel, false);
		NotificationCenter.default.post(name: PlayerManager.PlayerPlayedNotificationName, object: self);
		
		let timeRemainingInSong = BASS_ChannelBytes2Seconds(self.channel, BASS_ChannelGetLength(self.channel, DWORD(BASS_POS_BYTE))) - self.currentPlaybackTime;
		self.perform(#selector(self.playerDidFinishPlaying(notification:)), with: nil, afterDelay: timeRemainingInSong);
		
		self.shouldPlay = true;
	}
	
	public func pause() {
		BASS_ChannelPause(self.channel);
		NotificationCenter.default.post(name: PlayerManager.PlayerPausedNotificationName, object: self);
		
		self.shouldPlay = false;
	}
	
	public func loadQueueFromMPMediaItems(mediaItems: Array<MPMediaItem>?) -> Void {
		self.queueMediaItems = mediaItems;// Save the media items.
		self.queue.removeAll();// Remove old queue.
		self.queueMetadata.removeAll();// Clear old album artwork.
		currentSongIndex = 0;
		
		if (mediaItems == nil || mediaItems!.count == 0) {
			print("Empty queue: deleting song file and stopping channel.");
            try? FileManager.default.removeItem(at: self.currentSongFilePath);
            BASS_ChannelStop(self.channel);
            
			return;
		}
		
		// For every item, get the AVPlayerItem and set it in the array.
		for mediaItem in mediaItems! {
			let mediaItemURL:URL = mediaItem.value(forProperty: MPMediaItemPropertyAssetURL) as! URL;
			let playerItem: AVPlayerItem = AVPlayerItem(asset: AVAsset(url: mediaItemURL));
			self.queue.append(playerItem);
            
			let metadata: Dictionary = ["artwork": mediaItem.artwork ?? #imageLiteral(resourceName: "Default Music"), "artist": mediaItem.artist ?? "Unknown Artist", "title": mediaItem.title ?? "Unknown Title"] as [String : Any];
			self.queueMetadata.append(metadata);
		}
		
		self.exportCurrentSongToFile {
			BASS_ChannelStop(self.channel);
			self.channel = BASS_StreamCreateFile(false, self.currentSongFilePath.path, 0, 0, DWORD(BASS_STREAM_PRESCAN));
			
			NotificationCenter.default.post(name: PlayerManager.PlayerQueueChangedNotificationName, object: self, userInfo: ["queue": self.queue]);
			
			if (self.shouldPlay) {
				self.play();
			}
		}
	}
	
	public func loadSongFromPlayerItem(playerItem: AVPlayerItem!) {
		self.queueMediaItems = nil;// Save the media items.
		self.queue.removeAll();// Remove old queue.
		self.queueMetadata.removeAll();// Clear old album artwork.
		self.queue.append(playerItem);
		currentSongIndex = 0;
		
		BASS_ChannelStop(self.channel);
		self.channel = BASS_StreamCreateFile(false, self.currentSongFilePath.path, 0, 0, DWORD(BASS_STREAM_PRESCAN));
		BASS_ChannelSetAttribute(self.channel, DWORD(BASS_ATTRIB_NOBUFFER), 1);
	}
	
	public func playNextSong() {
		currentSongIndex += 1;
		if (currentSongIndex >= self.queue.count) {
			currentSongIndex = self.queue.count-1;
			return;
		}
		
		self.exportCurrentSongToFile {
			BASS_ChannelStop(self.channel);
			self.channel = BASS_StreamCreateFile(false, self.currentSongFilePath.path, 0, 0, DWORD(BASS_STREAM_PRESCAN));
			
			if self.shouldPlay {
				self.play();
			}
		}
	}
	
	public func playPreviousSong() {
		currentSongIndex -= 1;
		if (currentSongIndex < 0) {
			currentSongIndex = 0;
			return;
		}
		
		self.exportCurrentSongToFile {
			BASS_ChannelStop(self.channel);
			self.channel = BASS_StreamCreateFile(false, self.currentSongFilePath.path, 0, 0, DWORD(BASS_STREAM_PRESCAN));
			
			if (self.shouldPlay) {
				self.play();
			}
		}
	}
	
	public func seekToTimeInSeconds(time: TimeInterval, completionHandler: @escaping (Bool) -> Void) {
		BASS_ChannelSetPosition(self.channel, BASS_ChannelSeconds2Bytes(self.channel, time), DWORD(BASS_POS_BYTE));
		print("error seeking in song: \(BASS_ErrorGetCode())");
	}
	
    @objc private func playerDidFinishPlaying(notification: Notification?) {
		let timeRemainingInSong = BASS_ChannelBytes2Seconds(self.channel, BASS_ChannelGetLength(self.channel, DWORD(BASS_POS_BYTE))) - self.currentPlaybackTime;

		if timeRemainingInSong < 1 {
			if (self.nextSong != nil) {
				self.playNextSong();
			
			} else {
				self.pause();
			}
			
		} else {
			self.perform(#selector(self.playerDidFinishPlaying(notification:)), with: nil, afterDelay: timeRemainingInSong);
		}
	}
	
	public func exportCurrentSongToFile(completionHandler: @escaping () -> Void) {
		// Delete old song
		do {
			try FileManager.default.removeItem(at: self.currentSongFilePath);
			
		} catch {
			print("Failed to delete old song for export. Error: \(error)");
		}
		
		// If no new song return.
		if (currentSongIndex >= self.queue.count || self.queue.count < 1) {
			print("Error exporting file, invalid song index.");
			completionHandler();
			return;
		}
		
		// Export the current song to a file and send the file to the peer
		let currentSongAsset: AVAsset = self.queue[currentSongIndex].asset;
		let exporter: AVAssetExportSession = AVAssetExportSession.init(asset: currentSongAsset, presetName: AVAssetExportPresetPassthrough)!;
		exporter.outputFileType = convertToOptionalAVFileType("com.apple.coreaudio-format");
		exporter.outputURL = self.currentSongFilePath;
		
		print("Exporting current song host");
		
		exporter.exportAsynchronously {
			DispatchQueue.main.async {
				NotificationCenter.default.post(name: PlayerManager.PlayerSongChangedNotificationName, object: self);
				completionHandler();
			}
		};
	}
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalAVFileType(_ input: String?) -> AVFileType? {
	guard let input = input else { return nil }
	return AVFileType(rawValue: input)
}
