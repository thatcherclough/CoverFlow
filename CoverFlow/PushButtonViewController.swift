//
//  PushButtonViewController.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 10/19/20.
//

import Foundation
import UIKit

class PushButtonViewController: UIViewController {
    
    // MARK: IBOutlets
    
    @IBOutlet var bridgeImage: UIImageView!
    @IBOutlet var progressBar: UIProgressView!
    
    // MARK: View Related
    
    override func viewDidAppear(_ animated: Bool) {
        self.countdown()
    }
    
    func countdown() {
        var timeLeft: Float = 30
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (timer) in
            if MainViewController.authenticated {
                self.dismiss(animated: true, completion: nil)
                timer.invalidate()
            }
            
            timeLeft -= 1
            let progress = timeLeft / 30
            self.progressBar.progress = progress
            
            if timeLeft == 0 {
                MainViewController.bridge.disconnect()
                
                self.dismiss(animated: true, completion: nil)
                timer.invalidate()
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.userInterfaceStyle == .light {
            bridgeImage.image = UIImage(named: "BridgeBlack")
        } else {
            bridgeImage.image = UIImage(named: "BridgeWhite")
        }
    }
}
