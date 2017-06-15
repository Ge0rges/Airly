//
//  ReceiverViewController.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import UIKit

class ReceiverViewController: UIViewController {
  
  @IBOutlet var backButton: UIButton!
  @IBOutlet var hostLabel: UILabel!
  @IBOutlet var albumArtImageView: UIImageView!
  @IBOutlet var songNameLabel: UILabel!
  @IBOutlet var songArtistLabel: UILabel!
  
  //MARK: - Button Actions
  @IBAction func dismissBroadcastViewController(_ sender: UIButton) {
    //TODO: Stop broadcasting & disconnect.
    //TODO: Stop Playing
    
    self.navigationController?.popViewController(animated: true);
  }
}
