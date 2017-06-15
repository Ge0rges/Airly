//
//  WaitingViewController.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import UIKit

class WaitingViewController: UIViewController {
  @IBOutlet var backButton: UIButton!
  @IBOutlet var pingImageView: UIImageView!
  
  override func viewDidLoad() {
    //TODO: Start Broadcasting
    //TODO: Animate Ping
  }
  
  //MARK: - Button Actions
  @IBAction func dismissBroadcastViewController(_ sender: UIButton) {
    //TODO: Stop broadcasting & disconnect.
    //TODO: Stop Playing
    
    self.navigationController?.popViewController(animated: true);
  }
  
  func connectedToHost() {
    //TODO: Show ReceiverViewController. Segue ID: showReceiverSegue
  }
}
