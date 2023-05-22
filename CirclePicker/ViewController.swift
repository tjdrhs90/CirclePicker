//
//  ViewController.swift
//  CirclePicker
//
//  Created by sgsim on 2023/04/27.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var containerView: UIStackView!
    
    @IBOutlet weak var lbl: UILabel!
    
    var spinWheelControl: SpinWheelControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
                
        if spinWheelControl == nil {
            spinWheelControl = .init(frame: containerView.frame, snapOrientation: .up) //사이즈 .zero 로 할거면 view.layoutIfNeeded() 후에 그려야 크기 정상
            spinWheelControl.dataSource = self
            spinWheelControl.delegate = self
            containerView.addArrangedSubview(spinWheelControl)
            spinWheelControl.addTarget(self, action: #selector(spinWheelDidChangeValue), for: UIControl.Event.valueChanged)
            spinWheelControl.wedgeBorderColor = .black
            spinWheelControl.reloadData()
        }
    }
    
    var randomColor: UIColor {
        let randomRed:CGFloat = CGFloat(drand48())
        let randomGreen:CGFloat = CGFloat(drand48())
        let randomBlue:CGFloat = CGFloat(drand48())
        return UIColor(red: randomRed, green: randomGreen, blue: randomBlue, alpha: 1.0)
    }
    
    @IBAction func previousBtnTap(_ sender: UIButton) {
        print(type(of: self),#function)
        spinWheelControl.movePage(isNext: false)
    }
    
    @IBAction func nextBtnTap(_ sender: UIButton) {
        print(type(of: self),#function)
        spinWheelControl.movePage(isNext: true)
    }
}

extension ViewController: SpinWheelControlDelegate {
    @objc private func spinWheelDidChangeValue(sender: AnyObject) {
        print("Selected value changed to " + String(self.spinWheelControl.selectedIndex))
        lbl.text = "value changed \(spinWheelControl.selectedIndex)"
    }
    
    func spinWheelDidEndDecelerating(spinWheel: SpinWheelControl) {
        print("spinWheelDidEndDecelerating", spinWheel.selectedIndex)
    }
    
    func didTapOnWedgeAtIndex(spinWheel: SpinWheelControl, index: UInt) {
        print("didTapOnWedgeAtIndex", index)
        lbl.text = "didTapOnWedgeAtIndex \(index)"
    }
    
    func spinWheelCenterTap() {
        print(type(of: self),#function)
        lbl.text = "pressed the center"
    }
}

extension ViewController: SpinWheelControlDataSource {
    func numberOfWedgesInSpinWheel(spinWheel: SpinWheelControl) -> UInt {
        return 6
    }

    func wedgeForSliceAtIndex(index: UInt) -> SpinWheelWedge {
        let wedge = SpinWheelWedge()
        
        wedge.label.text = "Label #" + String(index)
        wedge.shape.fillColor = randomColor.withAlphaComponent(0.1).cgColor
        //wedge.shape.fillColor = UIColor.clear.cgColor
        //wedge.shape.borderSize = .small
        
        return wedge
    }
}
