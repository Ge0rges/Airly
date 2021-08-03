//
//  AppDelegate.swift
//  Airly
//
//  Created by Georges Kanaan on 15/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import UIKit
import StoreKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

	public static let AppDelegateDidBecomeActive = NSNotification.Name(rawValue: "AppDelegateBecameActive");
	public static let AppDelegateDidBackground = NSNotification.Name(rawValue: "AppDelegateBackgrounded");

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    // Override point for customization after application launch.
    // Ask review after 2 usages
    let launchesSinceReview: Int = UserDefaults.standard.integer(forKey: "launchesSinceLastReview");
    if launchesSinceReview >= 2 {
      if #available(iOS 10.3, *) {
        SKStoreReviewController.requestReview();
      }
      
      UserDefaults.standard.set(0, forKey: "launchesSinceLastReview");
      
    } else {
      UserDefaults.standard.set(launchesSinceReview+1, forKey: "launchesSinceLastReview");
    }
		
		UIApplication.shared.isIdleTimerDisabled = true;
    
    return true
  }

  func applicationWillResignActive(_ application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
		NotificationCenter.default.post(name: AppDelegate.AppDelegateDidBackground, object: self);
  }

  func applicationDidEnterBackground(_ application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
		NotificationCenter.default.post(name: AppDelegate.AppDelegateDidBackground, object: self);
  }

  func applicationWillEnterForeground(_ application: UIApplication) {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
  }

  func applicationDidBecomeActive(_ application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
		
		NotificationCenter.default.post(name: AppDelegate.AppDelegateDidBecomeActive, object: self);
  }

  func applicationWillTerminate(_ application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }
  
}
