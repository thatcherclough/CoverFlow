//
//  MainViewController.swift
//  CoverFlow
//
//  Created by Thatcher Clough on 12/3/20.
//

import Foundation
import UIKit
import AnimatedGradientView

public class MainViewController: UIViewController {
    
    @IBOutlet var startButton: TransparentTextButton!
    
    @IBAction func startButtonAction(_ sender: Any) {
        // change to starting
        UIView.animate(withDuration: 0.15,animations: {
            self.startButton.transform = CGAffineTransform.identity
        })
    }
    
    public override func viewDidLoad() {
        let animatedGradient = AnimatedGradientView(frame: view.bounds)
        animatedGradient.direction = .up
        animatedGradient.animationValues =
            [
                (colors: ["#833ab4", "#fd1d1d"], .up, .axial),
                (colors: ["#fd1d1d", "#fcb045"], .upRight, .axial),
                (colors: ["#833ab4", "#fd1d1d"], .right, .axial),
                (colors: ["#fd1d1d", "#fcb045"], .downRight, .axial),
                (colors: ["#833ab4", "#fd1d1d"], .down, .axial),
                (colors: ["#fd1d1d", "#fcb045"], .downLeft, .axial),
                (colors: ["#833ab4", "#fd1d1d"], .left, .axial),
                (colors: ["#fd1d1d", "#fcb045"], .upLeft, .axial)
            ]
        view.addSubview(animatedGradient)
        view.sendSubviewToBack(animatedGradient)
        
        startButton.setTitle("Start", for: .normal)
        startButton.layer.cornerRadius = 10
        startButton.clipsToBounds = true
        startButton.titleLabel?.alpha = 0
            
        startButton.addTarget(self, action: #selector(pushDownAnimation(_:)), for: .touchDown)
        startButton.addTarget(self, action: #selector(pushDownAnimation(_:)), for: .touchDragEnter)
        startButton.addTarget(self, action: #selector(backUpAnimation(_:)), for: .touchDragExit)
    }
    
    @objc func pushDownAnimation(_ sender: AnyObject) {
        UIView.animate(withDuration: 0.15,animations: {
            self.startButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        })
    }
    
    @objc func backUpAnimation(_ sender: AnyObject) {
        UIView.animate(withDuration: 0.15,animations: {
            self.startButton.transform = CGAffineTransform.identity
        })
    }
}

public class TransparentTextButton: UIButton {
    
    func clearColorForTitle() {
        let buttonSize = bounds.size
        if let font = titleLabel?.font{
            let attribs = [NSAttributedString.Key.font: font]
            if let textSize = titleLabel?.text?.size(withAttributes: attribs){
                UIGraphicsBeginImageContextWithOptions(buttonSize, false, UIScreen.main.scale)
                
                if let ctx = UIGraphicsGetCurrentContext(){
                    ctx.setFillColor(UIColor.white.cgColor)
                    
                    let center = CGPoint(x: buttonSize.width / 2 - textSize.width / 2, y: buttonSize.height / 2 - textSize.height / 2)
                    let path = UIBezierPath(rect: CGRect(x: 0, y: 0, width: buttonSize.width, height: buttonSize.height))
                    ctx.addPath(path.cgPath)
                    ctx.fillPath()
                    ctx.setBlendMode(.destinationOut)
                    
                    titleLabel?.text?.draw(at: center, withAttributes: [NSAttributedString.Key.font: font])
                    
                    if let viewImage = UIGraphicsGetImageFromCurrentImageContext(){
                        UIGraphicsEndImageContext()
                        
                        let maskLayer = CALayer()
                        maskLayer.contents = ((viewImage.cgImage) as AnyObject)
                        maskLayer.frame = bounds
                        
                        layer.mask = maskLayer
                    }
                }
            }
        }
    }
    
    func adjustPaddingBasedOnText(widthPadding: CGFloat, heightPadding: CGFloat) {
        if let font = titleLabel?.font {
            let attribs = [NSAttributedString.Key.font: font]
            if let textSize = titleLabel?.text?.size(withAttributes: attribs) {
                let screenWidth = UIScreen.main.bounds.width
                let screenHeight = UIScreen.main.bounds.height
                
                let width = textSize.width + widthPadding
                let height = textSize.height + heightPadding
                
                let newFrame = CGRect(x: (screenWidth / 2) - (width / 2), y: (screenHeight / 2) - (height / 2), width: width, height: height)
                frame = newFrame
            }
        }
    }
    
    public override func setTitle(_ title: String?, for state: UIControl.State) {
        super.setTitle(title, for: .normal)
        clearColorForTitle()
    }
}
