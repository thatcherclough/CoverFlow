//
//  LightSelectionViewController.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 10/19/20.
//

import Foundation
import UIKit

class LightSelectionViewController: UITableViewController {

    var allLights: [String]! = []
    var selectedLights: [String]! = []
    
    override func viewDidLoad() {
        allLights.removeAll()
        
        for device in ViewController.bridge.bridgeState.getDevicesOf(.light) as! [PHSDevice] {
            allLights.append(device.name!)
        }
        selectedLights = ViewController.lights
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allLights.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LightsCell") as! LightsCell
        cell.title.text = allLights[indexPath.row]
        if selectedLights.contains(allLights[indexPath.row]) {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if selectedLights.contains(allLights[indexPath.row]) {
            selectedLights.remove(at: selectedLights.firstIndex(of: allLights[indexPath.row])!)
        } else {
            selectedLights.append(allLights[indexPath.row])
        }
        ViewController.lights = selectedLights
        
        UserDefaults.standard.setValue(selectedLights, forKey: "lights")
        
        tableView.reloadData()
    }
}

class LightsCell: UITableViewCell {
    @IBOutlet var title: UILabel!
}
