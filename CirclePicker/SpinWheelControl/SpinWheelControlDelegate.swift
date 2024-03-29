//
//  SpinWheelControlDelegate.swift
//  SpinWheelControl
//
//  Created by Josh Henry on 5/2/17.
//  Copyright © 2017 Big Smash Software. All rights reserved.
//

import Foundation
import UIKit

@objc public protocol SpinWheelControlDelegate {
    
    //Triggered when the spin wheel has come to rest after spinning.
    @objc optional func spinWheelDidEndDecelerating(spinWheel: SpinWheelControl)
    
    //Triggered when the spin wheel has been tapped.
    @objc optional func didTapOnWedgeAtIndex(spinWheel: SpinWheelControl, index: UInt)
    
    //Triggered at various intervals. The variable radians describes how many radians the spin wheel control has moved since the last time this method was called.
    @objc optional func spinWheelDidRotateByRadians(radians: CGFloat)
    
    ///스핀 뷰 중앙 터치
    @objc optional func spinWheelCenterTap()
}
