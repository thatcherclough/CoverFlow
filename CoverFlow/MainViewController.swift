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
    }
}
