//
//  ApplePlayerManager.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import Foundation
import AVKit
import AVFoundation
import MediaPlayer

class ApplePlayerManager: NSObject, PlayerManager {
    
    public var shouldPlay = true
    public var channel: HSTREAM = 0
    
    private let session: AVAudioSession = AVAudioSession.sharedInstance()
    private var currentSongIndex: Int = 0
    private var songItems: [SongItem] = []
    
    var isSpotify: Bool {
        return false
    }
    
    static let sharedManager = ApplePlayerManager()
    override private init() {//This prevents others from using the default '()' initializer for this class
        super.init()
        
        // Setup the session
        do {
            try self.session.setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)), mode: .default)
            try self.session.setActive(true)
            try self.session.setPreferredIOBufferDuration(0.005)
            
        } catch let error as NSError {
            print("Unable to activate audio session:  \(error.localizedDescription)")
        }
        
        // Initialize BASS
        BASS_Init(-1, 44100, 0, nil, nil)
        BASS_SetConfig(DWORD(BASS_CONFIG_IOS_NOCATEGORY), 1)
        BASS_SetVolume(1)
    }
    
    func authorize(completion: @escaping (Bool) -> Void) {
        MPMediaLibrary.requestAuthorization { (authorizationStatus) in
            completion((authorizationStatus == MPMediaLibraryAuthorizationStatus.authorized))
        }
    }

    func isPlaying(completion: @escaping (Bool) -> Void) {
        completion((BASS_ChannelIsActive(self.channel) == DWORD(BASS_ACTIVE_PLAYING)))
    }
    
    func currentSong(completion: @escaping (SongItem?) -> Void) {
        let currentSong = self.songItems[self.currentSongIndex]
        currentSong.path = self.currentSongFilePath
        completion(currentSong)
    }
    
    func canSkipToPreviousSong(completion: @escaping (Bool) -> Void) {
        completion((currentSongIndex-1 >= 0 && self.songItems.count > 1))
    }
    
    func canSkipToNextSong(completion: @escaping (Bool) -> Void) {
        completion((currentSongIndex+1 < self.songItems.count && self.songItems.count > 0))
    }
    
    func currentPlaybackTime(completion: @escaping (TimeInterval) -> Void) {
        completion(BASS_ChannelBytes2Seconds(self.channel, BASS_ChannelGetPosition(self.channel, DWORD(BASS_POS_BYTE))))
    }
    
    func play(completion: @escaping (Bool) -> Void) {
        // Play at default rate
        BASS_ChannelPlay(self.channel, false)
        NotificationCenter.default.post(name: PlayerPlayedNotificationName, object: self)
        
        self.currentPlaybackTime { time in
            let timeRemainingInSong = BASS_ChannelBytes2Seconds(self.channel, BASS_ChannelGetLength(self.channel, DWORD(BASS_POS_BYTE))) - time
            self.perform(#selector(self.playerDidFinishPlaying(notification:)), with: nil, afterDelay: timeRemainingInSong)
            
            self.shouldPlay = true
            
            completion(true)
        }
    }
    
    func pause(completion: @escaping (Bool) -> Void) {
        BASS_ChannelPause(self.channel)
        NotificationCenter.default.post(name: PlayerPausedNotificationName, object: self)
        
        self.shouldPlay = false
        
        completion(true)
    }
    
    func playNextSong(completion: @escaping (Bool) -> Void) {
        currentSongIndex += 1
        if (currentSongIndex >= self.songItems.count) {
            currentSongIndex = self.songItems.count-1
            return
        }
        
        self.exportCurrentSongToFile {
            BASS_ChannelStop(self.channel)
            self.channel = BASS_StreamCreateFile(false, URL(string: self.currentSongFilePath)!.path, 0, 0, DWORD(BASS_STREAM_PRESCAN))
            
            if self.shouldPlay {
                self.play(completion: completion)
                
            } else {
                completion(true)
            }
        }
    }
    
    func playPreviousSong(completion: @escaping (Bool) -> Void) {
        currentSongIndex -= 1
        if (currentSongIndex < 0) {
            currentSongIndex = 0
            return
        }
        
        self.exportCurrentSongToFile {
            BASS_ChannelStop(self.channel)
            self.channel = BASS_StreamCreateFile(false, URL(string: self.currentSongFilePath)!.path, 0, 0, DWORD(BASS_STREAM_PRESCAN))
            
            if (self.shouldPlay) {
                self.play(completion: completion)
                
            } else {
                completion(true)
            }
        }
    }
    
    func seekToTimeInSeconds(time: TimeInterval!, completion: @escaping (Bool) -> Void) {
        BASS_ChannelSetPosition(self.channel, BASS_ChannelSeconds2Bytes(self.channel, time), DWORD(BASS_POS_BYTE))
        print("error seeking in song: \(BASS_ErrorGetCode())")
        completion((BASS_ErrorGetCode() == 0))
    }
    
    func loadQueueFromItems(songItems: [SongItem]) {
        self.songItems = songItems// Save the media items.
        currentSongIndex = 0
        
        if (self.songItems.count == 0) {
            print("Empty queue: deleting song file and stopping channel.")
            try? FileManager.default.removeItem(at: URL(string: self.currentSongFilePath)!)
            BASS_ChannelStop(self.channel)
            
            return
        }
        
        self.exportCurrentSongToFile {
            BASS_ChannelStop(self.channel)
            self.channel = BASS_StreamCreateFile(false, URL(string: self.currentSongFilePath)!.path, 0, 0, DWORD(BASS_STREAM_PRESCAN))
            BASS_ChannelSetAttribute(self.channel, DWORD(BASS_ATTRIB_NOBUFFER), 1);

            NotificationCenter.default.post(name: PlayerQueueChangedNotificationName, object: self, userInfo: ["queue": self.songItems])
            
            if (self.shouldPlay) {
                self.play { _ in}
            }
        }
    }
        
    public var outputLatency: TimeInterval {
        return self.session.outputLatency
    }
    
    public var currentSongFilePath: String! {
        // Get the path for the song
        let tempPath: URL = NSURL.fileURL(withPath: NSTemporaryDirectory())
        let songURL: URL = tempPath.appendingPathComponent("song.caf", isDirectory: false)
        
        return songURL.absoluteString
    }
    
    public var currentPlaybackTime: TimeInterval {
        return BASS_ChannelBytes2Seconds(self.channel, BASS_ChannelGetPosition(self.channel, DWORD(BASS_POS_BYTE)))
    }
    
    public func loadSong(songItem: SongItem) {
        self.songItems.removeAll()// Save the media items.
        self.songItems.append(songItem)
        currentSongIndex = 0
        
        BASS_ChannelStop(self.channel)
        self.channel = BASS_StreamCreateFile(false, URL(string: self.currentSongFilePath)!.path, 0, 0, DWORD(BASS_STREAM_PRESCAN))
        BASS_ChannelSetAttribute(self.channel, DWORD(BASS_ATTRIB_NOBUFFER), 1)
    }

    @objc private func playerDidFinishPlaying(notification: Notification?) {
        self.currentPlaybackTime { time in
            let timeRemainingInSong = BASS_ChannelBytes2Seconds(self.channel, BASS_ChannelGetLength(self.channel, DWORD(BASS_POS_BYTE))) - time
            if timeRemainingInSong < 1 {
                self.canSkipToNextSong { result in
                    if result {
                        self.playNextSong {_ in }
                        
                    } else {
                        self.pause {_ in }
                    }
                }
                
            } else {
                self.perform(#selector(self.playerDidFinishPlaying(notification:)), with: nil, afterDelay: timeRemainingInSong)
            }
        }
    }
    
    public func exportCurrentSongToFile(completionHandler: @escaping () -> Void) {
        // Delete old song
        do {
            try FileManager.default.removeItem(at: URL(string: self.currentSongFilePath)!)
            
        } catch {
            print("Failed to delete old song for export. Error: \(error)")
        }
        
        // If no new song return.
        if (currentSongIndex >= self.songItems.count || self.songItems.count < 1) {
            print("Error exporting file, invalid song index.")
            completionHandler()
            return
        }
        
        // Export the current song to a file and send the file to the peer
        let currentSongAsset: AVAsset = self.songItems[currentSongIndex].avItem!.asset
        let exporter: AVAssetExportSession = AVAssetExportSession.init(asset: currentSongAsset, presetName: AVAssetExportPresetPassthrough)!
        exporter.outputFileType = convertToOptionalAVFileType("com.apple.coreaudio-format")
        exporter.outputURL = URL(string: self.currentSongFilePath)!
        
        print("Exporting current song host")
        
        exporter.exportAsynchronously {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: PlayerSongChangedNotificationName, object: self)
                completionHandler()
            }
        }
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
