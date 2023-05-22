//
//  SpinWheelWedgeLabel.swift
//  SpinWheelPractice
//
//  Created by Josh Henry on 5/18/17.
//  Copyright © 2017 Big Smash Software. All rights reserved.
//

import UIKit

open class SpinWheelWedgeLabel: UILabel {
    
    //If no values are manually set, then set the default values here.
    private func setDefaultValues() {
        self.textColor = UIColor.white
        self.shadowColor = UIColor.black
        self.adjustsFontSizeToFitWidth = true
        self.textAlignment = .center
    }
    
    @objc public func configureWedgeLabel(index: UInt, width: CGFloat, position: CGPoint, orientation:WedgeLabelOrientation, radiansPerWedge: Radians) {
        frame = CGRect (x: 0, y: 0, width: width, height: 30)
        
        self.layer.position = position
        
        switch orientation {
        case .around:
            //Position times 2 is the total size of the control. 0.015 is the sweet spot to determine label position for any size.
            let yDistanceFromCenter: CGFloat = (position.x * 2) * 0.015
            self.layer.anchorPoint = CGPoint(x: 0.5, y: yDistanceFromCenter)
            self.transform = CGAffineTransform(rotationAngle: radiansPerWedge * CGFloat(index) + (CGFloat.pi / 2) + (radiansPerWedge / 2))
        case .outIn:
            self.layer.anchorPoint = CGPoint(x: 1.1, y: 0.5)
            self.transform = CGAffineTransform(rotationAngle: radiansPerWedge * CGFloat(index) + CGFloat.pi + (radiansPerWedge / 2))
        case .inOut:
            self.layer.anchorPoint = CGPoint(x: 0, y: 0.5)
            self.transform = CGAffineTransform(rotationAngle: radiansPerWedge * CGFloat(index) + (radiansPerWedge / 2))
        }
        
        setDefaultValues()
    }
}


class TornadoButton: UIButton {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        
        let pres = self.layer.presentation()!
        let suppt = self.convert(point, to: self.superview!)
        let prespt = self.superview!.layer.convert(suppt, to: pres)
        if (pres.hitTest(suppt)) != nil{
            return self
        }
        return super.hitTest(prespt, with: event)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let pres = self.layer.presentation()!
        let suppt = self.convert(point, to: self.superview!)
        return (pres.hitTest(suppt)) != nil
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if let t = touch {
            if self.hitTest(t.location(in: self), with: event) != nil {
                print("Tornado button with tag \(self.tag) ended tracking")
                self.sendActions(for: [.touchUpInside])
            }
        }
    }
}

class SpinWheelWedgeButton: TornadoButton {
    public func configureWedgeButton(index: UInt, width: CGFloat, position: CGPoint, radiansPerWedge: Radians) {
        //self.frame = CGRect(x: 0, y: 0, width: width, height: 30)
        self.frame = CGRect(x: 0, y: 0, width: width, height: width)
        //self.layer.anchorPoint = CGPoint(x: 2, y: 0.5)
        self.layer.anchorPoint = CGPoint(x: 2.3, y: 0.5)
        self.layer.position = position
        self.transform = CGAffineTransform(rotationAngle: radiansPerWedge * CGFloat(index) + CGFloat.pi + (radiansPerWedge / 2))
        self.backgroundColor = .green.withAlphaComponent(0.1)
        self.addTarget(self, action: #selector(pressed(_:)), for: .touchUpInside)
    }
    @IBAction func pressed(_ sender: TornadoButton) {
        print("If you see this you won! \(tag)")
    }
}
