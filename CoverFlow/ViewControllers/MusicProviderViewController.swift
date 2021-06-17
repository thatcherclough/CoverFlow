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
        checkAPI { (online) in
            if !online {
                DispatchQueue.main.async {
                    if self.presentedViewController == nil {
                        let alert = UIAlertController(title: "Error", message: "The CoverFlow API is not online. Try again later.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            } else {
                if self.appleMusicController == nil {
                    self.appleMusicController = AppleMusicController()
                }
                
                self.requestLibraryAccess()
            }
        }
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
        self.checkAPI { (online) in
            if !online {
                DispatchQueue.main.async {
                    if self.presentedViewController == nil {
                        let alert = UIAlertController(title: "Error", message: "The CoverFlow API is not online. Try again later.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    if self.spotifyController == nil {
                        self.spotifyController = SpotifyController(clientID: self.keys.spotifyClientID, redirectURI: URL(string: self.keys.spotifyRedirectUri)!)
                    }
                    
                    self.spotifyController.connect()
                }
            }
        }
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
            
            self.checkAPI { (online) in
                if !online {
                    DispatchQueue.main.async {
                        if self.presentedViewController == nil {
                            let alert = UIAlertController(title: "Error", message: "The CoverFlow API is not online. Try again later.", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                    }
                }
            }
        }
    }
    
    func checkAPI(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(keys.apiBaseUrl)/api") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return completion(false)
            }
            if let responseCode = response as? HTTPURLResponse {
                if responseCode.statusCode == 200 {
                    return completion(true)
                } else {
                    return completion(false)
                }
            }
        }
        task.resume()
    }
}
