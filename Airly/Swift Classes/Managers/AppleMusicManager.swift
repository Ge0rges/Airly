//
//  AppleMusicManager.swift
//  Airly
//
//  Created by Georges Kanaan on 22/06/2017.
//  Copyright © 2017 Georges Kanaan. All rights reserved.
//

import StoreKit
import MediaPlayer

class AppleMusicManager: NSObject {
	static let sharedManager = AppleMusicManager();
	override private init() {//This prevents others from using the default '()' initializer for this class
		super.init();
	}
	
	func appleMusicCheckIfDeviceCanPlayback() {
		let serviceController = SKCloudServiceController()
		serviceController.requestCapabilities(completionHandler: { (capability, error) in
			if #available(iOS 10.1, *) {
				switch (capability) {
					case .musicCatalogSubscriptionEligible:
						print("The user doesn't have an Apple Music subscription available. Now would be a good time to prompt them to buy one?")
						break;
					
					case .musicCatalogPlayback:
						print("The user has an Apple Music subscription and can playback music!")
						break;
					
					case .addToCloudMusicLibrary:
						print("The user has an Apple Music subscription, can playback music AND can add to the Cloud Music Library")
						break;
					
					default:
						break;
				}
				
			} else {
				switch (capability) {
					case []:
						print("The user doesn't have an Apple Music subscription available. Now would be a good time to prompt them to buy one?")
						break;
					
					case .musicCatalogPlayback:
						print("The user has an Apple Music subscription and can playback music!")
						break;
					
					case .addToCloudMusicLibrary:
						print("The user has an Apple Music subscription, can playback music AND can add to the Cloud Music Library")
						break;
					
					default:
						break;
				}
			}
		})
	}
}
