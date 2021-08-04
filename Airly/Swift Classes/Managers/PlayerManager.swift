//
//  PlayerManager.swift
//  Airly
//
//  Created by Georges Kanaan on 04/08/2021.
//  Copyright © 2021 Georges Kanaan. All rights reserved.
//

import Foundation
import UIKit
import AVKit

public class SongItem: NSObject, NSSecureCoding {
    public var title:String? = nil
    public var artist:String? = nil
    public var image:UIImage? = nil
    public var path: String? = nil
    public var avItem: AVPlayerItem? = nil
    
    public static var supportsSecureCoding: Bool {
        return true
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(title, forKey: "title")
        coder.encode(artist, forKey: "artist")
        coder.encode(image, forKey: "image")
        coder.encode(path, forKey: "path")

    }
    
    public required init?(coder: NSCoder) {
        self.title = coder.decodeObject(forKey: "title") as? String
        self.artist = coder.decodeObject(forKey: "artist") as? String
        self.image = coder.decodeObject(forKey: "image") as? UIImage
        self.path = coder.decodeObject(forKey: "path") as? String
        self.avItem = nil
    }
    
    public required override init() {
        super.init()
    }
}

let PlayerSongChangedNotificationName: NSNotification.Name = NSNotification.Name(rawValue: "PlayerSongChanged")
let PlayerQueueChangedNotificationName: NSNotification.Name = NSNotification.Name(rawValue: "PlayerQueueChanged")
let PlayerPlayedNotificationName: NSNotification.Name = NSNotification.Name(rawValue: "PlayerPlayed")
let PlayerPausedNotificationName: NSNotification.Name = NSNotification.Name(rawValue: "PlayerPaused")

protocol PlayerManager {
    var isSpotify: Bool { get }
    var outputLatency: TimeInterval { get }
    
    func isPlaying(completion: @escaping (Bool) -> Void)
    func currentSong(completion: @escaping (SongItem?) -> Void)
    func canSkipToPreviousSong(completion: @escaping (Bool) -> Void)
    func canSkipToNextSong(completion: @escaping (Bool) -> Void)
    func currentPlaybackTime(completion: @escaping (TimeInterval) -> Void) // In seconds
    
    func play(completion: @escaping (Bool) -> Void)
    func pause(completion: @escaping (Bool) -> Void)
    func playNextSong(completion: @escaping (Bool) -> Void)
    func playPreviousSong(completion: @escaping (Bool) -> Void)
    func seekToTimeInSeconds(time: TimeInterval!, completion: @escaping (Bool) -> Void)
    func loadQueueFromItems(songItems: [SongItem])
    func loadSong(songItem: SongItem)
    func authorize(completion: @escaping (Bool) -> Void)
}
