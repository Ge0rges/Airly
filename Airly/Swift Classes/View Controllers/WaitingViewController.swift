//
//  WaitingViewController.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import UIKit

class WaitingViewController: UIViewController, ConnectivityManagerDelegate {
  @IBOutlet var backButton: UIButton!
  @IBOutlet var pingImageView: UIImageView!
  
  let synaction: Synaction = Synaction.sharedManager();
  
  override func viewDidLoad() {
    // Set the delegate
    self.synaction.connectivityManager.delegate = self;
    
    // Start looking for a host
    self.synaction.connectivityManager.startBrowsingForBonjourBroadcast();
  }
  
  //MARK: - Button Actions
  @IBAction func dismissBroadcastViewController(_ sender: UIButton) {// Called when user presses back.
    // Stop broadcasting
    self.synaction.connectivityManager.stopBonjour();
    
    // Dismiss
    self.navigationController?.popViewController(animated: true);
  }
  
  //MARK: - ConnectivityManagerDelegate
  func socket(_ socket: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
    // Show receiver view controller
    self.performSegue(withIdentifier: "showReceiverSegue", sender: self);
  }
}
