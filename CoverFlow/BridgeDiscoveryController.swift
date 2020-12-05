//
//  BridgeDiscoveryController.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 10/18/20.
//

import Foundation
import UIKit

class BridgeDiscoveryController: UITableViewController {
    
    var bridges: [BridgeInfo] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        addTopSeparator()
        
        self.refreshControl = UIRefreshControl()
        refreshControl!.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        
        if ViewController.authenticated && ViewController.bridge != nil && ViewController.bridgeInfo != nil {
            bridges.append(ViewController.bridgeInfo)
        } else {
            refreshControl!.beginRefreshing()
            discoverBridges()
        }
    }
    
    func addTopSeparator() {
        let line = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.size.width, height: (1 / UIScreen.main.scale)))
        self.tableView.tableHeaderView = line
        line.backgroundColor = self.tableView.separatorColor
    }
    
    @objc func refresh(_ sender: AnyObject) {
        discoverBridges()
    }
    
    func discoverBridges() {
        NSLog("Getting bridges")
        PHSBridgeDiscovery().search(.discoveryOptionUPNP) { (result, returnCode) in
            if returnCode == .success && result != nil {
                NSLog("Got array 1")
                for (_, value) in result! {
                    if value.ipAddress == nil || value.uniqueId == nil {
                        continue
                    } else {
                        NSLog("Got a bridge")
                        let bridgeInfo: BridgeInfo = BridgeInfo(ipAddress: value.ipAddress, uniqueId: value.uniqueId)
                        NSLog("Got bridge info")
                        if !self.bridges.contains(where: { (bridgeInfoIn) -> Bool in
                            return Bool(bridgeInfoIn.ipAddress == bridgeInfo.ipAddress && bridgeInfoIn.uniqueId == bridgeInfo.uniqueId)
                        }) {
                            NSLog("Adding to array")
                            self.bridges.append(bridgeInfo)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Notice", message: "Could not find bridges.", preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
            
            if self.bridges.isEmpty {
                PHSBridgeDiscovery().search(.discoveryOptionIPScan) { (result, returnCode) in
                    if returnCode == .success && result != nil {
                        for (_, value) in result! {
                            if value.ipAddress == nil || value.uniqueId == nil {
                                continue
                            } else {
                                NSLog("Got a bridge")
                                let bridgeInfo: BridgeInfo = BridgeInfo(ipAddress: value.ipAddress, uniqueId: value.uniqueId)
                                NSLog("Got bridge info")
                                if !self.bridges.contains(where: { (bridgeInfoIn) -> Bool in
                                    return Bool(bridgeInfoIn.ipAddress == bridgeInfo.ipAddress && bridgeInfoIn.uniqueId == bridgeInfo.uniqueId)
                                }) {
                                    NSLog("Adding to array")
                                    self.bridges.append(bridgeInfo)
                                }
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            let alert = UIAlertController(title: "Notice", message: "Could not find bridges.", preferredStyle: UIAlertController.Style.alert)
                            alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                    }
                    NSLog("got bridges 1")
                    self.refreshControl!.endRefreshing()
                    self.tableView.reloadData()
                }
            } else {
                NSLog("got bridges 2")
                self.refreshControl!.endRefreshing()
                self.tableView.reloadData()
            }
        }
    }
    
    
    @IBAction func enterIPAction(_ sender: Any) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Manually connect", message: "Enter the IP address of your bridge to manually connect to it:", preferredStyle: UIAlertController.Style.alert)
            alert.addTextField { (textField) in
                textField.placeholder = "IP address"
                textField.autocorrectionType = .no
            }
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { alertAction in
                let searchingAlert = UIAlertController(title: "Finding bridge...", message: nil, preferredStyle: UIAlertController.Style.alert)
                alert.dismiss(animated: true) {
                    self.present(searchingAlert, animated: true, completion: {
                        if let textFields = alert.textFields {
                            if let ip = (textFields[0] as UITextField).text {
                                let bridge = PHSSDK.getBridgeInformation(ip)
                                if bridge != nil {
                                    if let uniqueId = bridge?.uniqueId {
                                        let bridgeInfo = BridgeInfo(ipAddress: ip, uniqueId: uniqueId)
                                        ViewController.bridgeInfo = bridgeInfo
                                        searchingAlert.dismiss(animated: true, completion: {
                                            _ = self.navigationController?.popToRootViewController(animated: true)
                                        })
                                    } else {
                                        searchingAlert.dismiss(animated: true, completion: {
                                            let alert = UIAlertController(title: "Error", message: "Could not obtain unique ID.", preferredStyle: UIAlertController.Style.alert)
                                            alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                                            self.present(alert, animated: true, completion: nil)
                                        })
                                    }
                                } else {
                                    searchingAlert.dismiss(animated: true, completion: {
                                        let alert = UIAlertController(title: "Error", message: "Could not find bridge.", preferredStyle: UIAlertController.Style.alert)
                                        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                                        self.present(alert, animated: true, completion: nil)
                                    })
                                }
                            } else {
                                searchingAlert.dismiss(animated: true, completion: {
                                    let alert = UIAlertController(title: "Error", message: "Could not get text.", preferredStyle: UIAlertController.Style.alert)
                                    alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                                    self.present(alert, animated: true, completion: nil)
                                })
                            }
                        } else {
                            searchingAlert.dismiss(animated: true, completion: {
                                let alert = UIAlertController(title: "Error", message: "Could not get text field.", preferredStyle: UIAlertController.Style.alert)
                                alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                                self.present(alert, animated: true, completion: nil)
                            })
                        }
                    })
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    // MARK: Table Related
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bridges.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BridgeCell") as! BridgeCell
        cell.title.text = bridges[indexPath.row].ipAddress
        cell.subtitle.text = bridges[indexPath.row].uniqueId
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        NSLog("tapped bridge")
        if bridges.count > indexPath.row {
            let selectedBridgeInfo = bridges[indexPath.row]
            
            if ViewController.authenticated && ViewController.bridgeInfo != nil && ViewController.bridgeInfo.ipAddress == selectedBridgeInfo.ipAddress && ViewController.bridgeInfo.uniqueId == selectedBridgeInfo.uniqueId {
                _ = navigationController?.popToRootViewController(animated: true)
            } else {
                NSLog("will set bridge info")
                ViewController.bridgeInfo = selectedBridgeInfo
                NSLog("set bridge info")
                _ = navigationController?.popToRootViewController(animated: true)
                NSLog("went back to root")
            }
        } else {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Error", message: "Index out of bounds. Bridges:\(self.bridges.count). Index:\(indexPath.row).", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
}

class BridgeCell: UITableViewCell {
    @IBOutlet var title: UILabel!
    @IBOutlet var subtitle: UILabel!
}
