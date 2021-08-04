//
//  HostSyncManager.swift
//  Airly
//
//  Created by Georges Kanaan on 22/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import UIKit
import MediaPlayer
import AVFoundation

class HostSyncManager: NSObject, ConnectivityManagerDelegate {
    
    let connectivityManager:ConnectivityManager! = ConnectivityManager.shared()
    let synaction:Synaction! = Synaction.sharedManager()
    public var broadcastViewController: BroadcastViewController?
    private var playerManager: PlayerManager?
    
    static let sharedManager = HostSyncManager()
    override private init() {//This prevents others from using the default '()' initializer for this class
        super.init()
        
        // Get playerManager from BroadcastVC later
        self.playerManager = nil
        
        // Set ourselves as the delegate
        self.synaction.connectivityManager.delegate = self
        
        // Register for notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.sendCurrentSong(notification:)), name: PlayerSongChangedNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.sendPlayCommand(notification:)), name: PlayerPlayedNotificationName, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.sendPauseCommand(calibrate:)), name: PlayerPausedNotificationName, object: nil)
    }
    
    @objc public func sendPlayCommand(notification: Notification?) {
        
        print("Sending play command.")
        
        self.playerManager = self.broadcastViewController!.playerManager!
        
        self.playerManager!.currentSong { songItem in
            if songItem == nil {
                print("Canceled send play, current song was nil: %@", self.playerManager!.currentSong as Any)
                
            } else {
                let deviceTimeAtPlaybackTime: UInt64 = self.synaction.currentTime()
                let timeToExecute: UInt64 = deviceTimeAtPlaybackTime + 1000000000
                
                self.playerManager!.currentPlaybackTime { playbackTime in
                    self.playerManager!.isPlaying { isPlaying in
                        let dictionaryPayload = ["command": "play",
                                                 "timeToExecute": timeToExecute,
                                                 "playbackTime": playbackTime,
                                                 "continuousPlay": isPlaying,
                                                 "timeAtPlaybackTime": deviceTimeAtPlaybackTime,
                                                 "song": songItem!.title!,
                                                 "isSpotify": self.playerManager!.isSpotify
                        ] as [String : Any]
                        
                        let payloadData = try! NSKeyedArchiver.archivedData(withRootObject: dictionaryPayload, requiringSecureCoding: false)
                        let packet: Packet = Packet.init(data: payloadData, type: PacketTypeControl, action: PacketActionPlay)
                        self.synaction.connectivityManager.send(packet, to: self.connectivityManager.allSockets as! [GCDAsyncSocket])
                    }
                }
            }
        }
    }
    
    @objc public func sendPauseCommand(calibrate: Bool)  {
        print("Sending pause command.")
        
        self.playerManager = self.broadcastViewController!.playerManager!
        
        let timeToExecute = self.synaction.currentTime()
        
        self.playerManager!.currentSong { songItem in
            let dictionaryPayload = ["command": "pause",
                                     "timeToExecute": timeToExecute,
                                     "song": songItem!.title!,
                                     "isSpotify": self.playerManager!.isSpotify
            ] as [String : Any]
            
            let payloadData = try! NSKeyedArchiver.archivedData(withRootObject: dictionaryPayload, requiringSecureCoding: false)
            let packet: Packet = Packet.init(data: payloadData, type: PacketTypeControl, action: PacketActionPlay)
            self.synaction.connectivityManager.send(packet, to: self.connectivityManager.allSockets as! [GCDAsyncSocket])
            
            if (calibrate) {
                print("Asking peers to calibrate after pause")
                self.synaction.askPeers(toCalculateOffset: self.connectivityManager.allSockets as! [GCDAsyncSocket])
            }
        }
    }
    
    @objc public func sendCurrentSong(notification: Notification?) {
        print("sendCurrentSong called on thread: \(Thread.current)")
        
        self.playerManager = self.broadcastViewController!.playerManager!
        
        // Pause command
        self.sendPauseCommand(calibrate: false)
        
        // Send the file
        self.playerManager!.currentSong { songItem in
            
            let fileData = try? Data.init(contentsOf: URL(string: songItem!.path!)!)
            
            print("Building current song packet with song data: \(String(describing: fileData))")
            // TODO
//            var songItemNoAV = SongItem()
//            songItemNoAV.title = songItem?.title
//            songItemNoAV.artist = songItem?.artist
//            songItemNoAV.image = songItem?.image
//            songItemNoAV.avItem = nil // Can't encode AVAsset
            
            let payloadDict: [String : Any] = ["command": "load", "file": fileData ?? NSData(), "songItem": songItem!]  as [String : Any]
            let packet: Packet = try! Packet.init(data: NSKeyedArchiver.archivedData(withRootObject: payloadDict, requiringSecureCoding: false), type: PacketTypeFile, action: PacketActionUnknown)
            
            self.synaction.executeBlock(whenAllPeersCalibrate: self.connectivityManager.allSockets as! [GCDAsyncSocket], block: { (sockets) in
                print("Sending current song: \(payloadDict)")
                self.connectivityManager.send(packet, to: self.connectivityManager.allSockets as! [GCDAsyncSocket])
            })
        }
    }
    
    func socket(_ socket: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        // Update UI
        self.broadcastViewController!.numberOfClientsLabel.text = (self.connectivityManager.allSockets.count == 1) ? "to 1 person" : "to \(self.connectivityManager.allSockets.count) people"
        
        print("Socket connected, asking to calibrate")
        self.synaction.askPeers(toCalculateOffset: [newSocket] )
    }
    
    func socketDidDisconnect(_ socket: GCDAsyncSocket, withError error: Error) {
        // Update UI
        self.broadcastViewController!.numberOfClientsLabel.text = "to \(self.connectivityManager.allSockets.count) people"
    }
    
    func didReceive(_ packet: Packet, from socket: GCDAsyncSocket) {
        let payloadDict: Dictionary<String,Any?> = try! NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(packet.data!) as! Dictionary
        let command: String! = payloadDict["command"] as? String
        
        if (command == "status") {// Send our current status to this peer
            print("A peer requested host status. Sending.")
            
            self.playerManager = self.broadcastViewController!.playerManager!
            
            self.playerManager!.isPlaying { isPlaying in
                if isPlaying {
                    self.sendPlayCommand(notification: nil)
                    
                } else {
                    self.sendPauseCommand(calibrate: false)
                }
            }
            
        } else if (command == "getSong") {
            print("A peer requested the song. Sending.")
            self.sendCurrentSong(notification: nil)// It will handle sending player state
        }
    }
}
