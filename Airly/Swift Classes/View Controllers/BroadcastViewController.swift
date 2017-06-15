//
//  BroadcastViewController.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import UIKit

class BroadcastViewController: UIViewController {
  
  @IBOutlet var backButton: UIButton!
  @IBOutlet var numberOfClientsLabel: UILabel!
  @IBOutlet var addMusicButton: UIButton!
  @IBOutlet var albumArtImageView: UIImageView!
  @IBOutlet var songNameLabel: UILabel!
  @IBOutlet var songArtistLabel: UILabel!
  @IBOutlet var backwardPlaybackButton: UIButton!
  @IBOutlet var playbackButton: UIButton!
  @IBOutlet var forwardPlaybackButton: UIButton!
  
  override func viewDidLoad() {
    //TODO: To do Start Broadcasting Bonjour.
  }
  
  //MARK: - Button Actions
  @IBAction func dismissBroadcastViewController(_ sender: UIButton) {
    //TODO: Stop broadcasting & disconnect.
    //TODO: Stop Playing
    
    self.navigationController?.popViewController(animated: true);
  }
  
  @IBAction func addMusicButtonPressed(_ sender: UIButton) {
  }
  
  //MARK: Playback Controls
  @IBAction func backwardPlaybackButtonPressed(_ sender: UIButton) {
  }
  
  @IBAction func togglePlaybackButtonPressed(_ sender: UIButton) {
  }
  
  @IBAction func forwardPlaybackButtonPressed(_ sender: UIButton) {
  }
}
