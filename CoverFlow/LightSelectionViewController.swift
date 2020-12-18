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
    
    override func viewDidAppear(_ animated: Bool) {
        tableView.reloadData()
    }
    
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
        tableView.deselectRow(at: indexPath, animated: false)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! LightsCell
        cell.setSelected(false, animated: true)
        
        let light = MainViewController.allLights[indexPath.row]
        if MainViewController.selectedLights.contains(light) {
            MainViewController.selectedLights.remove(at: MainViewController.selectedLights.firstIndex(of: light)!)
            cell.accessoryType = .none
        } else {
            MainViewController.selectedLights.append(light)
            cell.accessoryType = .checkmark
        }
        
        UserDefaults.standard.setValue(MainViewController.selectedLights, forKey: "lights")
    }
}

class LightsCell: UITableViewCell {
    @IBOutlet var title: UILabel!
}
