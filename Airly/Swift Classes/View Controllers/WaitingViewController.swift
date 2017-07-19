//
//  WaitingViewController.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import UIKit
import Flurry_iOS_SDK

class WaitingViewController: UIViewController, ConnectivityManagerDelegate, FlurryAdBannerDelegate {
  @IBOutlet var backButton: UIButton!
  @IBOutlet var pingImageView: UIImageView!
  
  let synaction: Synaction = Synaction.sharedManager();
  
  override func viewDidLoad() {
    super.viewDidLoad();
    
    // Set the delegate
    self.synaction.connectivityManager.delegate = self;
    
    // Start looking for a host
    self.synaction.connectivityManager.startBrowsingForBonjourBroadcast();
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated);
    
    // Flurry log time spent waiting
    DispatchQueue.main.async {
      Flurry.logEvent("listenerWaiting", timed: true);
    }
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated);
    
//    // Show ad banner at the bottom of the waiting screen
//    DispatchQueue.main.async {
//      let adBanner: FlurryAdBanner = FlurryAdBanner.init(space: "AIRLY_WAITING_SCREEN_BOTTOM_BANNER");
//      adBanner.adDelegate = self;
//
//      adBanner.fetchAndDisplayAd(in: self.view, viewControllerForPresentation: self);
//    }
  }
  
  //MARK: - Button Actions
  @IBAction func dismissBroadcastViewController(_ sender: UIButton) {// Called when user presses back.
    // Stop broadcasting
    self.synaction.connectivityManager.stopBonjour();
    
    // Dismiss
    self.navigationController?.popViewController(animated: true);
    
    // End log
    DispatchQueue.main.async {
      Flurry.endTimedEvent("listenerWaiting", withParameters: ["canceled": true]);
    }
  }
  
  //MARK: - ConnectivityManagerDelegate
  func socket(_ socket: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
		// Dismiss ourself
		self.navigationController?.popToRootViewController(animated: false);
		
    // Show receiver view controller
    self.performSegue(withIdentifier: "showReceiverSegue", sender: self);
    
    // End log
    DispatchQueue.main.async {
      Flurry.endTimedEvent("listenerWaiting", withParameters: ["canceled": false]);
    }
  }
  
//  //MARK: - Ad Delegate
//  func adBanner(_ bannerAd: FlurryAdBanner!, adError: FlurryAdError, errorDescription: Error!) {
//    print("Error fetching ad: \(adError)");
//  }
//
//  func adBannerDidFetchAd(_ bannerAd: FlurryAdBanner!) {
//    print("Fetched ad");
//  }
//
//  func adBannerDidRender(_ bannerAd: FlurryAdBanner!) {
//    print("Rendered Ad");
//  }
}
