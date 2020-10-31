//
//  AppDelegate.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 10/18/20.
//

import UIKit
import AVFoundation

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureSDK()
        
//        do {
//            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: [.mixWithOthers])
//            try AVAudioSession.sharedInstance().setActive(true)
//        } catch {
//            print(error.localizedDescription)
//        }
        return true
    }
    
    func configureSDK() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        PHSPersistence.setStorageLocation(documentsPath, andDeviceId: "001122334455")
        PHSLog.setConsoleLogLevel(.error)
    }
    
    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}
