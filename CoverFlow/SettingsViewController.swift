//
//  SettingsViewController.swift
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

protocol SettingsViewControllerDelegate {
    func didSignOut()
    func didSetBridgeInfo()
}

class SettingsViewController: UITableViewController, UITextFieldDelegate {
    
    // MARK: Variables, IBOutlets, and IBActions
    
    var delegate: SettingsViewControllerDelegate?
    var connectToNewBridge: Bool = false
    
    @IBAction func doneButtonAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBOutlet var bridgeCell: UITableViewCell!
    @IBOutlet var lightsCell: UITableViewCell!
    
    var colorDuration: Double = 0.0
    @IBOutlet var colorDurationLabel: UILabel!
    @IBOutlet var colorDurationSlider: UISlider!
    @IBAction func colorDurationChanged(_ sender: UISlider?) {
        var rounded: Int = Int(colorDurationSlider.value)
        if sender != nil && rounded == 0 && transitionDuration == 0 {
            rounded = 1
        }
        colorDuration = Double(rounded) * 0.25
        colorDurationSlider.value = Float(rounded)
        colorDurationLabel.text = "\(colorDuration) sec"
        
        DispatchQueue.global(qos: .background).async {
            UserDefaults.standard.setValue(rounded, forKey: "colorDuration")
        }
    }
    
    var transitionDuration: Double = 0.0
    @IBOutlet var transitionDurationLabel: UILabel!
    @IBOutlet var transitionDurationSlider: UISlider!
    @IBAction func transitionDurationChanged(_ sender: UISlider?) {
        var rounded: Int = Int(transitionDurationSlider.value)
        if sender != nil && rounded == 0 && colorDuration == 0 {
            rounded = 1
        }
        transitionDuration = Double(rounded) * 0.25
        transitionDurationSlider.value = Float(rounded)
        transitionDurationLabel.text = "\(transitionDuration) sec"
        
        DispatchQueue.global(qos: .background).async {
            UserDefaults.standard.setValue(rounded, forKey: "transitionDuration")
        }
    }
    
    var brightness: Double = 0.0
    @IBOutlet var brightnessLabel: UILabel!
    @IBOutlet var brightnessSlider: UISlider!
    @IBAction func brightnessChanged(_ sender: UISlider?) {
        let rounded: Int = Int(brightnessSlider.value)
        brightness = Double(rounded) * 2.54
        brightnessSlider.value = Float(rounded)
        brightnessLabel.text = "\(rounded)%"
        
        DispatchQueue.global(qos: .background).async {
            UserDefaults.standard.setValue(rounded, forKey: "brightness")
        }
    }
    
    @IBOutlet var randomizeColorSwitch: UISwitch!
    @IBAction func randomizeColorSwitchAction(_ sender: UISwitch?) {
        DispatchQueue.main.async {
            UserDefaults.standard.setValue(self.randomizeColorSwitch.isOn, forKey: "randomizeColorOrder")
        }
    }
    
    var maximumColors: Int = 0
    @IBOutlet var maximumColorsLabel: UILabel!
    @IBOutlet var maximumColorsStepper: UIStepper!
    @IBAction func maximumColorsStepperAction(_ sender: UIStepper?) {
        let maximumColors = self.maximumColorsStepper.value > 4 ? 4.0 : (self.maximumColorsStepper.value < 1 ? 1.0 : self.maximumColorsStepper.value)
        let maximumColorsInt = Int(maximumColors)
        self.maximumColors = maximumColorsInt
        maximumColorsStepper.value = maximumColors
        maximumColorsLabel.text = maximumColors == 4.0 ? "Maximum colors: All" : "Maximum colors: \(maximumColorsInt)"
        
        DispatchQueue.global(qos: .background).async {
            UserDefaults.standard.setValue(maximumColors, forKey: "maximumColors")
        }
    }
    
    @IBOutlet var musicProviderLabel: UILabel!
    @IBAction func signOutButtonAction(_ sender: Any) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Sign out", message: "Are you sure you want to sign out?", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { alertAction in
                self.delegate?.didSignOut()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @IBOutlet var twitterCell: UITableViewCell!
    
    // MARK: View Related
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delaysContentTouches = false
        
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
        let randomizeColorOrder = defaults.value(forKey: "randomizeColorOrder")
        if randomizeColorOrder == nil {
            defaults.setValue(false, forKey: "randomizeColorOrder")
            randomizeColorSwitch.isOn = false
        } else {
            randomizeColorSwitch.isOn = randomizeColorOrder as! Bool
        }
        let maximumColors = defaults.value(forKey: "maximumColors")
        if maximumColors == nil {
            defaults.setValue(4.0, forKey: "maximumColors")
            maximumColorsStepper.value = 4
        } else {
            maximumColorsStepper.value = maximumColors as! Double
        }
        
        colorDurationChanged(nil)
        transitionDurationChanged(nil)
        brightnessChanged(nil)
        randomizeColorSwitchAction(nil)
        maximumColorsStepperAction(nil)
        
        let cellHeight = twitterCell.bounds.height
        let image = UIImageView(image: UIImage(named: "Twitter"))
        image.setImageColor(color: .systemGray2)
        twitterCell.accessoryView = image
        twitterCell.accessoryView?.frame = CGRect(x: 0, y: 0, width: cellHeight / 3.5, height: cellHeight / 3.5)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if MainViewController.selectedLights.isEmpty {
            lightsCell.detailTextLabel?.text = "None selected"
        } else {
            lightsCell.detailTextLabel?.text = "\(MainViewController.selectedLights.count) selected"
        }
        
        if MainViewController.musicProvider != nil && MainViewController.musicProvider == "appleMusic" {
            musicProviderLabel.text = "Music provider: Apple Music"
        } else if MainViewController.musicProvider != nil && MainViewController.musicProvider == "spotify" {
            musicProviderLabel.text = "Music provider: Spotify"
        }
        self.tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let localNetworkPermissionService = LocalNetworkPermissionService()
        localNetworkPermissionService.triggerDialog()
        
        if connectToNewBridge {
            delegate?.didSetBridgeInfo()
            connectToNewBridge = false
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "toLightSelection" && !MainViewController.authenticated {
            alert(title: "Error", body: "Please connect to a bridge before continuing.")
            return false
        } else {
            return true
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toBridgeSelection" {
            if let destination = segue.destination as? BridgeDiscoveryViewController {
                destination.delegate = self
            }
        }
    }
    
    // MARK: Table Related
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)!
        cell.setSelected(false, animated: true)
        
        if let label = cell.textLabel?.text {
            if label == "Thatcher Clough" {
                let screenName =  "thatcherclough"
                let appURL = NSURL(string: "twitter://user?screen_name=\(screenName)")!
                let webURL = NSURL(string: "https://twitter.com/\(screenName)")!
                
                let application = UIApplication.shared
                if application.canOpenURL(appURL as URL) {
                    application.open(appURL as URL)
                } else {
                    application.open(webURL as URL)
                }
            }
        }
    }
    
    // MARK: Other
    
    func alert(title: String, body: String) {
        DispatchQueue.main.async {
            if self.presentedViewController == nil {
                let alert = UIAlertController(title: title, message: body, preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
}

extension SettingsViewController: BridgeDiscoveryViewControllerDelegate {
    func didSetBridgeInfo() {
        connectToNewBridge = true
    }
}

extension UIImageView {
    func setImageColor(color: UIColor) {
        let templateImage = self.image?.withRenderingMode(.alwaysTemplate)
        self.image = templateImage
        self.tintColor = color
    }
}
