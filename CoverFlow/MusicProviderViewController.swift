//
//  MusicProviderViewController.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 11/23/20.
//

import Foundation
import UIKit
import Keys
import MediaPlayer

public class MusicProviderViewController: UIViewController {
    
    // MARK: Variables
    
    let keys = CoverFlowKeys()
    var mainViewController: ViewController!
    
    // MARK: View Related
    
    public override func viewDidLoad() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.applicationEnteredForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
    }
    
    @objc func applicationEnteredForeground(notification: NSNotification) {
        if ViewController.musicProvider == "spotify" && ViewController.spotifyController != nil {
            let accessCode = ViewController.spotifyController.getAccessCodeFromReturnedURL()
            if accessCode != nil {
                ViewController.spotifyController.getAccessAndRefreshTokens(accessCode: accessCode!)
                UserDefaults.standard.set("spotify", forKey: "musicProvider")
                self.dismiss(animated: true, completion: {
                    let _ = ProcessInfo.processInfo.hostName
                    
                    self.mainViewController.hueSetup()
                })
            } else {
                DispatchQueue.main.async {
                    if self.presentedViewController == nil {
                        let alert = UIAlertController(title: "Error", message: "Could not connect to Spotify. Try connecting again.", preferredStyle: UIAlertController.Style.alert)
                        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if error == nil {
                self.mainViewController.canPushNotifications = granted
            }
        }
    }
    
    // MARK: Buttons
    
    @IBAction func spotifyButtonAction(_ sender: Any) {
        ViewController.musicProvider = "spotify"
        
        if ViewController.spotifyController == nil {
            ViewController.spotifyController = SpotifyController(clientID: keys.spotifyClientID, clientSecret: keys.spotifyClientSecret, redirectURI: URL(string: "coverflow://spotify-login-callback")!)
        }
        ViewController.spotifyController.connect()
    }
    
    @IBAction func appleMusicButtonAction(_ sender: Any) {
        ViewController.musicProvider = "appleMusic"
        if ViewController.appleMusicController == nil {
            ViewController.appleMusicController = AppleMusicController(apiKey: keys.appleMusicAPIKey1)
        }
        
        requestLibraryAccess()
    }
    
    func requestLibraryAccess() {
        MPMediaLibrary.requestAuthorization { authorizationStatus in
            if authorizationStatus == .authorized {
                DispatchQueue.main.async {
                    UserDefaults.standard.set("appleMusic", forKey: "musicProvider")
                    if self.presentedViewController == nil {
                        self.dismiss(animated: true, completion: {
                            let _ = ProcessInfo.processInfo.hostName
                            
                            self.mainViewController.hueSetup()
                        })
                    }
                }
            } else {
                DispatchQueue.main.async {
                    if self.presentedViewController == nil {
                        let alert = UIAlertController(title: "Notice", message: "Apple Music access is not enabled. Please enable \"Media and Apple Music\" access in settings.", preferredStyle: UIAlertController.Style.alert)
                        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
}
