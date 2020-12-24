//
//  BridgeDiscoveryViewController.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 10/18/20.
//

import Foundation

protocol BridgeDiscoveryViewControllerDelegate {
    func didSetBridgeInfo()
}

class BridgeDiscoveryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: Variables, IBOutlets, and IBActions
    
    var delegate: BridgeDiscoveryViewControllerDelegate?
    
    var bridges: [BridgeInfo] = []
    lazy var bridgeDiscovery: PHSBridgeDiscovery = PHSBridgeDiscovery()
    
    @IBOutlet var automaticallySearchButton: UIButton!
    @IBAction func automaticallySearchButtonAction(_ sender: Any) {
        discoverBridges()
    }
    
    @IBOutlet var enterIPButton: UIButton!
    @IBAction func enterIPButtonAction(_ sender: Any) {
        enterIP()
    }
    
    @IBOutlet var tableView: UITableView!
    
    // MARK: View Related
    
    override func viewDidLoad() {
        automaticallySearchButton.titleLabel?.textAlignment = .center
        if view.bounds.width < 370 {
            automaticallySearchButton.titleLabel?.font = automaticallySearchButton.titleLabel?.font.withSize(17)
            enterIPButton.titleLabel?.font = enterIPButton.titleLabel?.font.withSize(17)
        }
        
        tableView.rowHeight = 55
        tableView.delegate = self
        tableView.dataSource = self
        addTopSeparator()
        
        if MainViewController.authenticated && MainViewController.bridgeInfo != nil {
            bridges = [MainViewController.bridgeInfo]
        } else {
            discoverBridges()
        }
    }
    
    func addTopSeparator() {
        let line = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: (1 / UIScreen.main.scale)))
        tableView.tableHeaderView = line
        line.backgroundColor = tableView.separatorColor
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        tableView.reloadData()
    }
    
    // MARK: Functions
    
    func discoverBridges() {
        DispatchQueue.main.async {
            let searchingAlert = UIAlertController(title: "Finding bridges...", message: nil, preferredStyle: .alert)
            self.present(searchingAlert, animated: true) {
                self.bridgeDiscovery.search(.discoveryOptionUPNP) { [weak self] (results, returnCode) in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    if results != nil && !results!.isEmpty && returnCode == .success {
                        let foundBridges:[BridgeInfo] = results!.map({ (key, value) in BridgeInfo(withDiscoveryResult: value) })
                        strongSelf.bridges = foundBridges
                        strongSelf.tableView.reloadData()
                        
                        searchingAlert.dismiss(animated: true, completion: nil)
                    } else {
                        strongSelf.bridges = []
                        strongSelf.tableView.reloadData()
                        
                        let alert = UIAlertController(title: "Notice", message: "Could not find any bridges. Make sure \"Local Network\" access is enabled in settings and try searching again.", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                        searchingAlert.dismiss(animated: true) {
                            strongSelf.present(alert, animated: true, completion: nil)
                        }
                    }
                }
            }
        }
    }
    
    func enterIP() {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Manually connect", message: "Enter the IP address of your bridge to manually connect to it:", preferredStyle: .alert)
            alert.addTextField { (textField) in
                textField.placeholder = "IP address"
                textField.keyboardType = .decimalPad
            }
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { alertAction in
                let searchingAlert = UIAlertController(title: "Finding bridge...", message: nil, preferredStyle: .alert)
                alert.dismiss(animated: true) {
                    self.present(searchingAlert, animated: true, completion: {
                        if let ip = alert.textFields?.first?.text {
                            let bridge = PHSSDK.getBridgeInformation(ip)
                            if bridge != nil && bridge?.uniqueId != nil {
                                let bridgeInfo = BridgeInfo(ipAddress: ip, uniqueId: bridge!.uniqueId)
                                searchingAlert.dismiss(animated: true, completion: {
                                    MainViewController.bridgeInfo = bridgeInfo
                                    self.delegate?.didSetBridgeInfo()
                                    _ = self.navigationController?.popToRootViewController(animated: true)
                                })
                            } else {
                                searchingAlert.dismiss(animated: true, completion: {
                                    let alert = UIAlertController(title: "Error", message: "Could not find bridge.", preferredStyle: .alert)
                                    alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                                    self.present(alert, animated: true, completion: nil)
                                })
                            }
                        } else {
                            searchingAlert.dismiss(animated: true, completion: {
                                let alert = UIAlertController(title: "Error", message: "Could not get IP address.", preferredStyle: .alert)
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bridges.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BridgeCell") as! BridgeCell
        cell.title.text = bridges[indexPath.row].ipAddress
        cell.bridgeImage.image = (traitCollection.userInterfaceStyle == .light) ? UIImage(named: "BridgeBlack") : UIImage(named: "BridgeWhite")
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if bridges.count > indexPath.row {
            let selectedBridgeInfo = bridges[indexPath.row]
            
            MainViewController.bridgeInfo = selectedBridgeInfo
            self.delegate?.didSetBridgeInfo()
            _ = self.navigationController?.popToRootViewController(animated: true)
        } else {
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Error", message: "Index out of bounds. Bridges:\(self.bridges.count). Index:\(indexPath.row).", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Dismiss", style: .default, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
}

class BridgeCell: UITableViewCell {
    @IBOutlet var title: UILabel!
    @IBOutlet var bridgeImage: UIImageView!
}
