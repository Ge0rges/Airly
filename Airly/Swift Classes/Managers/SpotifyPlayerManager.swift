//
//  SpotifyPlayerManager.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import Foundation
import AVKit

class SpotifyPlayerManager: NSObject, PlayerManager, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    
    // Unique to Spotify
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private let appRemote = (UIApplication.shared.delegate as! AppDelegate).appRemote
    private var authorizeHandler: ((Bool) -> Void)? = nil
    private var currentState: SPTAppRemotePlayerState? = nil
    
    // Protocol
    var isSpotify: Bool {
        return true
    }
    
    public var outputLatency: TimeInterval {
        return 0//TODO
    }
    
    static let sharedManager = SpotifyPlayerManager()
    override private init() {//This prevents others from using the default '()' initializer for this class
        super.init()
        
        self.appRemote.delegate = self
        self.appRemote.playerAPI?.subscribe(toPlayerState: { _, _ in})
    }
    
    public func authorize(completion: @escaping (Bool) -> Void) {
        // Authorize and play last song.
        self.appRemote.authorizeAndPlayURI("")
        self.authorizeHandler = completion
    }
    
    public func isPlaying(completion: @escaping (Bool) -> Void) {
        if let state = self.currentState {
            completion(!state.isPaused)
            
        } else {
            completion(false)
        }
        
    }
    
    public func currentSong(completion: @escaping (SongItem?) -> Void) {
        
        let currentSongItem = SongItem()
        currentSongItem.title = self.currentState?.track.name
        currentSongItem.artist = self.currentState?.track.artist.name
        currentSongItem.path = self.currentState?.track.uri ?? nil
        
        if let state = self.currentState {
            self.appRemote.imageAPI?.fetchImage(forItem: state.track, with: CGSize(width: 1024, height: 1024), callback: { image, error in
                if let image = image as? UIImage {
                    currentSongItem.image = image
                } else {
                    currentSongItem.image = nil
                }
                
                completion(currentSongItem)
            })
            
        } else {
            currentSongItem.image = nil
            completion(currentSongItem)
        }
        
    }
    
    public func currentPlaybackTime(completion: @escaping (TimeInterval) -> Void) {
        completion(TimeInterval(self.currentState?.playbackPosition ?? 0))
    }
    
    public func canSkipToPreviousSong(completion: @escaping (Bool) -> Void) {
        completion(self.currentState?.playbackRestrictions.canSkipPrevious ?? false)
    }
    
    public func canSkipToNextSong(completion: @escaping (Bool) -> Void) {
        completion(self.currentState?.playbackRestrictions.canSkipNext ?? false)
    }
    
    //TODO
    public func play(completion: @escaping (Bool) -> Void) {
        self.appRemote.playerAPI?.resume({ result, error in
            completion((error != nil))
        })
    }
    
    public func pause(completion: @escaping (Bool) -> Void) {
        self.appRemote.playerAPI?.pause({ result, error in
            completion((error != nil))
        })
    }
    
    public func playNextSong(completion: @escaping (Bool) -> Void) {
        self.appRemote.playerAPI?.skip(toNext: { result, error in
            completion((error != nil))
        })
    }
    
    public func playPreviousSong(completion: @escaping (Bool) -> Void) {
        self.appRemote.playerAPI?.skip(toPrevious: { result, error in
            completion((error != nil))
        })
    }
    
    public func seekToTimeInSeconds(time: TimeInterval!, completion: @escaping (Bool) -> Void) {
        self.appRemote.playerAPI?.seek(toPosition: Int(time) * 1000, callback: { result, error in
            completion((error != nil))
        })
    }
    
    public func loadQueueFromItems(songItems: [SongItem]) {
        //TODO
        // - (void)enqueueTrackUri:(NSString *)trackUri callback:(nullable SPTAppRemoteCallback)callback
        // - (void)playItem:(id<SPTAppRemoteContentItem>)contentItem callback:(nullable SPTAppRemoteCallback)callback
        // Check if SPTAppRemoteContentItem.playable is true
    }
    
    func loadSong(songItem: SongItem) {
        self.appRemote.playerAPI?.play(songItem.path!, callback: { _, _ in})
    }
    
    //MARK: - STAppRemoteDelegate
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("connected")
        
        self.appRemote.playerAPI?.getPlayerState({ state, _ in
            self.currentState = state as? SPTAppRemotePlayerState
            NotificationCenter.default.post(name: PlayerSongChangedNotificationName, object: state)
            
            // We were just authorized. Check if there's a completion handler to call.
            if (self.authorizeHandler != nil) {
                self.authorizeHandler!(true)
                self.authorizeHandler = nil
            }

        })
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("disconnected with error")
        print(error as Any)
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("failed to connect with error")
        print(error as Any)
        
        // We were just denied authorization. Check if there's a completion handler to call.
        if (self.authorizeHandler != nil) {
            authorizeHandler!(false)
            self.authorizeHandler = nil
        }
    }
    
    //MARK: - STAppRemotePlayerStateChangeDelegate
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        self.currentState = playerState
        NotificationCenter.default.post(name: PlayerSongChangedNotificationName, object: playerState)
    }
}
