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

protocol MusicProviderViewControllerDelegate {
    func didGetNotificationsSettings(canPushNotifications: Bool)
    func didGetAppleMusicController(appleMusicController: AppleMusicController)
    func didGetSpotifyController(spotifyController: SpotifyController)
}

public class MusicProviderViewController: UIViewController {
    
    // MARK: Variables, IBOutlets, and IBActions
    
    var delegate: MusicProviderViewControllerDelegate?
    
    let keys = CoverFlowKeys()
    var appleMusicController: AppleMusicController!
    var spotifyController: SpotifyController!
    
    @IBOutlet var header: UILabel!
    @IBOutlet var headerConstraint: NSLayoutConstraint!
    
    @IBAction func appleMusicButtonAction(_ sender: Any) {
        if appleMusicController == nil {
            appleMusicController = AppleMusicController(apiKey: keys.appleMusicAPIKey1)
        }
        
        requestLibraryAccess()
    }
    
    func requestLibraryAccess() {
        MPMediaLibrary.requestAuthorization { authorizationStatus in
            if authorizationStatus == .authorized {
                if self.appleMusicController != nil {
                    self.delegate?.didGetAppleMusicController(appleMusicController: self.appleMusicController)
                }
            } else {
                self.appleMusicController = nil
                
                DispatchQueue.main.async {
                    if self.presentedViewController == nil {
                        let alert = UIAlertController(title: "Notice", message: "Apple Music access is not enabled. Please enable \"Media and Apple Music\" access in settings.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    @IBAction func spotifyButtonAction(_ sender: Any) {
        if spotifyController == nil {
            spotifyController = SpotifyController(clientID: keys.spotifyClientID, clientSecret: keys.spotifyClientSecret, redirectURI: URL(string: "coverflow://spotify-login-callback")!)
        }
        
        spotifyController.connect()
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
        if spotifyController != nil {
            if let accessCode = spotifyController.getAccessCodeFromReturnedURL() {
                spotifyController.getAccessAndRefreshTokens(accessCode: accessCode)
                delegate?.didGetSpotifyController(spotifyController: spotifyController)
            } else {
                DispatchQueue.main.async {
                    self.spotifyController = nil
                    
                    if self.presentedViewController == nil {
                        let alert = UIAlertController(title: "Error", message: "Could not connect to Spotify. Try connecting again.", preferredStyle: .alert)
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
                self.delegate?.didGetNotificationsSettings(canPushNotifications: granted)
            }
        }
    }
}
