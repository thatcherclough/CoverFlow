//
//  ViewController.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 10/18/20.
//

import UIKit
import MediaPlayer
import ColorThiefSwift
import StoreKit
import Reachability
import AVFoundation
import Keys

class ViewController: UITableViewController, UITextFieldDelegate {
    
    // MARK: Cells, slider, and variables
    
    let keys = CoverFlowKeys()
    var canPushNotifications: Bool = false
    
    static var musicProvider: String! = UserDefaults.standard.string(forKey: "musicProvider")
    static var appleMusicController: AppleMusicController!
    static var spotifyController: SpotifyController!
    
    @IBOutlet var bridgeCell: UITableViewCell!
    @IBOutlet var lightsCell: UITableViewCell!
    @IBOutlet var startButtonText: UILabel!
    
    var currentHues: [NSNumber] = []
    var currentLightsStates: [String: PHSLightState] = [:]
    static var bridge: PHSBridge! = nil
    static var bridgeInfo: BridgeInfo! = nil
    static var authenticated: Bool = false
    static var lights: [String]! = []
    
    var colorDuration: Double = 0.0
    @IBOutlet var colorDurationLabel: UILabel!
    @IBOutlet var colorDurationSlider: UISlider!
    @IBAction func colorDurationChanged(_ sender: UISlider?) {
        var rounded: Int = Int(colorDurationSlider.value)
        if rounded == 0 && transitionDuration == 0 {
            rounded = 1
        }
        colorDurationSlider.value = Float(rounded)
        
        let newColorDuration = Double(rounded) * 0.25
        if newColorDuration != colorDuration {
            colorDuration = newColorDuration
            
            colorDurationLabel.text = "\(colorDuration) sec"
            DispatchQueue.global(qos: .background).async {
                UserDefaults.standard.setValue(rounded, forKey: "colorDuration")
            }
        }
    }
    
    var transitionDuration: Double = 0.0
    @IBOutlet var transitionDurationLabel: UILabel!
    @IBOutlet var transitionDurationSlider: UISlider!
    @IBAction func transitionDurationChanged(_ sender: UISlider?) {
        var rounded: Int = Int(transitionDurationSlider.value)
        if rounded == 0 && colorDuration == 0{
            rounded = 1
        }
        transitionDurationSlider.value = Float(rounded)
        
        let newTransitionDuration = Double(rounded) * 0.25
        if newTransitionDuration != transitionDuration {
            transitionDuration = newTransitionDuration
            transitionDurationLabel.text = "\(transitionDuration) sec"
            DispatchQueue.global(qos: .background).async {
                UserDefaults.standard.setValue(rounded, forKey: "transitionDuration")
            }
        }
    }
    
    var brightness: Double = 0.0
    @IBOutlet var brightnessLabel: UILabel!
    @IBOutlet var brightnessSlider: UISlider!
    @IBAction func brightnessChanged(_ sender: UISlider?) {
        let rounded: Int = Int(brightnessSlider.value)
        brightnessSlider.value = Float(rounded)
        
        let newBrightness = Double(rounded) * 2.54
        if newBrightness != brightness {
            brightness = newBrightness
            brightnessLabel.text = "\(rounded)%"
            DispatchQueue.global(qos: .background).async {
                UserDefaults.standard.setValue(rounded, forKey: "brightness")
            }
        }
    }
    
    // MARK: View Related
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        observeReachability()
        
        colorDurationSlider.minimumValue = 0
        colorDurationSlider.maximumValue = 40
        colorDurationSlider.tintAdjustmentMode = .normal
        transitionDurationSlider.minimumValue = 0
        transitionDurationSlider.maximumValue = 20
        transitionDurationSlider.tintAdjustmentMode = .normal
        brightnessSlider.minimumValue = 0
        brightnessSlider.maximumValue = 100
        brightnessSlider.tintAdjustmentMode = .normal
        
        let defaults = UserDefaults.standard
        let colorTimeDefaults = defaults.value(forKey: "colorDuration")
        if colorTimeDefaults == nil {
            defaults.setValue(4.0, forKey: "colorDuration")
            colorDurationSlider.value = 4.0
        } else {
            colorDurationSlider.value = colorTimeDefaults as! Float
        }
        let transitionTimeDefaults = defaults.value(forKey: "transitionDuration")
        if transitionTimeDefaults == nil {
            defaults.setValue(8.0, forKey: "transitionDuration")
            transitionDurationSlider.value = 8.0
        } else {
            transitionDurationSlider.value = transitionTimeDefaults as! Float
        }
        let brightnessDefaults = defaults.value(forKey: "brightness")
        if brightnessDefaults == nil {
            defaults.setValue(100, forKey: "brightness")
            brightnessSlider.value = 100
        } else {
            brightnessSlider.value = brightnessDefaults as! Float
        }
        
        colorDurationChanged(nil)
        transitionDurationChanged(nil)
        brightnessChanged(nil)
        
        if ViewController.musicProvider == "appleMusic" && ViewController.appleMusicController == nil {
            ViewController.appleMusicController = AppleMusicController(apiKey: keys.appleMusicAPIKey1)
        } else if ViewController.musicProvider == "spotify" && ViewController.spotifyController == nil{
            ViewController.spotifyController = SpotifyController(clientID: keys.spotifyClientID, clientSecret: keys.spotifyClientSecret, redirectURI: URL(string: "coverflow://spotify-login-callback")!)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        checkPermissionsAndSetupHue()
        
        if ViewController.lights.isEmpty {
            self.lightsCell.detailTextLabel?.text = "None selected"
        } else {
            self.lightsCell.detailTextLabel?.text = "\(ViewController.lights.count) selected"
        }
        self.tableView.reloadData()
        
        if ViewController.musicProvider == nil {
            presentMusicProvider(alert: nil)
        } else {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if error == nil {
                    self.canPushNotifications = granted
                }
            }
        }
    }
    
    func checkPermissionsAndSetupHue() {
        if ViewController.musicProvider == "appleMusic" {
            MPMediaLibrary.requestAuthorization { authorizationStatus in
                if authorizationStatus != .authorized {
                    self.stop()
                    
                    let alert = UIAlertController(title: "Error", message: "Apple Music access has been revoked. Try connecting again.", preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                    self.presentMusicProvider(alert: alert)
                    
                    ViewController.musicProvider = nil
                    UserDefaults.standard.set(nil, forKey: "musicProvider")
                } else {
                    self.hueSetup()
                }
            }
        } else if ViewController.musicProvider == "spotify" {
            if ViewController.spotifyController != nil && ViewController.spotifyController.refreshToken == "N/A" {
                self.stop()
                
                let alert = UIAlertController(title: "Error", message: "Spotify access has been revoked. Try connecting again.", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                presentMusicProvider(alert: alert)
                
                ViewController.musicProvider = nil
                UserDefaults.standard.set(nil, forKey: "musicProvider")
            } else {
                self.hueSetup()
            }
        }
    }
    
    func hueSetup() {
        setUpLastConnectedBridge()
        
        if ViewController.bridgeInfo != nil && (!ViewController.authenticated || (ViewController.authenticated && ViewController.bridge.bridgeConfiguration.networkConfiguration.ipAddress != ViewController.bridgeInfo.ipAddress)) {
            connectFromBridgeInfo()
        }
    }
    
    func setUpLastConnectedBridge() {
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
        
        if lastConnectedBridge != nil {
            ViewController.bridgeInfo = lastConnectedBridge
        }
    }
    
    func connectFromBridgeInfo() {
        DispatchQueue.main.async {
            if self.presentedViewController != nil {
                self.dismiss(animated: true, completion: nil)
            }
            let connectionAlert = UIAlertController(title: "Connecting to bridge...", message: nil, preferredStyle: UIAlertController.Style.alert)
            self.present(connectionAlert, animated: true) {
                ViewController.bridge = self.buildBridge(info: ViewController.bridgeInfo)
                ViewController.bridge.connect()
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
    
    override func viewWillDisappear(_ animated: Bool) {
        stop()
    }
    
    func stop() {
        if timer != nil {
            timer.invalidate()
        }
        timer = nil
        
        DispatchQueue.main.async() {
            self.startButtonText.text = "Start"
            self.canStartOrStop = true
        }
        self.stopBackgrounding()
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "toLightSelection" && !ViewController.authenticated {
            alert(title: "Error", body: "Please connect to a bridge before continuing.")
            return false
        } else {
            return true
        }
    }
    
    // MARK: Table Related
    
    var canStartOrStop: Bool = true
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!
        cell.setSelected(false, animated: true)
        
        if indexPath.section == 2 && indexPath.row == 0 {
            checkPermissionsAndSetupHue()
            
            if !ViewController.authenticated {
                alert(title: "Error", body: "Please connect to a bridge before continuing.")
            } else {
                if canStartOrStop {
                    canStartOrStop = false
                    if startButtonText.text == "Start" {
                        startButtonText.text = "Starting..."
                        
                        DispatchQueue.global(qos: .background).async {
                            self.startBackgrounding()
                            self.getCurrentLightsStates()
                            self.start()
                        }
                    } else {
                        startButtonText.text = "Start"
                        
                        DispatchQueue.global(qos: .background).async {
                            self.stopBackgrounding()
                            self.setCurrentLightsStates()
                            
                            if self.timer != nil {
                                self.timer.invalidate()
                            }
                            
                            self.canStartOrStop = true
                        }
                    }
                }
            }
        }
    }
    
    // MARK: Bridge related
    
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
        
        for light in ViewController.bridge.bridgeState.getDevicesOf(.light) {
            let lightName = (light as! PHSDevice).name!
            
            if ViewController.lights.contains(lightName) {
                currentLightsStates[lightName] = (light as! PHSLightPoint).lightState
            }
        }
    }
    
    func setCurrentLightsStates() {
        for light in ViewController.bridge.bridgeState.getDevicesOf(.light) {
            let lightName = (light as! PHSDevice).name!
            
            if ViewController.lights.contains(lightName) && currentLightsStates.keys.contains(lightName) {
                let lightPoint = light as! PHSLightPoint
                
                lightPoint.update(currentLightsStates[lightName], allowedConnectionTypes: .local) { (responses, errors, returnCode) in
                    if errors != nil && errors!.count > 0 {
                        var errorText = "Could not restore light state."
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
    
    var timer: Timer!
    var notifyAboutNothingPlaying: Bool = true
    func start() {
        if ViewController.musicProvider == "appleMusic" {
            var currentHueIndex: Int = 0
            var albumAndArtist = ViewController.appleMusicController.getCurrentAlbumName() + ViewController.appleMusicController.getCurrentArtistName()
            let wait = self.colorDuration + self.transitionDuration
            
            getCoverImageAndSetCurrentSongHues()
            
            DispatchQueue.main.async {
                self.timer = Timer.scheduledTimer(withTimeInterval: wait, repeats: true) { (timer) in
                    if wait != (self.colorDuration + self.transitionDuration) {
                        timer.invalidate()
                        self.start()
                    }
                    
                    if !self.currentHues.isEmpty && self.currentHues.count > currentHueIndex {
                        for light in ViewController.bridge.bridgeState.getDevicesOf(.light) {
                            if ViewController.lights.contains((light as! PHSDevice).name) {
                                if let lightPoint: PHSLightPoint = light as? PHSLightPoint {
                                    let lightState = PHSLightState()
                                    if self.brightness == 0 {
                                        lightState.on = false
                                    } else {
                                        lightState.on = true
                                        lightState.hue = self.currentHues[currentHueIndex]
                                        lightState.saturation = 254
                                        lightState.brightness = NSNumber(value: self.brightness)
                                        lightState.transitionTime = NSNumber(value: self.transitionDuration * 10)
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
                    
                    let currentAlbumAndArtist = ViewController.appleMusicController.getCurrentAlbumName() + ViewController.appleMusicController.getCurrentArtistName()
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
                
                if self.startButtonText.text == "Starting..." {
                    self.startButtonText.text = "Stop"
                    self.canStartOrStop = true
                }
            }
        } else if ViewController.musicProvider == "spotify" {
            var currentHueIndex: Int = 0
            var albumAndArtist = ""
            let wait = self.colorDuration + self.transitionDuration
            
            ViewController.spotifyController.getCurrentAlbum { (album) in
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
                        if wait != (self.colorDuration + self.transitionDuration) {
                            timer.invalidate()
                            self.start()
                        }
                        
                        if !self.currentHues.isEmpty && self.currentHues.count > currentHueIndex {
                            for light in ViewController.bridge.bridgeState.getDevicesOf(.light) {
                                if ViewController.lights.contains((light as! PHSDevice).name) {
                                    if let lightPoint: PHSLightPoint = light as? PHSLightPoint {
                                        let lightState = PHSLightState()
                                        if self.brightness == 0 {
                                            lightState.on = false
                                        } else {
                                            lightState.on = true
                                            lightState.hue = self.currentHues[currentHueIndex]
                                            lightState.saturation = 254
                                            lightState.brightness = NSNumber(value: self.brightness)
                                            lightState.transitionTime = NSNumber(value: self.transitionDuration * 10)
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
                        
                        ViewController.spotifyController.getCurrentAlbum { (album) in
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
                    
                    if self.startButtonText.text == "Starting..." {
                        self.startButtonText.text = "Stop"
                        self.canStartOrStop = true
                    }
                }
                
            }
            
        }
    }
    
    func getCoverImageAndSetCurrentSongHues() {
        currentHues.removeAll()
        
        if ViewController.musicProvider == "appleMusic" {
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
                        ViewController.appleMusicController.getCoverFromAPI(albumName: albumName!, artistName: artistName!) { (url) in
                            if url != nil {
                                self.getData(from: URL(string: url!)!) { data, response, error in
                                    if data == nil || error != nil {
                                        self.alertAndNotify(title: "Error", body: "Could not download the current song's album cover.")
                                        return
                                    }
                                    
                                    DispatchQueue.main.async() {
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
        } else if ViewController.musicProvider == "spotify" {
            ViewController.spotifyController.getCurrentAlbum() { (album) in
                if let images = album["images"] as? NSArray {
                    if let image = images[0] as? [String: Any] {
                        if let url = image["url"] {
                            self.getData(from: URL(string: url as! String)!) { data, response, error in
                                if data == nil || error != nil {
                                    self.alertAndNotify(title: "Error", body: "Could not download the current song's album cover.")
                                    return
                                }
                                
                                DispatchQueue.main.async() {
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
        
        for color in colors {
            let rgb = rgbToHue(r: CGFloat(color.r), g: CGFloat(color.g), b: CGFloat(color.b))
            let hue: CGFloat = rgb.h
            let saturation: CGFloat = rgb.s
            if hue > 0 && saturation > 0.2 {
                currentHues.append((hue * 182) as NSNumber)
            }
        }
        
        if currentHues.isEmpty {
            alertAndNotify(title: "Notice", body: "The current song's album cover does not have any distinct colors.")
        }
    }
    
    func rgbToHue(r: CGFloat, g: CGFloat, b: CGFloat) -> (h: CGFloat, s: CGFloat, b: CGFloat) {
        let minV: CGFloat = CGFloat(min(r, g, b))
        let maxV: CGFloat = CGFloat(max(r, g, b))
        let delta: CGFloat = maxV - minV
        var hue: CGFloat = 0
        if delta != 0 {
            if r == maxV {
                hue = (g - b) / delta
            } else if g == maxV {
                hue = 2 + (b - r) / delta
            } else {
                hue = 4 + (r - g) / delta
            }
            hue *= 60
            if hue < 0 {
                hue += 360
            }
        }
        let saturation = maxV == 0 ? 0 : (delta / maxV)
        let brightness = maxV
        return (h: hue, s: saturation, b: brightness)
    }
    
    // MARK: Other
    
    var audioPlayer: AVAudioPlayer?
    func playAudio(fileName: String, fileExtension: String) {
        do {
            let audioFile = URL(fileURLWithPath: Bundle.main.path(forResource: fileName, ofType: fileExtension)!)
            audioPlayer = try AVAudioPlayer(contentsOf: audioFile)
            audioPlayer!.volume = 0.05
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
            backgroundPlayer!.numberOfLoops = -1
            backgroundPlayer!.prepareToPlay()
            backgroundPlayer!.play()
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
    func observeReachability(){
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
                if ViewController.bridge != nil {
                    ViewController.bridge.disconnect()
                    
                    stopBackgrounding()
                    
                    if timer != nil {
                        timer.invalidate()
                    }
                }
            } else if connection == .wifi {
                setUpLastConnectedBridge()
                connectFromBridgeInfo()
            }
        }
    }
}

extension ViewController: PHSBridgeConnectionObserver {
    func bridgeConnection(_ bridgeConnection: PHSBridgeConnection!, handle connectionEvent: PHSBridgeConnectionEvent) {
        switch connectionEvent {
        case .couldNotConnect:
            print("could not connect")
            
            if self.presentedViewController as? UIAlertController != nil {
                self.dismiss(animated: true, completion: nil)
            }
            alert(title: "Error", body: "Could not connect to the bridge.")
            
            ViewController.bridge = nil
            ViewController.bridgeInfo = nil
            ViewController.authenticated = false
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
            
            bridgeCell.detailTextLabel?.text = "Not connected"
            lightsCell.detailTextLabel?.text = "None selected"
            ViewController.lights.removeAll()
            startButtonText.text = "Start"
            
            ViewController.bridgeInfo = nil
            ViewController.bridge = nil
            ViewController.authenticated = false
            
            tableView.reloadData()
            
            if bridgeCell.detailTextLabel?.text == "Connected" {
                alert(title: "Notice", body: "Disconnected from the bridge.")
            }
            break
        case .notAuthenticated:
            print("not authenticated")
            
            ViewController.authenticated = false
            break
        case .linkButtonNotPressed:
            print("button not pressed")
            
            if self.presentedViewController as? UIAlertController != nil {
                self.dismiss(animated: true, completion: nil)
            }
            if self.presentedViewController == nil {
                let pushButton = self.storyboard?.instantiateViewController(withIdentifier: "PushButtonViewController") as! PushButtonViewController
                pushButton.isModalInPresentation = true
                self.present(pushButton, animated: true, completion: nil)
            }
            break
        case .authenticated:
            print("authenticated")
            
            if self.presentedViewController as? UIAlertController != nil {
                self.dismiss(animated: true, completion: nil)
            }
            ViewController.authenticated = true
            
            bridgeCell.detailTextLabel?.text = "Connected"
            
            let defaults = UserDefaults.standard
            let lights = defaults.value(forKey: "lights")
            if  lights == nil {
                defaults.setValue([], forKey: "lights")
            } else {
                ViewController.lights = defaults.value(forKey: "lights") as? [String]
            }
            
            if ViewController.lights.isEmpty {
                lightsCell.detailTextLabel?.text = "None selected"
            } else {
                lightsCell.detailTextLabel?.text = "\(ViewController.lights.count) selected"
            }
            
            self.tableView.reloadData()
            break
        default:
            return
        }
    }
    
    func bridgeConnection(_ bridgeConnection: PHSBridgeConnection!, handleErrors connectionErrors: [PHSError]!) {}
}

extension ViewController: PHSBridgeStateUpdateObserver {
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
