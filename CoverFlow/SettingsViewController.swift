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

class SettingsViewController: UITableViewController, UITextFieldDelegate {
    
    // MARK: Cells, slider, and variables
    
    static var toConnect: BridgeInfo! = nil
    var mainViewController: MainViewController!
    
    @IBOutlet var bridgeCell: UITableViewCell!
    @IBOutlet var lightsCell: UITableViewCell!
    @IBOutlet var startButtonText: UILabel!
    
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
    
    @IBAction func doneButtonAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: View Related
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        self.tableView.reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("APPEARED HERE")
        let localNetworkPermissionService = LocalNetworkPermissionService()
        localNetworkPermissionService.triggerDialog()
        
        if MainViewController.lights.isEmpty {
            lightsCell.detailTextLabel?.text = "None selected"
        } else {
            lightsCell.detailTextLabel?.text = "\(MainViewController.lights.count) selected"
        }
        
        if SettingsViewController.toConnect != nil && (!MainViewController.authenticated || (MainViewController.authenticated && MainViewController.bridge != nil &&  MainViewController.bridge.bridgeConfiguration.networkConfiguration.ipAddress != SettingsViewController.toConnect.ipAddress)) {
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
                MainViewController.bridge = self.mainViewController.buildBridge(info: SettingsViewController.toConnect)
                MainViewController.bridge.connect()
            }
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
