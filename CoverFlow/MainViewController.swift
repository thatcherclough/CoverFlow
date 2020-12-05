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
    
    var animatedGradient: AnimatedGradientView!
    
    @IBOutlet var startButton: TransparentTextButton!
    @IBOutlet var settingsButton: TransparentTextButton!
    
    @IBAction func startButtonAction(_ sender: Any) {
//        startButton.setTitle("Starting...", alpha: 0.9)
    }
    
    public override func viewDidLoad() {
        animatedGradient = AnimatedGradientView(frame: view.bounds)
        view.addSubview(animatedGradient)
        view.sendSubviewToBack(animatedGradient)
        updateBackground()
        
        startButton.setTitle("Start", alpha: 0.9)
        startButton.layer.cornerRadius = 10
        startButton.titleLabel?.alpha = 0
        startButton.clipsToBounds = true
        
        settingsButton.setTitle("Settings", alpha: 0.9)
        settingsButton.layer.cornerRadius = 10
        settingsButton.titleLabel?.alpha = 0
        settingsButton.clipsToBounds = true
    }
    
    func updateBackground() {
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
    }
    
}

public class TransparentTextButton: UIButton {
    
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        self.addTarget(self, action: #selector(pushDownAnimation(_:)), for: .touchDown)
        self.addTarget(self, action: #selector(pushDownAnimation(_:)), for: .touchDragEnter)
        self.addTarget(self, action: #selector(backUpAnimation(_:)), for: .touchDragExit)
        self.addTarget(self, action: #selector(backUpAnimation(_:)), for: .touchUpInside)
    }
    
    @objc func pushDownAnimation(_ sender: AnyObject) {
        UIView.animate(withDuration: 0.15, animations: {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        })
    }
    
    @objc func backUpAnimation(_ sender: AnyObject) {
        UIView.animate(withDuration: 0.15, animations: {
            self.transform = CGAffineTransform.identity
        })
    }
    
    public func setTitle(_ title: String?, alpha: CGFloat) {
        super.setTitle(title, for: .normal)
        clearColorForTitle(alpha: alpha)
    }
    
    func clearColorForTitle(alpha: CGFloat) {
        let buttonSize = bounds.size
        if let font = titleLabel?.font{
            let attribs = [NSAttributedString.Key.font: font]
            if let textSize = titleLabel?.text?.size(withAttributes: attribs){
                UIGraphicsBeginImageContextWithOptions(buttonSize, false, UIScreen.main.scale)
                
                if let ctx = UIGraphicsGetCurrentContext(){
                    ctx.setFillColor(UIColor.white.cgColor)
                    ctx.setAlpha(alpha)
                    
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
    
    func changeAlpha(alpha: CGFloat, duration: TimeInterval) {
        UIView.animate(withDuration: duration, animations: {
            self.alpha = alpha
        })
    }
}
