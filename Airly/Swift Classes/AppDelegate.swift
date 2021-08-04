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
        
    public static let AppDelegateDidBecomeActive = NSNotification.Name(rawValue: "AppDelegateBecameActive")
    public static let AppDelegateDidBackground = NSNotification.Name(rawValue: "AppDelegateBackgrounded")
    
    private let SpotifyClientID = "9e006a8cd8b943a28a7539c5a631f05e"
    private let SpotifyRedirectURI = URL(string: "airly://spotify-login-callback")!
    
    var window: UIWindow?
    
    public var access_token = ""
    
    lazy var configuration: SPTConfiguration = {
        let configuration = SPTConfiguration(clientID: SpotifyClientID, redirectURL: SpotifyRedirectURI)
        // Set the playURI to a non-nil value so that Spotify plays music after authenticating and App Remote can connect
        // otherwise another app switch will be required
        configuration.playURI = ""

        // Set these url's to your backend which contains the secret to exchange for an access token
        // You can use the provided ruby script spotify_token_swap.rb for testing purposes
        configuration.tokenSwapURL = URL(string: "https://gkanaan.com:90/swap")
        configuration.tokenRefreshURL = URL(string: "https://gkanaan.com:90/refresh")
        return configuration
    }()
    
    lazy var appRemote: SPTAppRemote = {
        let appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        return appRemote
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        // Ask review after 2 usages
        let launchesSinceReview: Int = UserDefaults.standard.integer(forKey: "launchesSinceLastReview")
        if launchesSinceReview >= 2 {
            if #available(iOS 10.3, *) {
                SKStoreReviewController.requestReview()
            }
            
            UserDefaults.standard.set(0, forKey: "launchesSinceLastReview")
            
        } else {
            UserDefaults.standard.set(launchesSinceReview+1, forKey: "launchesSinceLastReview")
        }
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        let parameters = appRemote.authorizationParameters(from: url)
        if let access_token = parameters?[SPTAppRemoteAccessTokenKey] {
            appRemote.connectionParameters.accessToken = access_token
            self.access_token = access_token
            
        } else if let error_description = parameters?[SPTAppRemoteErrorDescriptionKey] {
            print(error_description)
        }
        
        return true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        NotificationCenter.default.post(name: AppDelegate.AppDelegateDidBackground, object: self)
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        NotificationCenter.default.post(name: AppDelegate.AppDelegateDidBackground, object: self)
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        NotificationCenter.default.post(name: AppDelegate.AppDelegateDidBecomeActive, object: self)
        
        // Connect spotify
        if let _ = self.appRemote.connectionParameters.accessToken {
            self.appRemote.connect()
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        
        // Give up spotify connection
        if (self.appRemote.isConnected) {
            self.appRemote.disconnect()
        }
    }
}
