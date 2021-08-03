//
//  ViewController.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    
    @IBOutlet var subtitleLabel: UILabel!
    @IBOutlet var broadcastLabel: UILabel!
    @IBOutlet var receiveLabel: UILabel!
    @IBOutlet var orLabel: UILabel!
    @IBOutlet var broadcastImageView: UIImageView!
    @IBOutlet var receiveImageview: UIImageView!
    @IBOutlet var getStartedButton: UIButton!
    @IBOutlet var titleLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad();
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
        // Tell AutoLayout to FUCK OFF
        self.view.removeConstraints(self.view.constraints)
        self.broadcastImageView.removeConstraints(self.broadcastImageView.constraints)
        self.receiveImageview.removeConstraints(self.receiveImageview.constraints)
        
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = true
        self.broadcastImageView.translatesAutoresizingMaskIntoConstraints = true
        self.receiveImageview.translatesAutoresizingMaskIntoConstraints = true
        
        // Animate
        UIView.animate(withDuration: 0.3, animations: {
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
            self.broadcastImageView.accessibilityTraits = UIAccessibilityTraits.button;
            self.receiveImageview.accessibilityTraits = UIAccessibilityTraits.button;
            
            // Update the image view images to higher resolution
            self.broadcastImageView.image = UIImage.init(named: "Big Broadcast");
            self.receiveImageview.image = UIImage.init(named: "Big Receive");
            
            // Bye Bye Birdie
            self.orLabel.removeFromSuperview();
            self.broadcastLabel.removeFromSuperview();
            self.receiveLabel.removeFromSuperview();
            self.getStartedButton.removeFromSuperview();
            self.subtitleLabel.removeFromSuperview();
            
        })
    }
}

//extension UIView {
//
//    public func removeAllConstraintsExcept(_ view: AnyObject?) {
//        var _superview = self.superview
//
//        while let superview = _superview {
//            for constraint in superview.constraints {
//                if constraint.firstItem is view || constraint.secondItem is view {
//                    continue
//                }
//
//                if let first = constraint.firstItem as? UIView, first == self {
//                    superview.removeConstraint(constraint)
//                }
//
//                if let second = constraint.secondItem as? UIView, second == self {
//                    superview.removeConstraint(constraint)
//                }
//            }
//
//            _superview = superview.superview
//        }
//
//        self.removeConstraints(self.constraints)
//        self.translatesAutoresizingMaskIntoConstraints = true
//    }
//}
