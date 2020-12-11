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
    
    // MARK: Variables, IBOutlets, and IBActions
    
    let keys = CoverFlowKeys()
    var mainViewController: MainViewController!
    
    @IBOutlet var header: UILabel!
    @IBOutlet var headerConstraint: NSLayoutConstraint!
    
    @IBAction func appleMusicButtonAction(_ sender: Any) {
        MainViewController.musicProvider = "appleMusic"
        if MainViewController.appleMusicController == nil {
            MainViewController.appleMusicController = AppleMusicController(apiKey: keys.appleMusicAPIKey1)
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
    
    @IBAction func spotifyButtonAction(_ sender: Any) {
        MainViewController.musicProvider = "spotify"
        
        if MainViewController.spotifyController == nil {
            MainViewController.spotifyController = SpotifyController(clientID: keys.spotifyClientID, clientSecret: keys.spotifyClientSecret, redirectURI: URL(string: "coverflow://spotify-login-callback")!)
        }
        MainViewController.spotifyController.connect()
    }
    
    // MARK: View Related
    
    public override func viewDidLoad() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.applicationEnteredForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
        
        if view.bounds.width < 370 {
            header.font = header.font.withSize(30)
            headerConstraint.constant = 40
        }
    }
    
    @objc func applicationEnteredForeground(notification: NSNotification) {
        if MainViewController.musicProvider == "spotify" && MainViewController.spotifyController != nil {
            let accessCode = MainViewController.spotifyController.getAccessCodeFromReturnedURL()
            if accessCode != nil {
                MainViewController.spotifyController.getAccessAndRefreshTokens(accessCode: accessCode!)
                UserDefaults.standard.set("spotify", forKey: "musicProvider")
                self.dismiss(animated: true, completion: {
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
}
