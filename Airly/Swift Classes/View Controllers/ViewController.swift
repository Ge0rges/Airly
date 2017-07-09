//
//  ViewController.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import UIKit
import Flurry_iOS_SDK

class ViewController: UIViewController, UIGestureRecognizerDelegate {
  
  @IBOutlet var subtitleLabel: UILabel!
  @IBOutlet var broadcastLabel: UILabel!
  @IBOutlet var receiveLabel: UILabel!
  @IBOutlet var orLabel: UILabel!
  @IBOutlet var broadcastImageView: UIImageView!
  @IBOutlet var receiveImageview: UIImageView!
  @IBOutlet var getStartedButton: UIButton!
  
  override func viewDidLoad() {
    super.viewDidLoad();
    
    // Flurry log page views
    DispatchQueue.main.async {
      Flurry.logAllPageViews(forTarget: self.navigationController);
    };
  }
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated);
		
		// Enable slide to back
		self.navigationController!.interactivePopGestureRecognizer?.isEnabled = true;
		self.navigationController!.interactivePopGestureRecognizer?.delegate = self;
	}
	
	func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		return true;
	}
	
  @IBAction func getStartedPressed(_ sender: UIButton) {// Animate view change
    // Tell autolayout to fuck off
    self.broadcastImageView.translatesAutoresizingMaskIntoConstraints = true;
    self.receiveImageview.translatesAutoresizingMaskIntoConstraints = true;
    
    // Animate
    UIView.animate(withDuration: 0.3
			, animations: {
      // Calculate Image View positions
      let width = self.view.frame.width/3;
      let height = width;
      let x = self.view.frame.width/2 - width/2;
      let yBroadcast = self.view.frame.height/2 - height;
      let yReceive = self.view.frame.height - yBroadcast;
      
      // Animate the image views
      self.broadcastImageView.frame = CGRect(x: x, y: yBroadcast, width: width, height: height);
      self.receiveImageview.frame = CGRect(x: x, y: yReceive, width: width, height: height);
      
			// Hide everything else
			self.orLabel.isHidden = true;
			self.broadcastLabel.isHidden = true;
			self.receiveLabel.isHidden = true;
			self.getStartedButton.isHidden = true;
			self.subtitleLabel.isHidden = true;
			
    }, completion: { (finished) in
      // Enable user interaction on the images
      self.broadcastImageView.isUserInteractionEnabled = true;
      self.receiveImageview.isUserInteractionEnabled = true;
      
      // Accessibility traits
      self.broadcastImageView.accessibilityTraits = UIAccessibilityTraitButton;
      self.receiveImageview.accessibilityTraits = UIAccessibilityTraitButton;
      
      // Update the image view images to higher resolution
      self.broadcastImageView.image = UIImage.init(named: "Big Broadcast");
      self.receiveImageview.image = UIImage.init(named: "Big Receive");
    })
  }
}

