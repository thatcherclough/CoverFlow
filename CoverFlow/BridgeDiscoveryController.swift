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
        PHSBridgeDiscovery().search(.discoveryOptionUPNP) { (result, returnCode) in
            if returnCode == .success {
                for (_, value) in result! {
                    let bridgeInfo: BridgeInfo = BridgeInfo(ipAddress: value.ipAddress, uniqueId: value.uniqueId)
                    
                    if !self.bridges.contains(where: { (BridgeInfo) -> Bool in
                        return Bool(BridgeInfo.ipAddress == bridgeInfo.ipAddress && BridgeInfo.uniqueId == BridgeInfo.uniqueId)
                    }) {
                        self.bridges.append(bridgeInfo)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    let alert = UIAlertController(title: "Notice", message: "Could not find bridges.", preferredStyle: UIAlertController.Style.alert)
                    alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                }
            }
            self.refreshControl!.endRefreshing()
            self.tableView.reloadData()
        }
    }
    
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
        let selectedBridgeInfo = bridges[indexPath.row]
        if ViewController.authenticated && ViewController.bridgeInfo.ipAddress == selectedBridgeInfo.ipAddress && ViewController.bridgeInfo.uniqueId == selectedBridgeInfo.uniqueId {
            _ = navigationController?.popToRootViewController(animated: true)
        } else {
            ViewController.bridgeInfo = bridges[indexPath.row]
            _ = navigationController?.popToRootViewController(animated: true)
        }
    }
}

class BridgeCell: UITableViewCell {
    @IBOutlet var title: UILabel!
    @IBOutlet var subtitle: UILabel!
}
