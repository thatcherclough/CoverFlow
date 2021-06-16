//
//  MainViewController.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 12/3/20.
//

import Foundation
import UIKit
import AnimatedGradientView
import Keys
import MediaPlayer
import Reachability
import ColorThiefSwift

class MainViewController: UIViewController {
    
    // MARK: Variables, IBOutlets, and IBActions
    
    let apiBaseURL = "http://192.168.86.31:5000"
    
    let keys = CoverFlowKeys()
    var canPushNotifications: Bool = false
    var appleMusicController: AppleMusicController!
    var spotifyController: SpotifyController!
    
    var currentColors: [UIColor] = []
    var currentLightsStates: [String: PHSLightState] = [:]
    var bridge: PHSBridge! = nil
    static var bridgeInfo: BridgeInfo! = nil
    
    var settings: SettingsViewController!
    var settingsNav: UINavigationController!
    var animatedGradient: AnimatedGradientView!
    let defaultHexes: [String] = ["f64f59", "c471ed", "12c2e9"]
    
    static var musicProvider: String! = UserDefaults.standard.string(forKey: "musicProvider")
    static var authenticated: Bool = false
    static var allLights: [String] = []
    static var selectedLights: [String] = []
    
    @IBOutlet var label: UILabel!
    
    @IBOutlet var startButton: TransparentTextButton!
    @IBAction func startButtonAction(_ sender: Any) {
        checkPermissions()
        
        if !MainViewController.authenticated {
            alert(title: "Error", body: "Please connect to a bridge in settings before continuing.")
        } else {
            startButton.isEnabled = false
            if startButton.titleLabel?.text == "Start" {
                checkAPI { (online) in
                    if online {
                        DispatchQueue.main.async {
                            self.startButton.setTitle("Starting...", alpha: 0.9)
                        }
                        
                        DispatchQueue.global(qos: .background).async {
                            self.getCurrentLightsStates()
                            self.start()
                            self.startBackgrounding()
                        }
                    } else {
                        DispatchQueue.main.async {
                        self.alert(title: "Error", body: "The CoverFlow API is not online. Try again later.")
                        self.startButton.isEnabled = true
                        }
                    }
                }
            } else {
                stop()
                setCurrentLightsStates()
                currentColors.removeAll()
                
                DispatchQueue.main.async {
                    self.startButton.isEnabled = true
                }
            }
        }
    }
    
    @IBOutlet var settingsButton: TransparentTextButton!
    @IBAction func settingsButtonAction(_ sender: Any) {
        DispatchQueue.main.async {
            if self.startButton.titleLabel?.text != "Start" {
                self.alert(title: "Notice", body: "You must stop CoverFlow before accessing settings.")
            } else {
                self.settings.delegate = self
                self.settingsNav.isModalInPresentation = true
                self.present(self.settingsNav, animated: true, completion: nil)
            }
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    // MARK: View Related
    
    public override func viewDidLoad() {
        if view.bounds.width < 370 {
            label.font = label.font.withSize(60)
        }
        
        settingsNav = storyboard?.instantiateViewController(withIdentifier: "SettingsViewController") as? UINavigationController
        settings = settingsNav.viewControllers.first as? SettingsViewController
        settings.loadViewIfNeeded()
        
        resetBackground()
        
        startButton.setTitle("Start", alpha: 0.9)
        startButton.layer.cornerRadius = 10
        startButton.clipsToBounds = true
        
        settingsButton.setTitle("Settings", alpha: 0.9)
        settingsButton.layer.cornerRadius = 10
        settingsButton.clipsToBounds = true
        
        observeReachability()
        
        NotificationCenter.default.addObserver(self, selector:#selector(appMovedToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        if MainViewController.musicProvider == "appleMusic" && appleMusicController == nil {
            appleMusicController = AppleMusicController()
        } else if MainViewController.musicProvider == "spotify" && spotifyController == nil {
            spotifyController = SpotifyController(clientID: keys.spotifyClientID, clientSecret: keys.spotifyClientSecret, redirectURI: URL(string: "coverflow://spotify-login-callback")!)
        }
        
        checkPermissionsAndSetupHue()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        checkPermissions()
        
        if MainViewController.musicProvider == nil {
            presentMusicProvider(alert: nil)
        } else {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if error == nil {
                    self.canPushNotifications = granted
                }
            }
        }
    }
    
    func resetBackground() {
        DispatchQueue.main.async {
            if self.animatedGradient != nil && self.animatedGradient.superview != nil {
                self.animatedGradient.removeFromSuperview()
            }
            self.animatedGradient = AnimatedGradientView(frame: self.view.bounds)
            self.animatedGradient.animationDuration = 3
            self.animatedGradient.autoRepeat = true
            self.animatedGradient.colorStrings = [self.defaultHexes]
            self.view.addSubview(self.animatedGradient)
            self.view.sendSubviewToBack(self.animatedGradient)
        }
    }
    
    func updateBackground() {
        if !currentColors.isEmpty && animatedGradient != nil {
            DispatchQueue.main.async {
                self.animatedGradient.animationValues =
                    [
                        (colors: [self.nextHex(), self.nextHex()], .upRight, .axial),
                        (colors: [self.nextHex(), self.nextHex()], .downRight, .axial),
                        (colors: [self.nextHex(), self.nextHex()], .downLeft, .axial),
                        (colors: [self.nextHex(), self.nextHex()], .upLeft, .axial)
                    ]
                self.animatedGradient.startAnimating()
            }
        }
    }
    
    var hexIndex: Int = 0
    func nextHex() -> String {
        hexIndex += 1
        if hexIndex >= currentColors.count {
            hexIndex = 0
        }
        
        if let hex = currentColors[hexIndex].hexa {
            return hex
        } else {
            return "nil"
        }
    }
    
    func checkPermissions() {
        if MainViewController.musicProvider == "appleMusic" {
            MPMediaLibrary.requestAuthorization { authorizationStatus in
                if authorizationStatus != .authorized && self.presentedViewController as? MusicProviderViewController == nil {
                    self.stop()
                    
                    let alert = UIAlertController(title: "Error", message: "Apple Music access has been revoked. Try connecting again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                    self.presentMusicProvider(alert: alert)
                }
            }
        } else if MainViewController.musicProvider == "spotify" && ((spotifyController == nil || (spotifyController != nil && spotifyController.refreshToken == "N/A")) && presentedViewController as? MusicProviderViewController == nil) {
            self.stop()
            
            let alert = UIAlertController(title: "Error", message: "Spotify access has been revoked. Try connecting again.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
            presentMusicProvider(alert: alert)
        } else if MainViewController.musicProvider == nil && presentedViewController as? MusicProviderViewController == nil {
            presentMusicProvider(alert: nil)
        }
    }
    
    func checkPermissionsAndSetupHue() {
        if MainViewController.musicProvider == "appleMusic" {
            MPMediaLibrary.requestAuthorization { authorizationStatus in
                if authorizationStatus != .authorized && self.presentedViewController as? MusicProviderViewController == nil {
                    self.stop()
                    
                    let alert = UIAlertController(title: "Error", message: "Apple Music access has been revoked. Try connecting again.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                    self.presentMusicProvider(alert: alert)
                } else {
                    self.hueSetup()
                }
            }
        } else if MainViewController.musicProvider == "spotify" && ((spotifyController == nil || (spotifyController != nil && spotifyController.refreshToken == "N/A")) && presentedViewController as? MusicProviderViewController == nil) {
            self.stop()
            
            let alert = UIAlertController(title: "Error", message: "Spotify access has been revoked. Try connecting again.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
            presentMusicProvider(alert: alert)
        } else if MainViewController.musicProvider == nil && presentedViewController as? MusicProviderViewController == nil {
            presentMusicProvider(alert: nil)
        } else {
            hueSetup()
        }
    }
    
    func presentMusicProvider(alert: UIAlertController!) {
        DispatchQueue.main.async {
            if self.presentedViewController as? MusicProviderViewController == nil {
                let musicProvider = self.storyboard?.instantiateViewController(withIdentifier: "MusicProviderViewController") as! MusicProviderViewController
                musicProvider.delegate = self
                musicProvider.isModalInPresentation = true
                self.present(musicProvider, animated: true) {
                    if alert != nil {
                        musicProvider.present(alert, animated: true, completion: nil)
                    }
                    
                    self.appleMusicController = nil
                    self.spotifyController = nil
                    MainViewController.musicProvider = nil
                    UserDefaults.standard.set(nil, forKey: "musicProvider")
                }
            }
        }
    }
    
    func hueSetup() {
        var lastConnectedBridge: BridgeInfo! {
            get {
                if let lastConnectedBridge = PHSKnownBridge.lastConnectedBridge {
                    let lastConnectedBridgeInfo = BridgeInfo(ipAddress: lastConnectedBridge.ipAddress, uniqueId: lastConnectedBridge.uniqueId)
                    return lastConnectedBridgeInfo
                } else {
                    return nil
                }
            }
        }
        
        if lastConnectedBridge != nil && !MainViewController.authenticated {
            MainViewController.bridgeInfo = lastConnectedBridge
            connectFromBridgeInfo()
        }
    }
    
    func connectFromBridgeInfo() {
        DispatchQueue.main.async {
            let connectionAlert = UIAlertController(title: "Connecting to bridge...", message: nil, preferredStyle: .alert)
            if self.presentedViewController != nil {
                self.dismiss(animated: true) {
                    self.present(connectionAlert, animated: true) {
                        self.bridge = self.buildBridge(info: MainViewController.bridgeInfo)
                        self.bridge.connect()
                    }
                }
            } else {
                self.present(connectionAlert, animated: true) {
                    self.bridge = self.buildBridge(info: MainViewController.bridgeInfo)
                    self.bridge.connect()
                }
            }
        }
    }
    
    @objc func appMovedToForeground() {
        if !currentColors.isEmpty && animatedGradient != nil && startButton.titleLabel?.text == "Stop" {
            animatedGradient.startAnimating()
        }
    }
    
    // MARK: API Related
    
    func checkAPI(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(apiBaseURL)/api") else { return }
        
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
    
    // MARK: Bridge Related
    
    func buildBridge(info: BridgeInfo) -> PHSBridge {
        return PHSBridge.init(block: { (builder) in
            builder?.connectionTypes = .local
            builder?.ipAddress = info.ipAddress
            builder?.bridgeID = info.uniqueId
            
            builder?.bridgeConnectionObserver = self
            builder?.add(self)
        }, withAppName: "CoverFlow", withDeviceName: "iDevice")
    }
    
    func getCurrentLightsStates() {
        currentLightsStates.removeAll()
        
        for light in bridge.bridgeState.getDevicesOf(.light) {
            let lightName = (light as! PHSDevice).name!
            
            if MainViewController.selectedLights.contains(lightName) {
                currentLightsStates[lightName] = (light as! PHSLightPoint).lightState
            }
        }
    }
    
    func setCurrentLightsStates() {
        for light in bridge.bridgeState.getDevicesOf(.light) {
            let lightName = (light as! PHSDevice).name!
            
            if currentLightsStates.keys.contains(lightName) {
                let lightPoint = light as! PHSLightPoint
                
                lightPoint.update(currentLightsStates[lightName], allowedConnectionTypes: .local) { (responses, errors, returnCode) in
                    if errors != nil && errors!.count > 0 {
                        var errorText = "Could not restore light state."
                        for generalError in errors! {
                            if let error = generalError as? PHSClipError {
                                errorText += " " + error.errorDescription + "."
                            }
                        }
                        if !errorText.contains("Device is set to off") {
                            self.alertAndNotify(title: "Error", body: errorText)
                        }
                    }
                }
            }
        }
    }
    
    var timer: Timer!
    var notifyAboutNothingPlaying: Bool = true
    func start() {
        if MainViewController.musicProvider == "appleMusic" {
            var currentColorIndex: Int = 0
            var albumAndArtist = appleMusicController.getCurrentAlbumName() + appleMusicController.getCurrentArtistName()
            let wait = settings.colorDuration + settings.transitionDuration
            
            getCoverImageAndSetCurrentSongHues()
            
            DispatchQueue.main.async {
                self.timer = Timer.scheduledTimer(withTimeInterval: wait, repeats: true) { (timer) in
                    if !self.currentColors.isEmpty && self.currentColors.count > currentColorIndex {
                        for light in self.bridge.bridgeState.getDevicesOf(.light) {
                            if MainViewController.selectedLights.contains((light as! PHSDevice).name) {
                                if let lightPoint: PHSLightPoint = light as? PHSLightPoint {
                                    let lightState = PHSLightState()
                                    
                                    let index = self.settings.randomizeColorSwitch.isOn ? Int.random(in: 0..<self.currentColors.count) : currentColorIndex
                                    if self.settings.brightness == 0 {
                                        lightState.on = false
                                    } else {
                                        lightState.on = true
                                        lightState.hue = self.currentColors[index].hsba.h * 360 * 182 as NSNumber
                                        lightState.saturation = self.currentColors[index].hsba.s * 254 as NSNumber
                                        lightState.brightness = NSNumber(value: self.settings.brightness)
                                        lightState.transitionTime = NSNumber(value: self.settings.transitionDuration * 10)
                                    }
                                    lightPoint.update(lightState, allowedConnectionTypes: .local) { (responses, errors, returnCode) in
                                        if errors != nil && errors!.count > 0 {
                                            var errorText = "Could not set light state."
                                            for generalError in errors! {
                                                if let error = generalError as? PHSClipError {
                                                    errorText += " " + error.errorDescription + "."
                                                }
                                            }
                                            self.alertAndNotify(title: "Error", body: errorText)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    let currentAlbumAndArtist = self.appleMusicController.getCurrentAlbumName() + self.appleMusicController.getCurrentArtistName()
                    if currentAlbumAndArtist != albumAndArtist {
                        albumAndArtist = currentAlbumAndArtist
                        self.getCoverImageAndSetCurrentSongHues()
                        currentColorIndex = 0
                        
                        self.playAudio(fileName: "songChange", fileExtension: "mp3")
                        
                        if let alert = self.presentedViewController as? UIAlertController {
                            if alert.message! == "The current song\'s album cover does not have any distinct colors." {
                                alert.dismiss(animated: true, completion: nil)
                            }
                        }
                    } else {
                        currentColorIndex += 1
                        if currentColorIndex >= self.currentColors.count {
                            currentColorIndex = 0
                        }
                    }
                }
                RunLoop.current.add(self.timer, forMode: .default)
                
                if self.startButton.titleLabel?.text == "Starting..." {
                    self.startButton.setTitle("Stop", alpha: 0.9)
                    self.startButton.isEnabled = true
                }
            }
        } else if MainViewController.musicProvider == "spotify" {
            var currentColorIndex: Int = 0
            var albumAndArtist = ""
            let wait = settings.colorDuration + settings.transitionDuration
            
            spotifyController.getCurrentAlbum { (album) in
                if let _ = album["retry"] as? String {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.start()
                    }
                    return
                }
                
                if let error = album["error"] as? String {
                    self.stop()
                    
                    if error == "Invalid access token" {
                        let alert = UIAlertController(title: "Error", message: "Spotify access has been revoked. Try connecting again.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                        self.presentMusicProvider(alert: alert)
                    } else {
                        self.alertAndNotify(title: "Error", body: "\(error).")
                    }
                    return
                }
                
                if let message = album["nothing_playing"] as? String {
                    if self.notifyAboutNothingPlaying {
                        self.alertAndNotify(title: "Notice", body: "\(message).")
                        self.notifyAboutNothingPlaying = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.start()
                    }
                    return
                } else {
                    guard let artists = album["artists"] as? NSArray,
                          let primaryArtist = artists[0] as? [String: Any],
                          let artistName = primaryArtist["name"] as? String,
                          let albumName = album["name"] as? String else {
                        self.stop()
                        self.alertAndNotify(title: "Error", body: "Could not get information on the current song.")
                        return
                    }
                    
                    albumAndArtist = albumName + artistName
                    
                    self.getCoverImageAndSetCurrentSongHues()
                }
                DispatchQueue.main.async {
                    if let alert = self.presentedViewController as? UIAlertController {
                        if alert.message! == "Nothing is playing on Spotify. Start playing something." {
                            alert.dismiss(animated: true, completion: nil)
                        }
                    }
                    
                    self.timer = Timer.scheduledTimer(withTimeInterval: wait, repeats: true) { (timer) in
                        if !self.currentColors.isEmpty && self.currentColors.count > currentColorIndex {
                            for light in self.bridge.bridgeState.getDevicesOf(.light) {
                                if MainViewController.selectedLights.contains((light as! PHSDevice).name) {
                                    if let lightPoint: PHSLightPoint = light as? PHSLightPoint {
                                        let lightState = PHSLightState()
                                        
                                        let index = self.settings.randomizeColorSwitch.isOn ? Int.random(in: 0..<self.currentColors.count) : currentColorIndex
                                        if self.settings.brightness == 0 {
                                            lightState.on = false
                                        } else {
                                            lightState.on = true
                                            lightState.hue = self.currentColors[index].hsba.h * 360 * 182 as NSNumber
                                            lightState.saturation = self.currentColors[index].hsba.s * 254 as NSNumber
                                            lightState.brightness = NSNumber(value: self.settings.brightness)
                                            lightState.transitionTime = NSNumber(value: self.settings.transitionDuration * 10)
                                        }
                                        lightPoint.update(lightState, allowedConnectionTypes: .local) { (responses, errors, returnCode) in
                                            if errors != nil && errors!.count > 0 {
                                                var errorText = "Could not set light state."
                                                for generalError in errors! {
                                                    if let error = generalError as? PHSClipError {
                                                        errorText += " " + error.errorDescription + "."
                                                    }
                                                }
                                                self.alertAndNotify(title: "Error", body: errorText)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        self.spotifyController.getCurrentAlbum { (album) in
                            if let _ = album["retry"] as? String {
                                self.timer.invalidate()
                                self.start()
                                return
                            }
                            
                            if let error = album["error"] as? String {
                                self.stop()
                                
                                if error == "Invalid access token" {
                                    let alert = UIAlertController(title: "Error", message: "Spotify access has been revoked. Try connecting again.", preferredStyle: .alert)
                                    alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                                    self.presentMusicProvider(alert: alert)
                                } else {
                                    self.alertAndNotify(title: "Error", body: "\(error).")
                                }
                                return
                            }
                            
                            if let message = album["nothing_playing"] as? String {
                                self.alertAndNotify(title: "Notice", body: "\(message).")
                                self.notifyAboutNothingPlaying = false
                                self.timer.invalidate()
                                self.start()
                                return
                            } else {
                                guard let artists = album["artists"] as? NSArray,
                                      let primaryArtist = artists[0] as? [String: Any],
                                      let artistName = primaryArtist["name"] as? String,
                                      let albumName = album["name"] as? String else {
                                    self.stop()
                                    self.alertAndNotify(title: "Error", body: "Could not get information on the current song.")
                                    return
                                }
                                
                                let currentAlbumAndArtist = albumName + artistName
                                if currentAlbumAndArtist != albumAndArtist {
                                    albumAndArtist = currentAlbumAndArtist
                                    self.getCoverImageAndSetCurrentSongHues()
                                    currentColorIndex = 0
                                    
                                    self.playAudio(fileName: "songChange", fileExtension: "mp3")
                                    
                                    DispatchQueue.main.async {
                                        if let alert = self.presentedViewController as? UIAlertController {
                                            if alert.message! == "The current song\'s album cover does not have any distinct colors." {
                                                alert.dismiss(animated: true, completion: nil)
                                            }
                                        }
                                    }
                                } else {
                                    currentColorIndex += 1
                                    if currentColorIndex >= self.currentColors.count {
                                        currentColorIndex = 0
                                    }
                                }
                            }
                        }
                        
                    }
                    RunLoop.current.add(self.timer, forMode: .default)
                    
                    if self.startButton.titleLabel?.text == "Starting..." {
                        self.startButton.setTitle("Stop", alpha: 0.9)
                        self.startButton.isEnabled = true
                    }
                }
            }
        }
    }
    
    func getCoverImageAndSetCurrentSongHues() {
        if MainViewController.musicProvider == "appleMusic" {
            let player = MPMusicPlayerController.systemMusicPlayer
            let nowPlaying: MPMediaItem? = player.nowPlayingItem
            let albumArt = nowPlaying?.artwork
            let albumName = nowPlaying?.albumTitle
            let artistName = (nowPlaying?.albumArtist != nil) ? nowPlaying?.albumArtist : nowPlaying?.artist
            
            if nowPlaying != nil {
                if let image = albumArt?.image(at: CGSize(width: 200, height: 200)) {
                    setCurrentSongHues(image: image)
                } else {
                    if albumName != nil && artistName != nil {
                        appleMusicController.getCoverFromAPI(albumName: albumName!, artistName: artistName!) { (url) in
                            if url != nil {
                                self.getData(from: URL(string: url!)!) { data, response, error in
                                    if data == nil || error != nil {
                                        self.alertAndNotify(title: "Error", body: "Could not download the current song's album cover.")
                                        return
                                    }
                                    
                                    DispatchQueue.main.async {
                                        let image = UIImage(data: data!)
                                        self.setCurrentSongHues(image: image!)
                                        return
                                    }
                                }
                            } else {
                                self.alertAndNotify(title: "Error", body: "Could not get the current song's album cover. The Apple Music API did not return a URL.")
                            }
                        }
                    } else {
                        alertAndNotify(title: "Error", body: "Could not get the current song's album cover. Album name or artist is nil.")
                    }
                }
            } else {
                alertAndNotify(title: "Error", body: "Could not get the current song's album cover. Now playing item is nil.")
            }
        } else if MainViewController.musicProvider == "spotify" {
            spotifyController.getCurrentAlbum() { (album) in
                if let images = album["images"] as? NSArray {
                    if let image = images[0] as? [String: Any] {
                        if let url = image["url"] {
                            self.getData(from: URL(string: url as! String)!) { data, response, error in
                                if data == nil || error != nil {
                                    self.alertAndNotify(title: "Error", body: "Could not download the current song's album cover.")
                                    return
                                }
                                
                                DispatchQueue.main.async {
                                    let image = UIImage(data: data!)
                                    self.setCurrentSongHues(image: image!)
                                    return
                                }
                            }
                        } else {
                            self.alertAndNotify(title: "Error", body: "Could not get the current song's album cover. The Spotify API did not return a URL.")
                        }
                    } else {
                        self.alertAndNotify(title: "Error", body: "Could not get the current song's album cover.")
                    }
                } else {
                    self.alertAndNotify(title: "Error", body: "Could not get the current song's album cover.")
                }
            }
        }
    }
    
    func getData(from url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
    }
    
    func setCurrentSongHues(image: UIImage) {
        guard let colors = ColorThief.getPalette(from: image, colorCount: 4, quality: 5, ignoreWhite: true) else {
            self.alertAndNotify(title: "Notice", body: "Could not extract colors form the current song's album cover.")
            return
        }
        
        var newColors: [UIColor] = []
        for color in colors {
            let uiColor = UIColor(red: CGFloat(color.r), green: CGFloat(color.g), blue: CGFloat(color.b), alpha: 1)
            let hue = uiColor.hsba.h
            let saturation = uiColor.hsba.s
            if hue > 0 && saturation > 0.07 {
                let newSaturation: CGFloat = saturation > 0.2 ? 1.0 : 0.7
                let newUIColor = UIColor(hue: hue, saturation: newSaturation, brightness: 0.7, alpha: 1)
                newColors.append(newUIColor)
            }
        }
        
        if newColors.isEmpty {
            alertAndNotify(title: "Notice", body: "The current song's album cover does not have any distinct colors.")
        } else {
            if newColors.count > settings.maximumColors {
                newColors = Array(newColors[0..<Int(settings.maximumColors)])
            }
            currentColors = newColors
            updateBackground()
        }
    }
    
    func stop() {
        if timer != nil {
            timer.invalidate()
        }
        timer = nil
        
        DispatchQueue.main.async {
            self.startButton.setTitle("Start", alpha: 0.9)
            self.startButton.isEnabled = true
            
            self.resetBackground()
        }
        self.stopBackgrounding()
    }
    
    // MARK: Other
    
    var audioPlayer: AVAudioPlayer?
    func playAudio(fileName: String, fileExtension: String) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: fileName, ofType: fileExtension)!))
            if audioPlayer != nil {
                audioPlayer!.volume = 0.025
                audioPlayer!.prepareToPlay()
                audioPlayer!.play()
            } else {
                throw "Error"
            }
        } catch {
            alert(title: "Notice", body: "Could not play sound \"\(fileName).\(fileExtension)\".")
        }
    }
    
    var backgroundPlayer: AVAudioPlayer?
    func startBackgrounding() {
        do {
            backgroundPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "audioCheck", ofType: "mp3")!))
            if backgroundPlayer != nil {
                backgroundPlayer!.numberOfLoops = -1
                backgroundPlayer!.volume = 0.0
                backgroundPlayer!.prepareToPlay()
                backgroundPlayer!.play()
            } else {
                throw "Error"
            }
        } catch {
            alert(title: "Notice", body: "Could not initialize background mode.")
        }
        
        var backgroundTask = UIBackgroundTaskIdentifier(rawValue: 0)
        backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            UIApplication.shared.endBackgroundTask(backgroundTask)
        })
    }
    
    func stopBackgrounding() {
        if backgroundPlayer != nil && backgroundPlayer!.isPlaying {
            backgroundPlayer!.stop()
        }
    }
    
    func alertAndNotify(title: String, body: String) {
        alert(title: title, body: body)
        if canPushNotifications {
            pushNotification(title: title, body: body)
        }
    }
    
    func alert(title: String, body: String) {
        DispatchQueue.main.async {
            if self.presentedViewController == nil {
                let alert = UIAlertController(title: title, message: body, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    func pushNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }
    
    private var reachability : Reachability!
    func observeReachability() {
        do {
            reachability = try Reachability()
            NotificationCenter.default.addObserver(self, selector:#selector(self.reachabilityChanged), name: NSNotification.Name.reachabilityChanged, object: nil)
            try reachability.startNotifier()
        } catch {
            print("could not initiate connection manager")
        }
    }
    
    var firstDetection: Bool = true
    @objc func reachabilityChanged(note: Notification) {
        if firstDetection {
            firstDetection = false
        } else {
            let connection = (note.object as! Reachability).connection
            if connection == .cellular || connection == .unavailable || connection == .unavailable {
                stop()
                if bridge != nil {
                    bridge.disconnect()
                }
            } else if connection == .wifi {
                hueSetup()
            }
        }
    }
}

extension MainViewController: PHSBridgeConnectionObserver {
    func bridgeConnection(_ bridgeConnection: PHSBridgeConnection!, handle connectionEvent: PHSBridgeConnectionEvent) {
        switch connectionEvent {
        case .couldNotConnect:
            print("could not connect")
            
            if self.presentedViewController != nil {
                self.dismiss(animated: true) {
                    self.alert(title: "Error", body: "Could not connect to the bridge.")
                }
            } else {
                alert(title: "Error", body: "Could not connect to the bridge.")
            }
            
            bridge = nil
            MainViewController.bridgeInfo = nil
            MainViewController.authenticated = false
            break
        case .connected:
            print("connected")
            break
        case .connectionLost:
            print("connection lost")
            
            alertAndNotify(title: "Notice", body: "Lost connection to the bridge.")
            break
        case .connectionRestored:
            print("connection restored")
            
            alertAndNotify(title: "Notice", body: "Restored connection to the bridge.")
            break
        case .disconnected:
            print("disconnected")
            
            if MainViewController.authenticated {
                alert(title: "Notice", body: "Disconnected from the bridge.")
            }
            
            MainViewController.bridgeInfo = nil
            bridge = nil
            MainViewController.authenticated = false
            
            settings.bridgeCell.detailTextLabel?.text = "Not connected"
            settings.lightsCell.detailTextLabel?.text = "None selected"
            MainViewController.selectedLights.removeAll()
            MainViewController.allLights.removeAll()
            startButton.setTitle("Start", alpha: 0.9)
            settings.tableView.reloadData()
            break
        case .notAuthenticated:
            print("not authenticated")
            
            MainViewController.authenticated = false
            break
        case .linkButtonNotPressed:
            print("button not pressed")
            
            if self.presentedViewController as? UIAlertController != nil {
                self.dismiss(animated: true, completion: nil)
            }
            
            if self.presentedViewController as? PushButtonViewController == nil {
                let pushButton = self.storyboard?.instantiateViewController(withIdentifier: "PushButtonViewController") as! PushButtonViewController
                pushButton.isModalInPresentation = true
                pushButton.delegate = self
                self.present(pushButton, animated: true, completion: nil)
            }
            break
        case .authenticated:
            print("authenticated")
            break
        default:
            return
        }
    }
    
    func bridgeConnection(_ bridgeConnection: PHSBridgeConnection!, handleErrors connectionErrors: [PHSError]!) {}
}

extension MainViewController: PHSBridgeStateUpdateObserver {
    func bridge(_ bridge: PHSBridge!, handle updateEvent: PHSBridgeStateUpdatedEvent) {
        switch updateEvent {
        case .bridgeConfig:
            print("bridge config")
            break
        case .fullConfig:
            print("full congif")
            break
        case .initialized:
            print("good")
            
            if presentedViewController != nil {
                dismiss(animated: true, completion: nil)
            }
            
            if bridge != nil {
                MainViewController.allLights.removeAll()
                for device in bridge.bridgeState.getDevicesOf(.light) as! [PHSDevice] {
                    MainViewController.allLights.append(device.name!)
                }
            }
            
            MainViewController.authenticated = true
            
            settings.bridgeCell.detailTextLabel?.text = "Connected"
            
            let defaults = UserDefaults.standard
            let lights = defaults.value(forKey: "lights")
            if  lights == nil {
                MainViewController.selectedLights = MainViewController.allLights
                defaults.setValue(MainViewController.selectedLights, forKey: "lights")
            } else if let defaultLights = defaults.value(forKey: "lights") as? [String] {
                MainViewController.selectedLights = defaultLights
            }
            if MainViewController.selectedLights.isEmpty {
                settings.lightsCell.detailTextLabel?.text = "None selected"
            } else {
                settings.lightsCell.detailTextLabel?.text = "\(MainViewController.selectedLights.count) selected"
            }
            settings.tableView.reloadData()
            break
        default:
            return
        }
    }
}

extension MainViewController: MusicProviderViewControllerDelegate {
    func didGetNotificationsSettings(canPushNotifications: Bool) {
        self.canPushNotifications = canPushNotifications
    }
    
    func didGetAppleMusicController(appleMusicController: AppleMusicController) {
        DispatchQueue.main.async {
            UserDefaults.standard.set("appleMusic", forKey: "musicProvider")
            MainViewController.musicProvider = "appleMusic"
            self.appleMusicController = appleMusicController
            self.dismiss(animated: true, completion: {
                self.hueSetup()
            })
        }
    }
    
    func didGetSpotifyController(spotifyController: SpotifyController) {
        DispatchQueue.main.async {
            UserDefaults.standard.set("spotify", forKey: "musicProvider")
            MainViewController.musicProvider = "spotify"
            self.spotifyController = spotifyController
            self.dismiss(animated: true, completion: {
                self.hueSetup()
            })
        }
    }
}

extension MainViewController: SettingsViewControllerDelegate {
    func didSignOut() {
        dismiss(animated: true) {
            self.presentMusicProvider(alert: nil)
            
            if self.bridge != nil {
                self.bridge.disconnect()
            }
        }
    }
    
    func connectToBridge() {
        if !MainViewController.authenticated || (MainViewController.authenticated && bridge != nil && bridge.bridgeConfiguration.networkConfiguration.ipAddress != MainViewController.bridgeInfo.ipAddress) {
            connectFromBridgeInfo()
        }
    }
}

extension MainViewController: PushButtonViewControllerDelegate {
    func timerDidExpire() {
        bridge.disconnect()
        dismiss(animated: true, completion: nil)
    }
}

public class TransparentTextButton: UIButton {
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        self.addTarget(self, action: #selector(pushDownAnimation(_:)), for: .touchDown)
        self.addTarget(self, action: #selector(pushDownAnimation(_:)), for: .touchDragEnter)
        self.addTarget(self, action: #selector(backUpAnimation(_:)), for: .touchDragExit)
        self.addTarget(self, action: #selector(backUpAnimation(_:)), for: .touchUpInside)
    }
    
    @objc func pushDownAnimation(_ sender: AnyObject) {
        UIView.animate(withDuration: 0.15, animations: {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        })
    }
    
    @objc func backUpAnimation(_ sender: AnyObject) {
        UIView.animate(withDuration: 0.15, animations: {
            self.transform = CGAffineTransform.identity
        })
    }
    
    public func setTitle(_ title: String?, alpha: CGFloat) {
        super.setTitle(title, for: .normal)
        titleLabel?.alpha = 0
        clearColorForTitle(alpha: alpha)
    }
    
    func clearColorForTitle(alpha: CGFloat) {
        let buttonSize = bounds.size
        if let font = titleLabel?.font {
            let attributes = [NSAttributedString.Key.font: font]
            if let textSize = titleLabel?.text?.size(withAttributes: attributes) {
                UIGraphicsBeginImageContextWithOptions(buttonSize, false, UIScreen.main.scale)
                if let ctx = UIGraphicsGetCurrentContext() {
                    ctx.setFillColor(UIColor.white.cgColor)
                    ctx.setAlpha(alpha)
                    
                    let center = CGPoint(x: buttonSize.width / 2 - textSize.width / 2, y: buttonSize.height / 2 - textSize.height / 2)
                    let path = UIBezierPath(rect: CGRect(x: 0, y: 0, width: buttonSize.width, height: buttonSize.height))
                    ctx.addPath(path.cgPath)
                    ctx.fillPath()
                    ctx.setBlendMode(.destinationOut)
                    titleLabel?.text?.draw(at: center, withAttributes: [NSAttributedString.Key.font: font])
                    if let viewImage = UIGraphicsGetImageFromCurrentImageContext() {
                        UIGraphicsEndImageContext()
                        let maskLayer = CALayer()
                        maskLayer.contents = ((viewImage.cgImage) as AnyObject)
                        maskLayer.frame = bounds
                        layer.mask = maskLayer
                    }
                }
            }
        }
    }
}

extension PHSKnownBridge {
    class var lastConnectedBridge: PHSKnownBridge? {
        get {
            let knownBridges: [PHSKnownBridge] = PHSKnownBridges.getAll()
            let sortedKnownBridges: [PHSKnownBridge] = knownBridges.sorted { (bridge1, bridge2) -> Bool in
                return bridge1.lastConnected < bridge2.lastConnected
            }
            return sortedKnownBridges.first
        }
    }
}

extension UIColor {
    var hsba:(h: CGFloat, s: CGFloat,b: CGFloat,a: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        self.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h: h, s: s, b: b, a: a)
    }
    
    var rgb: (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: nil) else { return nil }
        return (r,g,b)
    }
    
    var hexa: String? {
        guard let (r,g,b) = rgb else { return nil }
        return "#" + UInt8(r*255).hexa + UInt8(g*255).hexa + UInt8(b*255).hexa
    }
}

extension UInt8 {
    var hexa: String {
        let value = String(self, radix: 16, uppercase: true)
        return (self < 16 ? "0": "") + value
    }
}

extension String: Error {}
