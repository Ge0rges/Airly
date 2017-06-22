////
////  AppleMusicManager.swift
////  Airly
////
////  Created by Georges Kanaan on 22/06/2017.
////  Copyright © 2017 Georges Kanaan. All rights reserved.
////
//
//import StoreKit
//import MediaPlayer
//
//class AppleMusicManager: NSObject {
//	static let sharedManager = AppleMusicManager();
//	override private init() {//This prevents others from using the default '()' initializer for this class
//		super.init();
//	}
//	
//	func appleMusicCheckIfDeviceCanPlayback() {
//		let serviceController = SKCloudServiceController()
//		serviceController.requestCapabilities(completionHandler: { (capability, error) in
//			if #available(iOS 10.1, *) {
//				switch (capability) {
//				case .musicCatalogSubscriptionEligible:
//					print("The user doesn't have an Apple Music subscription available. Now would be a good time to prompt them to buy one?");
//					break;
//					
//				case .musicCatalogPlayback:
//					print("The user has an Apple Music subscription and can playback music!");
//					break;
//					
//				case .addToCloudMusicLibrary:
//					print("The user has an Apple Music subscription, can playback music AND can add to the Cloud Music Library");
//					break;
//					
//				default:
//					break;
//				}
//				
//			} else {
//				switch (capability) {
//				case []:
//					print("The user doesn't have an Apple Music subscription available. Now would be a good time to prompt them to buy one?");
//					break;
//					
//				case .musicCatalogPlayback:
//					print("The user has an Apple Music subscription and can playback music!");
//					break;
//					
//				case .addToCloudMusicLibrary:
//					print("The user has an Apple Music subscription, can playback music AND can add to the Cloud Music Library");
//					break;
//					
//				default:
//					break;
//				}
//			}
//		});
//	}
//	
//	func appleMusicRequestPermission() {
//		switch SKCloudServiceController.authorizationStatus() {
//		case .authorized:
//			print("The user's already authorized - we don't need to do anything more here, so we'll exit early.")
//			return;
//			
//		case .denied:
//			print("The user has selected 'Don't Allow' in the past - so we're going to show them a different dialog to push them through to their Settings page and change their mind, and exit the function early.")
//			// Show an alert to guide users into the Settings
//			return;
//			
//		case .notDetermined:
//			print("The user hasn't decided yet - so we'll break out of the switch and ask them.")
//			break;
//			
//		case .restricted:
//			print("User may be restricted; for example, if the device is in Education mode, it limits external Apple Music usage. This is similar behaviour to Denied.")
//			return;
//		}
//		
//		SKCloudServiceController.requestAuthorization { (status:SKCloudServiceAuthorizationStatus) in
//			switch status {
//			case .authorized:
//				print("All good - the user tapped 'OK', so you're clear to move forward and start playing.")
//				break;
//				
//			case .denied:
//				print("The user tapped 'Don't allow'. Read on about that below...")
//				break;
//				
//			case .notDetermined:
//				print("The user hasn't decided or it's not clear whether they've confirmed or denied.")
//				break;
//				
//			case .restricted:
//				print("User may be restricted; for example, if the device is in Education mode, it limits external Apple Music usage. This is similar behaviour to Denied.");
//				break;
//			}
//		}
//	}
//	
//	func appleMusicFetchStorefrontRegion() {
//		let serviceController = SKCloudServiceController()
//		serviceController.requestStorefrontIdentifier { (storefrontId, error) in
//			guard (error == nil) else {
//				print("An error occured. Handle it here.")
//				return;
//			}
//			
//			guard let storefrontId = storefrontId, storefrontId.characters.count >= 6 else {
//				print("Handle the error - the callback didn't contain a valid storefrontID.")
//				return;
//			}
//			
//			let indexRange = storefrontId.index(storefrontId.startIndex, offsetBy: 5);
//			let trimmedId = storefrontId.substring(to: indexRange);
//			
//			print("Success! The user's storefront ID is: \(trimmedId)");
//		}
//	}
//}
