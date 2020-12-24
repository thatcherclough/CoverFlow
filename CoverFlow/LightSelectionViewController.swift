//
//  LightSelectionViewController.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 10/19/20.
//

import Foundation
import UIKit

class LightSelectionViewController: UITableViewController {
    
    // MARK: View Related
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.reloadData()
    }
    
    // MARK: Table Related
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return MainViewController.allLights.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LightsCell") as! LightsCell
        
        let lightName = MainViewController.allLights[indexPath.row]
        cell.title.text = lightName
        cell.accessoryType = MainViewController.selectedLights.contains(lightName) ? .checkmark : .none
        tableView.deselectRow(at: indexPath, animated: false)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! LightsCell
        cell.setSelected(false, animated: true)
        
        let lightName = MainViewController.allLights[indexPath.row]
        let selectedLightsIndex = MainViewController.selectedLights.firstIndex(of: lightName)
        if selectedLightsIndex != nil {
            MainViewController.selectedLights.remove(at: selectedLightsIndex!)
            cell.accessoryType = .none
        } else {
            MainViewController.selectedLights.append(lightName)
            cell.accessoryType = .checkmark
        }
        
        UserDefaults.standard.setValue(MainViewController.selectedLights, forKey: "lights")
    }
}

class LightsCell: UITableViewCell {
    @IBOutlet var title: UILabel!
}
