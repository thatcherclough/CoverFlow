//
//  LightSelectionViewController.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 10/19/20.
//

import Foundation
import UIKit

class LightSelectionViewController: UITableViewController {
    
    // MARK: Table Related
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return MainViewController.allLights.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LightsCell") as! LightsCell
        let light = MainViewController.allLights[indexPath.row]
        cell.title.text = light
        if MainViewController.selectedLights.contains(light) {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if MainViewController.selectedLights.contains(MainViewController.allLights[indexPath.row]) {
            MainViewController.selectedLights.remove(at: MainViewController.selectedLights.firstIndex(of: MainViewController.allLights[indexPath.row])!)
        } else {
            MainViewController.selectedLights.append(MainViewController.allLights[indexPath.row])
        }
        
        UserDefaults.standard.setValue(MainViewController.selectedLights, forKey: "lights")
        tableView.reloadData()
    }
}

class LightsCell: UITableViewCell {
    @IBOutlet var title: UILabel!
}
