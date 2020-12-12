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
    
    let keys = CoverFlowKeys()
    var canPushNotifications: Bool = false
    
    static var musicProvider: String! = UserDefaults.standard.string(forKey: "musicProvider")
    static var appleMusicController: AppleMusicController!
    static var spotifyController: SpotifyController!
    
    var currentHues: [NSNumber] = []
    var currentLightsStates: [String: PHSLightState] = [:]
    static var bridge: PHSBridge! = nil
    static var bridgeInfo: BridgeInfo! = nil
    static var authenticated: Bool = false
    static var lights: [String]! = []
    
    var settings: SettingsViewController!
    var settingsNav: UINavigationController!
    var animatedGradient: AnimatedGradientView!
    var hexes: [String] = []
    let defaultHexes: [String] = ["f64f59", "c471ed", "12c2e9"]
    
    @IBOutlet var label: UILabel!
    
    @IBOutlet var startButton: TransparentTextButton!
    @IBAction func startButtonAction(_ sender: Any) {
        checkPermissions()
        
        if !MainViewController.authenticated {
            alert(title: "Error", body: "Please connect to a bridge in settings before continuing.")
        } else {
            startButton.isEnabled = false
            if startButton.titleLabel?.text == "Start" {
                startButton.setTitle("Starting...", alpha: 0.9)
                
                DispatchQueue.global(qos: .background).async {
                    self.getCurrentLightsStates()
                    self.start()
                    self.startBackgrounding()
                }
            } else {
                stop()
                setCurrentLightsStates()
                currentHues.removeAll()
                hexes.removeAll()
                
                DispatchQueue.main.async {
                    self.startButton.isEnabled = true
                }
            }
        }
    }
    
    @IBOutlet var settingsButton: TransparentTextButton!
    @IBAction func settingsButtonAction(_ sender: Any) {
        DispatchQueue.main.async {
            if self.startButton.titleLabel?.text == "Stop" {
                self.alert(title: "Notice", body: "You must stop CoverFlow before accessing settings.")
            } else {
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
        super.viewDidLoad()
        
        if view.bounds.width < 370 {
            label.font = label.font.withSize(60)
        }
        
        settingsNav = self.storyboard?.instantiateViewController(withIdentifier: "SettingsViewController") as? UINavigationController
        settings = settingsNav.viewControllers.first as? SettingsViewController
        settings.mainViewController = self
        settings.loadViewIfNeeded()
        
        resetBackground()
        
        startButton.setTitle("Start", alpha: 0.9)
        startButton.layer.cornerRadius = 10
        startButton.titleLabel?.alpha = 0
        startButton.clipsToBounds = true
        
        settingsButton.setTitle("Settings", alpha: 0.9)
        settingsButton.layer.cornerRadius = 10
        settingsButton.titleLabel?.alpha = 0
        settingsButton.clipsToBounds = true
        
        observeReachability()
        
        NotificationCenter.default.addObserver(self, selector:#selector(appMovedToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        if MainViewController.musicProvider == "appleMusic" && MainViewController.appleMusicController == nil {
            MainViewController.appleMusicController = AppleMusicController(apiKey: keys.appleMusicAPIKey1)
        } else if MainViewController.musicProvider == "spotify" && MainViewController.spotifyController == nil{
            MainViewController.spotifyController = SpotifyController(clientID: keys.spotifyClientID, clientSecret: keys.spotifyClientSecret, redirectURI: URL(string: "coverflow://spotify-login-callback")!)
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
        if !hexes.isEmpty && self.animatedGradient != nil {
            DispatchQueue.main.async {
                self.animatedGradient.animationValues =
                    [
                        (colors: [self.hexes[self.nextHexIndex()], self.hexes[self.nextHexIndex()]], .upRight, .axial),
                        (colors: [self.hexes[self.nextHexIndex()], self.hexes[self.nextHexIndex()]], .downRight, .axial),
                        (colors: [self.hexes[self.nextHexIndex()], self.hexes[self.nextHexIndex()]], .downLeft, .axial),
                        (colors: [self.hexes[self.nextHexIndex()], self.hexes[self.nextHexIndex()]], .upLeft, .axial)
                    ]
                self.animatedGradient.startAnimating()
            }
        }
    }
    
    var hexIndex: Int = 0
    func nextHexIndex() -> Int {
        hexIndex += 1
        if hexIndex >= hexes.count {
            hexIndex = 0
        }
        return hexIndex
    }
    
    func checkPermissions() {
        if MainViewController.musicProvider == "appleMusic" {
            MPMediaLibrary.requestAuthorization { authorizationStatus in
                if authorizationStatus != .authorized && self.presentedViewController as? MusicProviderViewController == nil {
                    self.stop()
                    
                    let alert = UIAlertController(title: "Error", message: "Apple Music access has been revoked. Try connecting again.", preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                    self.presentMusicProvider(alert: alert)
                    
                    MainViewController.musicProvider = nil
                    UserDefaults.standard.set(nil, forKey: "musicProvider")
                }
            }
        } else if MainViewController.musicProvider == "spotify" {
            if MainViewController.spotifyController != nil && MainViewController.spotifyController.refreshToken == "N/A" && self.presentedViewController as? MusicProviderViewController == nil {
                self.stop()
                
                let alert = UIAlertController(title: "Error", message: "Spotify access has been revoked. Try connecting again.", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                presentMusicProvider(alert: alert)
                
                MainViewController.musicProvider = nil
                UserDefaults.standard.set(nil, forKey: "musicProvider")
            }
        }
    }
    
    func checkPermissionsAndSetupHue() {
        if MainViewController.musicProvider == "appleMusic" {
            MPMediaLibrary.requestAuthorization { authorizationStatus in
                if authorizationStatus != .authorized && self.presentedViewController as? MusicProviderViewController == nil {
                    self.stop()
                    
                    let alert = UIAlertController(title: "Error", message: "Apple Music access has been revoked. Try connecting again.", preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                    self.presentMusicProvider(alert: alert)
                    
                    MainViewController.musicProvider = nil
                    UserDefaults.standard.set(nil, forKey: "musicProvider")
                } else {
                    self.hueSetup()
                }
            }
        } else if MainViewController.musicProvider == "spotify" {
            if MainViewController.spotifyController != nil && MainViewController.spotifyController.refreshToken == "N/A" && self.presentedViewController as? MusicProviderViewController == nil {
                self.stop()
                
                let alert = UIAlertController(title: "Error", message: "Spotify access has been revoked. Try connecting again.", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                presentMusicProvider(alert: alert)
                
                MainViewController.musicProvider = nil
                UserDefaults.standard.set(nil, forKey: "musicProvider")
            } else {
                self.hueSetup()
            }
        }
    }
    
    func presentMusicProvider(alert: UIAlertController!) {
        DispatchQueue.main.async {
            let musicProvider = self.storyboard?.instantiateViewController(withIdentifier: "MusicProviderViewController") as! MusicProviderViewController
            musicProvider.mainViewController = self
            musicProvider.isModalInPresentation = true
            self.present(musicProvider, animated: true) {
                if alert != nil {
                    musicProvider.present(alert, animated: true, completion: nil)
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
            if self.presentedViewController != nil {
                self.dismiss(animated: true, completion: nil)
            }
            let connectionAlert = UIAlertController(title: "Connecting to bridge...", message: nil, preferredStyle: UIAlertController.Style.alert)
            self.present(connectionAlert, animated: true) {
                MainViewController.bridge = self.buildBridge(info: MainViewController.bridgeInfo)
                MainViewController.bridge.connect()
            }
        }
    }
    
    @objc func appMovedToForeground() {
        if !hexes.isEmpty && animatedGradient != nil && startButton.titleLabel?.text == "Stop" {
            animatedGradient.startAnimating()
        }
    }
    
    // MARK: Bridge Related
    
    func buildBridge(info: BridgeInfo) -> PHSBridge {
        return PHSBridge.init(block: { (builder) in
            builder?.connectionTypes = .local
            builder?.ipAddress = info.ipAddress
            builder?.bridgeID  = info.uniqueId
            
            builder?.bridgeConnectionObserver = self
            builder?.add(self)
        }, withAppName: "CoverFlow", withDeviceName: "iDevice")
    }
    
    func getCurrentLightsStates() {
        currentLightsStates.removeAll()
        
        for light in MainViewController.bridge.bridgeState.getDevicesOf(.light) {
            let lightName = (light as! PHSDevice).name!
            
            if MainViewController.lights.contains(lightName) {
                currentLightsStates[lightName] = (light as! PHSLightPoint).lightState
            }
        }
    }
    
    func setCurrentLightsStates() {
        for light in MainViewController.bridge.bridgeState.getDevicesOf(.light) {
            let lightName = (light as! PHSDevice).name!
            
            if MainViewController.lights.contains(lightName) && currentLightsStates.keys.contains(lightName) {
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
            var currentHueIndex: Int = 0
            var albumAndArtist = MainViewController.appleMusicController.getCurrentAlbumName() + MainViewController.appleMusicController.getCurrentArtistName()
            let wait = self.settings.colorDuration + self.settings.transitionDuration
            
            getCoverImageAndSetCurrentSongHues()
            
            DispatchQueue.main.async {
                self.timer = Timer.scheduledTimer(withTimeInterval: wait, repeats: true) { (timer) in
                    if wait != (self.settings.colorDuration + self.settings.transitionDuration) {
                        timer.invalidate()
                        self.start()
                    }
                    
                    if !self.currentHues.isEmpty && self.currentHues.count > currentHueIndex {
                        for light in MainViewController.bridge.bridgeState.getDevicesOf(.light) {
                            if MainViewController.lights.contains((light as! PHSDevice).name) {
                                if let lightPoint: PHSLightPoint = light as? PHSLightPoint {
                                    let lightState = PHSLightState()
                                    
                                    let index = self.settings.randomizeColorSwitch.isOn ? Int.random(in: 0..<self.currentHues.count) : currentHueIndex
                                    if self.settings.brightness == 0 {
                                        lightState.on = false
                                    } else {
                                        lightState.on = true
                                        lightState.hue = self.currentHues[index]
                                        lightState.saturation = 254
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
                    
                    if self.backgroundPlayer != nil && !self.backgroundPlayer!.isPlaying {
                        self.startBackgrounding()
                    }
                    
                    let currentAlbumAndArtist = MainViewController.appleMusicController.getCurrentAlbumName() + MainViewController.appleMusicController.getCurrentArtistName()
                    if currentAlbumAndArtist != albumAndArtist {
                        albumAndArtist = currentAlbumAndArtist
                        self.getCoverImageAndSetCurrentSongHues()
                        currentHueIndex = 0
                        
                        self.playAudio(fileName: "songChange", fileExtension: "mp3")
                    } else {
                        currentHueIndex += 1
                        if currentHueIndex >= self.currentHues.count {
                            currentHueIndex = 0
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
            var currentHueIndex: Int = 0
            var albumAndArtist = ""
            let wait = self.settings.colorDuration + self.settings.transitionDuration
            
            MainViewController.spotifyController.getCurrentAlbum { (album) in
                if let _ = album["retry"] as? String {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.start()
                    }
                    return
                }
                
                if let error = album["error"] as? String {
                    self.stop()
                    
                    if error == "Invalid access token" {
                        let alert = UIAlertController(title: "Error", message: "Spotify access has been revoked. Try connecting again.", preferredStyle: UIAlertController.Style.alert)
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
                    self.timer = Timer.scheduledTimer(withTimeInterval: wait, repeats: true) { (timer) in
                        if wait != (self.settings.colorDuration + self.settings.transitionDuration) {
                            timer.invalidate()
                            self.start()
                        }
                        
                        if !self.currentHues.isEmpty && self.currentHues.count > currentHueIndex {
                            for light in MainViewController.bridge.bridgeState.getDevicesOf(.light) {
                                if MainViewController.lights.contains((light as! PHSDevice).name) {
                                    if let lightPoint: PHSLightPoint = light as? PHSLightPoint {
                                        let lightState = PHSLightState()
                                        
                                        let index = self.settings.randomizeColorSwitch.isOn ? Int.random(in: 0..<self.currentHues.count) : currentHueIndex
                                        if self.settings.brightness == 0 {
                                            lightState.on = false
                                        } else {
                                            lightState.on = true
                                            lightState.hue = self.currentHues[index]
                                            lightState.saturation = 254
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
                        
                        if self.backgroundPlayer != nil && !self.backgroundPlayer!.isPlaying {
                            self.startBackgrounding()
                        }
                        
                        MainViewController.spotifyController.getCurrentAlbum { (album) in
                            if let _ = album["retry"] as? String {
                                self.timer.invalidate()
                                self.start()
                                return
                            }
                            
                            if let error = album["error"] as? String {
                                self.stop()
                                
                                if error == "Invalid access token" {
                                    let alert = UIAlertController(title: "Error", message: "Spotify access has been revoked. Try connecting again.", preferredStyle: UIAlertController.Style.alert)
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
                                    currentHueIndex = 0
                                    
                                    self.playAudio(fileName: "songChange", fileExtension: "mp3")
                                } else {
                                    currentHueIndex += 1
                                    if currentHueIndex >= self.currentHues.count {
                                        currentHueIndex = 0
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
                let image = albumArt?.image(at: CGSize(width: 200, height: 200)) ?? nil
                
                if image != nil {
                    setCurrentSongHues(image: image!)
                } else {
                    if albumName != nil && artistName != nil {
                        MainViewController.appleMusicController.getCoverFromAPI(albumName: albumName!, artistName: artistName!) { (url) in
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
            MainViewController.spotifyController.getCurrentAlbum() { (album) in
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
        
        var newHues: [NSNumber] = []
        var newHexes: [String] = []
        for color in colors {
            let uiColor = UIColor(red: CGFloat(color.r), green: CGFloat(color.g), blue: CGFloat(color.b), alpha: 1)
            let hue = uiColor.hsba.h
            let saturation = uiColor.hsba.s
            if hue > 0 && saturation > 0.2 {
                newHues.append((hue * 360 * 182) as NSNumber)
                
                let uiColorFullSaturation = UIColor(hue: hue, saturation: 0.8, brightness: 0.7, alpha: 1)
                if let hex = uiColorFullSaturation.hexa {
                    newHexes.append(hex)
                }
            }
        }
        
        if newHues.isEmpty {
            alertAndNotify(title: "Notice", body: "The current song's album cover does not have any distinct colors.")
        } else {
            currentHues = newHues
        }
        
        if !newHexes.isEmpty {
            hexes = newHexes
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
            let audioFile = URL(fileURLWithPath: Bundle.main.path(forResource: fileName, ofType: fileExtension)!)
            audioPlayer = try AVAudioPlayer(contentsOf: audioFile)
            audioPlayer!.volume = 0.025
            audioPlayer!.prepareToPlay()
            audioPlayer!.play()
        } catch {
            alert(title: "Notice", body: "Could not play sound \"\(fileName).\(fileExtension)\".")
        }
    }
    
    var backgroundPlayer: AVAudioPlayer?
    func startBackgrounding() {
        do {
            let audioCheck = URL(fileURLWithPath: Bundle.main.path(forResource: "audioCheck", ofType: "mp3")!)
            backgroundPlayer = try AVAudioPlayer(contentsOf: audioCheck)
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
            backgroundPlayer?.stop()
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
                let alert = UIAlertController(title: title, message: body, preferredStyle: UIAlertController.Style.alert)
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
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    private var reachability : Reachability!
    func observeReachability() {
        do {
            self.reachability = try Reachability()
            NotificationCenter.default.addObserver(self, selector:#selector(self.reachabilityChanged), name: NSNotification.Name.reachabilityChanged, object: nil)
            try self.reachability.startNotifier()
        }
        catch {
            print("could not initiate connection manager")
        }
    }
    
    var firstDetection: Bool = true
    @objc func reachabilityChanged(note: Notification) {
        if firstDetection {
            firstDetection = false
        } else {
            let reachability = note.object as! Reachability
            let connection = reachability.connection
            
            if connection == .cellular || connection == .unavailable || connection == .unavailable {
                if MainViewController.bridge != nil {
                    MainViewController.bridge.disconnect()
                    
                    stop()
                }
            } else if connection == .wifi {
                hueSetup()
            }
        }
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
        clearColorForTitle(alpha: alpha)
    }
    
    func clearColorForTitle(alpha: CGFloat) {
        let buttonSize = bounds.size
        if let font = titleLabel?.font{
            let attribs = [NSAttributedString.Key.font: font]
            if let textSize = titleLabel?.text?.size(withAttributes: attribs){
                UIGraphicsBeginImageContextWithOptions(buttonSize, false, UIScreen.main.scale)
                
                if let ctx = UIGraphicsGetCurrentContext(){
                    ctx.setFillColor(UIColor.white.cgColor)
                    ctx.setAlpha(alpha)
                    
                    let center = CGPoint(x: buttonSize.width / 2 - textSize.width / 2, y: buttonSize.height / 2 - textSize.height / 2)
                    let path = UIBezierPath(rect: CGRect(x: 0, y: 0, width: buttonSize.width, height: buttonSize.height))
                    ctx.addPath(path.cgPath)
                    ctx.fillPath()
                    ctx.setBlendMode(.destinationOut)
                    
                    titleLabel?.text?.draw(at: center, withAttributes: [NSAttributedString.Key.font: font])
                    
                    if let viewImage = UIGraphicsGetImageFromCurrentImageContext(){
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
            
            MainViewController.bridge = nil
            MainViewController.bridgeInfo = nil
            SettingsViewController.toConnect = nil
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
            
            if settings.bridgeCell.detailTextLabel?.text == "Connected" {
                alert(title: "Notice", body: "Disconnected from the bridge.")
            }
            
            settings.bridgeCell.detailTextLabel?.text = "Not connected"
            settings.lightsCell.detailTextLabel?.text = "None selected"
            MainViewController.lights.removeAll()
            startButton.setTitle("Start", alpha: 0.9)
            
            MainViewController.bridgeInfo = nil
            SettingsViewController.toConnect = nil
            MainViewController.bridge = nil
            MainViewController.authenticated = false
            
            settings.tableView.reloadData()
            break
        case .notAuthenticated:
            print("not authenticated")
            
            MainViewController.authenticated = false
            break
        case .linkButtonNotPressed:
            print("button not pressed")
            
            if settings.presentedViewController as? UIAlertController != nil {
                settings.dismiss(animated: true, completion: nil)
            }
            
            if settings.presentedViewController as? PushButtonViewController == nil {
                let pushButton = self.storyboard?.instantiateViewController(withIdentifier: "PushButtonViewController") as! PushButtonViewController
                pushButton.isModalInPresentation = true
                settings.present(pushButton, animated: true, completion: nil)
            }
            break
        case .authenticated:
            print("authenticated")
            
            if self.presentedViewController != nil {
                self.dismiss(animated: true, completion: nil)
            }
            
            MainViewController.authenticated = true
            
            if MainViewController.bridgeInfo == nil {
                MainViewController.bridgeInfo = SettingsViewController.toConnect
            }
            SettingsViewController.toConnect = nil
            settings.bridgeCell.detailTextLabel?.text = "Connected"
            
            let defaults = UserDefaults.standard
            let lights = defaults.value(forKey: "lights")
            if  lights == nil {
                defaults.setValue([], forKey: "lights")
            } else {
                MainViewController.lights = defaults.value(forKey: "lights") as? [String]
            }
            
            if MainViewController.lights.isEmpty {
                settings.lightsCell.detailTextLabel?.text = "None selected"
            } else {
                settings.lightsCell.detailTextLabel?.text = "\(MainViewController.lights.count) selected"
            }
            
            settings.tableView.reloadData()
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
            break
        default:
            return
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
