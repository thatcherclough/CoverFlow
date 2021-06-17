//
//  PushButtonViewController.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 10/19/20.
//

import Foundation
import UIKit

protocol PushButtonViewControllerDelegate {
    func timerDidExpire()
}

class PushButtonViewController: UIViewController {
    
    // MARK: Variables and IBOutlets
    
    var delegate: PushButtonViewControllerDelegate?
    
    @IBOutlet var bridgeImage: UIImageView!
    @IBOutlet var progressBar: UIProgressView!
    
    // MARK: View Related
    
    override func viewDidAppear(_ animated: Bool) {
        countdown()
    }
    
    func countdown() {
        var timeLeft: Float = 30
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (timer) in
            if MainViewController.authenticated {
                self.dismiss(animated: true, completion: nil)
                timer.invalidate()
            }
            
            timeLeft -= 1
            self.progressBar.progress = timeLeft / 30
            
            if timeLeft == 0 {
                self.delegate?.timerDidExpire()
                timer.invalidate()
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        bridgeImage.image = (traitCollection.userInterfaceStyle == .light) ? UIImage(named: "BridgeBlack") : UIImage(named: "BridgeWhite")
    }
}
