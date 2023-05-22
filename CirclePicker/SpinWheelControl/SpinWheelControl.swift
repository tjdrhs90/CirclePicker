//
//  SpinWheelControl.swift
//  SpinWheelControl
//
//  Created by Josh Henry on 4/27/17.
//  Copyright © 2017 Big Smash Software. All rights reserved.
//
//Trigonometry is used extensively in SpinWheel Control. Here is a quick refresher.
//Sine, Cosine and Tangent are each a ratio of sides of a right angled triangle
//Arc tangent (atan2) calculates the angles of a right triangle (tangent = Opposite / Adjacent)
//The sin is ratio of the length of the side that is opposite that angle to the length of the longest side of the triangle (the hypotenuse) (sin = Opposite / Hypotenuse)
//The cosine is (cosine = Adjacent / Hypotenuse)

import UIKit

public typealias Degrees = CGFloat
public typealias Radians = CGFloat
typealias Velocity = CGFloat

public enum SpinWheelStatus {
    case idle, decelerating, snapping
}

public enum SpinWheelDirection {
    case up, upRight, right, downRight, down, downLeft, left, upLeft
    
    var radiansValue: Radians {
        switch self {
        case .up:
            return Radians.pi / 2
        case .upRight:
            return Radians.pi / 4
        case .right:
            return 0
        case .downRight:
            return -(Radians.pi / 4)
        case .down:
            return -(Radians.pi / 2)
        case .downLeft:
            return -((Radians.pi / 4) * 3)
        case .left:
            return Radians.pi
        case .upLeft:
            return Radians.pi - (Radians.pi / 4)
        }
    }
    
    var degreesValue: Degrees {
        switch self {
        case .up:
            return 90
        case .upRight:
            return 45
        case .right:
            return 0
        case .downRight:
            return 315
        case .down:
            return 270
        case .downLeft:
            return 225
        case .left:
            return 180
        case .upLeft:
            return 135
        }
    }
}


@objc public enum WedgeLabelOrientation: Int {
    case inOut
    case outIn
    case around
}


@objc public enum WedgeBorderSize: Int {
    case none
    case small
    case medium
    case large
}


@IBDesignable
open class SpinWheelControl: UIControl {
    
    //MARK: Properties
    @IBInspectable var borderWidth: CGFloat = 0 {
        didSet {
            layer.borderWidth = borderWidth
        }
    }
    
    
    @IBInspectable var borderColor: UIColor? {
        didSet {
            layer.borderColor = borderColor?.cgColor
        }
    }
    
    
    @IBInspectable public var wedgeBorderColor: UIColor = UIColor.white {
        didSet {
            self.wedgeStrokeColor = wedgeBorderColor
        }
    }
    
    
    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            layer.cornerRadius = cornerRadius
            layer.masksToBounds = cornerRadius > 0
        }
    }
    
    
    @IBInspectable var snapOrientation: CGFloat = SpinWheelDirection.up.degreesValue {
        didSet {
            snappingPositionRadians = snapOrientation.toRadians
        }
    }
    
    
    @IBInspectable var wedgeLabelOrientation: Int {
        get {
            return self.wedgeLabelOrientationIndex.rawValue
        }
        set (wedgeLabelOrientationIndex) {
            self.wedgeLabelOrientationIndex = WedgeLabelOrientation(rawValue: wedgeLabelOrientationIndex) ?? WedgeLabelOrientation.inOut
        }
    }
    
    
    @objc weak public var dataSource: SpinWheelControlDataSource?
    @objc public var delegate: SpinWheelControlDelegate?
    
    //Constants
    @objc static let kMinimumRadiansForSpin: Radians = 0.1
    @objc static let kMinDistanceFromCenter: CGFloat = 30.0
    @objc static let kMaxVelocity: Velocity = 30 //20 //ssg 내가 수정한 부분
    @objc static let kDecelerationVelocityMultiplier: CGFloat = 0.98 //The deceleration multiplier is not to be set past 0.99 in order to avoid issues
    @objc static let kSpeedToSnap: CGFloat = 20 //0.1 //ssg 내가 수정한 부분
    @objc static let kSnapRadiansProximity: Radians = 0.001
    @objc static let kWedgeSnapVelocityMultiplier: CGFloat = 10.0
    @objc static let kZoomZoneThreshold = 1.5
    @objc static let kPreferredFramesPerSecond: Int = 120
    @objc static let kMinRandomSpinVelocity: Velocity = 12
    @objc static let kDefaultSpinVelocityMultiplier: Velocity = 0.75
    @objc let kCircleRadians: Radians = 2 * CGFloat.pi //A circle = 360 degrees = 2 * pi radians
    
    @objc public var spinWheelView: UIView!
    
    private var numberOfWedges: UInt!
    private var radiansPerWedge: CGFloat!
    
    @objc var decelerationDisplayLink: CADisplayLink? = nil
    @objc var snapDisplayLink: CADisplayLink? = nil
    
    var startTrackingTime: CFTimeInterval!
    var endTrackingTime: CFTimeInterval!
    
    var currentStatus: SpinWheelStatus = .idle
    
    var previousTouchRadians: Radians!
    var currentTouchRadians: Radians!
    var startTouchRadians: Radians!
    var totalRotationRadians: Radians = Radians(0)
    var currentlyDetectingTap: Bool!
    
    var snapDestinationRadians: Radians!
    var snapIncrementRadians: Radians!
    
    var currentDecelerationVelocity: Velocity!
    
    @objc var snappingPositionRadians: Radians = SpinWheelDirection.up.radiansValue
    
    @objc public var wedgeStrokeColor: UIColor = UIColor.white
    
    var wedgeLabelOrientationIndex: WedgeLabelOrientation = WedgeLabelOrientation.inOut
    
    @objc public var selectedIndex: Int = 0
    
    
    //MARK: Computed Properties
    @objc var spinWheelCenter: CGPoint {
        return convert(center, from: superview)
    }
    
    
    //The diameter of the spin wheel
    @objc var diameter: CGFloat {
        return min(self.spinWheelView.frame.width, self.spinWheelView.frame.height)
    }
    
    
    //How many degrees per wedge.
    @objc var degreesPerWedge: Degrees {
        return 360 / CGFloat(numberOfWedges)
    }
    
    
    //The radius of the spin wheel's circle
    @objc var radius: CGFloat {
        return diameter / 2
    }
    
    
    //How far the wheel is turned from its default position
    @objc var currentRadians: Radians {
        return atan2(self.spinWheelView.transform.b, self.spinWheelView.transform.a)
    }
    
    
    //How many radians there are to snapDestinationRadians
    @objc var radiansToDestinationSlice: Radians {
        return snapDestinationRadians - currentRadians
    }
    
    
    //The velocity of the spinwheel
    @objc var velocity: Velocity {
        var computedVelocity: Velocity = 0
        
        //If the wheel was actually spun, calculate the new velocity
        if endTrackingTime != startTrackingTime &&
            abs(previousTouchRadians - currentTouchRadians) >= SpinWheelControl.kMinimumRadiansForSpin {
            computedVelocity = (previousTouchRadians - currentTouchRadians) / CGFloat(endTrackingTime - startTrackingTime)
        }
        
        //If the velocity is beyond the maximum allowed velocity, throttle it
        if computedVelocity > SpinWheelControl.kMaxVelocity {
            computedVelocity = SpinWheelControl.kMaxVelocity
        }
        else if computedVelocity < -SpinWheelControl.kMaxVelocity {
            computedVelocity = -SpinWheelControl.kMaxVelocity
        }
        
        return computedVelocity
    }
    
    
    //MARK: Initialization Methods
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        self.drawWheel()
    }
    
    
    public init(frame: CGRect, snapOrientation: SpinWheelDirection) {
        super.init(frame: frame)
        
        self.snappingPositionRadians = snapOrientation.radiansValue
        
        self.drawWheel()
    }
    
    
    public init(frame: CGRect, wedgeLabelOrientation: WedgeLabelOrientation) {
        super.init(frame: frame)
        self.wedgeLabelOrientationIndex = wedgeLabelOrientation
        
        self.drawWheel()
    }
    
    
    public init(frame: CGRect, snapOrientation: SpinWheelDirection, wedgeLabelOrientation: WedgeLabelOrientation) {
        super.init(frame: frame)
        self.wedgeLabelOrientationIndex = wedgeLabelOrientation
        
        self.snappingPositionRadians = snapOrientation.radiansValue
        
        self.drawWheel()
    }
    
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.drawWheel()
    }
    
    
    //Return the radians at the touch point. Return values range from -pi to pi
    @objc func radiansForTouch(touch: UITouch) -> Radians {
        let touchPoint: CGPoint = touch.location(in: self)
        let dx: CGFloat = touchPoint.x - self.spinWheelView.center.x
        let dy: CGFloat = touchPoint.y - self.spinWheelView.center.y
        
        return atan2(dy, dx)
    }
    
    
    //Distance of a point from the center of the spinwheel
    @objc func distanceFromCenter(point: CGPoint) -> CGFloat {
        let dx: CGFloat = point.x - spinWheelCenter.x
        let dy: CGFloat = point.y - spinWheelCenter.y
        
        return sqrt(dx * dx + dy * dy)
    }
    
    
    //MARK: Methods
    //Clear the SpinWheelControl from the screen
    @objc public func clear() {
        for subview in spinWheelView.subviews {
            subview.removeFromSuperview()
        }
        guard let sublayers = spinWheelView.layer.sublayers else {
            return
        }
        for sublayer in sublayers {
            sublayer.removeFromSuperlayer()
        }
        //ssg 내가 추가한 부분
        removeWedgeFixViews()
    }
    
    
    //Draw the spinWheelView
    @objc public func drawWheel() {
        spinWheelView = UIView(frame: self.bounds)
        
        guard self.dataSource?.numberOfWedgesInSpinWheel(spinWheel: self) != nil else {
            return
        }
        numberOfWedges = self.dataSource?.numberOfWedgesInSpinWheel(spinWheel: self)
        
        guard numberOfWedges >= 2 else {
            return
        }
        
        radiansPerWedge = kCircleRadians / CGFloat(numberOfWedges)
        
        guard let source = self.dataSource else {
            return
        }
        
        for wedgeNumber in 0..<numberOfWedges {
            let wedge: SpinWheelWedge = source.wedgeForSliceAtIndex(index: wedgeNumber)
            
            //Wedge shape
            wedge.shape.configureWedgeShape(index: wedgeNumber, radius: radius, position: spinWheelCenter, degreesPerWedge: degreesPerWedge)
            wedge.shape.strokeColor = self.wedgeStrokeColor.cgColor
            wedge.layer.addSublayer(wedge.shape)
            
            //Wedge label
            wedge.label.configureWedgeLabel(index: wedgeNumber, width: radius * 0.9, position: spinWheelCenter, orientation: self.wedgeLabelOrientationIndex, radiansPerWedge: radiansPerWedge)
            wedge.addSubview(wedge.label)
            
            //Wedge button //ssg 내가 추가한 부분
            wedge.button.configureWedgeButton(index: wedgeNumber, width: radius * 0.4, position: spinWheelCenter, radiansPerWedge: radiansPerWedge)
            wedge.addSubview(wedge.button)
            
            //Wedge fix view //ssg 내가 추가한 부분
            let sv = UIStackView()
            wedgeFixViews.append(sv)
            let tag = Int(wedgeNumber)
            sv.tag = tag
            wedge.tag = tag
            
            //Add the shape and label to the spinWheelView
            spinWheelView.addSubview(wedge)
        }
        
        self.spinWheelView.isUserInteractionEnabled = false
        
        //Rotate the wheel to put the first wedge at the top
        self.spinWheelView.transform = CGAffineTransform(rotationAngle: -(snappingPositionRadians) - (radiansPerWedge / 2))
        
        self.addSubview(self.spinWheelView)
        
        wedgeFixViewContainer.isUserInteractionEnabled = false
        wedgeFixViewContainer.frame = self.bounds
        self.addSubview(wedgeFixViewContainer)
        
        //ssg 내가 추가한 부분
        wedgeFixViews.forEach {
            $0.backgroundColor = .blue.withAlphaComponent(0.1)
            $0.isUserInteractionEnabled = false
            $0.frame.size = .init(width: 50, height: 50)
            wedgeFixViewContainer.addSubview($0)
        }
    }
    
    
    //Clear all views and redraw the spin wheel
    @objc public func reloadData() {
        clear()
        drawWheel()
    }
    
    
    //Handle a tap action.
    @objc func handleTap() {
        var indexTapped: Radians = (startTouchRadians - currentRadians  - (radiansPerWedge / 2)) / radiansPerWedge
        indexTapped = indexTapped.rounded(FloatingPointRoundingRule.toNearestOrAwayFromZero)
        indexTapped = indexTapped + CGFloat(numberOfWedges)
        indexTapped = indexTapped.truncatingRemainder(dividingBy: CGFloat(numberOfWedges))
        
        delegate?.didTapOnWedgeAtIndex?(spinWheel: self, index: UInt(indexTapped))
    }
    
    
    //Spin the wheel with a given velocity multiplier (or default velocity multiplier if no velocity provided)
    //TODO: Due to a bug in Swift 4, private constants cannot be used as default arguments when Enable Testability is turned on. Therefore,
    //the default velocity multiplier value is hand-coded until this is fixed.
    //More info: https://bugs.swift.org/browse/SR-5111
    //    @objc public func spin(velocityMultiplier: CGFloat = SpinWheelControl.kDefaultSpinVelocityMultiplier) {
    @objc public func spin(velocityMultiplier: CGFloat = 0.75) {
        //If the velocity multiplier is valid, spin the wheel.
        if (0...1).contains(velocityMultiplier) {
            beginDeceleration(withVelocity: SpinWheelControl.kMaxVelocity * velocityMultiplier)
        }
    }
    
    
    //Perform a random spin of the wheel
    @objc public func randomSpin() {
        //Get the range to find a random number between
        let range = UInt32(SpinWheelControl.kMaxVelocity - SpinWheelControl.kMinRandomSpinVelocity)
        
        //The velocity subtractor is a random number between 1 and the range value
        let velocitySubtractor = Double(arc4random_uniform(range)) + 1
        
        //Subtract the velocity subtractor from max velocity to get the final random velocity
        let randomSpinVelocity = Velocity(Double(SpinWheelControl.kMaxVelocity) - velocitySubtractor)
        
        //Get the spin multiplier using the new random spin velocity value
        let randomSpinMultiplier = randomSpinVelocity / SpinWheelControl.kMaxVelocity
        
        spin(velocityMultiplier: randomSpinMultiplier)
    }
    
    
    //User began touching/dragging the UIControl
    override open func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        //ssg
        beginTrackingFlag = true
        
        switch currentStatus {
        case SpinWheelStatus.idle:
            currentlyDetectingTap = true
        case SpinWheelStatus.decelerating:
            endDeceleration()
            endSnap()
        case SpinWheelStatus.snapping:
            endSnap()
        }
        
        let touchPoint: CGPoint = touch.location(in: self)
        
        if distanceFromCenter(point: touchPoint) < SpinWheelControl.kMinDistanceFromCenter {
            return false
        }
        
        startTrackingTime = CACurrentMediaTime()
        endTrackingTime = startTrackingTime
        
        startTouchRadians = radiansForTouch(touch: touch)
        currentTouchRadians = startTouchRadians
        previousTouchRadians = startTouchRadians
        
        return true
    }
    
    
    //User is in the middle of dragging the UIControl
    override open func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        currentlyDetectingTap = false
        
        startTrackingTime = endTrackingTime
        endTrackingTime = CACurrentMediaTime()
        
        let touchPoint: CGPoint = touch.location(in: self)
        let distanceFromCenterOfSpinWheel: CGFloat = distanceFromCenter(point: touchPoint)
        
        if distanceFromCenterOfSpinWheel < SpinWheelControl.kMinDistanceFromCenter {
            return true
        }
        
        previousTouchRadians = currentTouchRadians
        currentTouchRadians = radiansForTouch(touch: touch)
        let touchRadiansDifference: Radians = currentTouchRadians - previousTouchRadians
        
        self.spinWheelView.transform = self.spinWheelView.transform.rotated(by: touchRadiansDifference)
        
        //ssg 수정
        spinWheelDidRotateByRadians(radians: touchRadiansDifference)
        
        totalRotationRadians += touchRadiansDifference
        
        return true
    }
    
    
    //User ended touching/dragging the UIControl
    override open func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        //ssg
        beginTrackingFlag = false
        
        let tapCount = touch?.tapCount != nil ? (touch?.tapCount)! : 0
        
        //If just tapped, handle accordingly
        //Ideally this would catch all taps, but taps also need to be handled in decelerationStep function
        if currentStatus == .idle &&
            tapCount > 0 &&
            currentlyDetectingTap {
            handleTap()
        }
            //Else it was a spin. Start deceleration process.
        else {
            beginDeceleration()
        }
    }
    
    
    //After user has lifted their finger from dragging, begin the deceleration
    func beginDeceleration(withVelocity customVelocity: Velocity? = nil) {
        if let customVelocity = customVelocity, customVelocity <= SpinWheelControl.kMaxVelocity {
            currentDecelerationVelocity = customVelocity
        } else {
            currentDecelerationVelocity = velocity
        }
        
        //If the wheel was spun, begin deceleration
        if currentDecelerationVelocity != 0 {
            currentStatus = .decelerating
            
            decelerationDisplayLink?.invalidate()
            decelerationDisplayLink = CADisplayLink(target: self, selector: #selector(SpinWheelControl.decelerationStep))
            if #available(iOS 10.0, *) {
                decelerationDisplayLink?.preferredFramesPerSecond = SpinWheelControl.kPreferredFramesPerSecond
            }
            else {
                // TODO: Fallback on earlier versions
                decelerationDisplayLink?.preferredFramesPerSecond = SpinWheelControl.kPreferredFramesPerSecond
            }
            decelerationDisplayLink?.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
        }
            //Else snap to the nearest wedge.  No deceleration necessary.
        else {
            snapToNearestWedge()
        }
    }
    
    
    //Deceleration step run for each frame of decelerationDisplayLink
    @objc func decelerationStep() {
        let newVelocity: Velocity = currentDecelerationVelocity * SpinWheelControl.kDecelerationVelocityMultiplier
        let radiansToRotate: Radians = currentDecelerationVelocity / CGFloat(SpinWheelControl.kPreferredFramesPerSecond)
        
        //If the spinwheel has slowed down to under the minimum speed, end the deceleration
        if newVelocity <= SpinWheelControl.kSpeedToSnap &&
            newVelocity >= -SpinWheelControl.kSpeedToSnap {
            endDeceleration()
        }
            //else continue decelerating the SpinWheel
        else {
            currentDecelerationVelocity = newVelocity
            self.spinWheelView.transform = self.spinWheelView.transform.rotated(by: -radiansToRotate)
            //ssg 수정
            spinWheelDidRotateByRadians(radians: -radiansToRotate)
        }
    }
    
    
    //End decelerating the spinwheel
    @objc func endDeceleration() {
        decelerationDisplayLink?.invalidate()
        snapToNearestWedge()
    }
    
    
    //Snap to the nearest wedge
    @objc func snapToNearestWedge() {
        //ssg 0.2.1 버전에서 아래와 같이 작성되어 있는데 스핀 중에 손으로 잡았다 움직이지 않고 놓으면 그 자리에 멈춰서 주석 처리 하고
//        //If this was just a tap, handle accordingly
//        if (totalRotationRadians == 0) {
//            handleTap()
//        }
//            //Else it was a spin, snap to wedge.
//        else {
//            currentStatus = .snapping
//
//            let sumRadians = ((currentRadians + (radiansPerWedge / 2)) + snappingPositionRadians)
//            let nearestWedge: Int = Int(round(sumRadians / radiansPerWedge))
//
//            selectWedgeAtIndexOffset(index: nearestWedge, animated: true)
//        }
//
//        //Reset the total touch radians
//        totalRotationRadians = Radians(0)
        
        
        //ssg 0.2.0 버전에서 적힌대로 아래와 같이 작성하니 스핀 중에 손으로 잡았다 움직이지 않고 놓아도 그 자리에 멈추지 않고 각도에 맞게 이동함
        currentStatus = .snapping
        
        let nearestWedge: Int = Int(round(((currentRadians + (radiansPerWedge / 2)) + snappingPositionRadians) / radiansPerWedge))
        
        selectWedgeAtIndexOffset(index: nearestWedge, animated: true)
    }
    
    
    //One snap step of CADisplayLink
    @objc func snapStep() {
        let difference: Radians = atan2(sin(radiansToDestinationSlice), cos(radiansToDestinationSlice))
        
        //If the spin wheel is turned close enough to the destination it is snapping to, end snapping
        if abs(difference) <= SpinWheelControl.kSnapRadiansProximity {
            endSnap()
        }
            //else continue snapping to the nearest wedge
        else {
            let newPositionRadians: Radians = currentRadians + snapIncrementRadians
            self.spinWheelView.transform = CGAffineTransform(rotationAngle: newPositionRadians)
            
            //ssg 수정
            spinWheelDidRotateByRadians(radians: newPositionRadians)
        }
    }
    
    
    //End snapping
    @objc func endSnap() {
        //snappingPositionRadians is the default snapping position (in this case, up)
        //currentRadians in this case is where in the wheel it is currently snapped
        //Distance of zero wedge from the default snap position (up)
        var indexSnapped: Radians = (-(snappingPositionRadians) - currentRadians - (radiansPerWedge / 2))
        
        //Number of wedges from the zero wedge to the default snap position (up)
        indexSnapped = indexSnapped / radiansPerWedge + CGFloat(numberOfWedges)
        indexSnapped = indexSnapped.rounded(FloatingPointRoundingRule.toNearestOrAwayFromZero)
        indexSnapped = indexSnapped.truncatingRemainder(dividingBy: CGFloat(numberOfWedges))
        
        didEndRotationOnWedgeAtIndex(index: UInt(indexSnapped))
        
        snapDisplayLink?.invalidate()
        currentStatus = .idle
    }
    
    
    //When the SpinWheelControl ends rotation, trigger the UIControl's valueChanged to reflect the newly selected value.
    @objc func didEndRotationOnWedgeAtIndex(index: UInt) {
        selectedIndex = Int(index)
        delegate?.spinWheelDidEndDecelerating?(spinWheel: self)
        
        //ssg 움직이는 도중에 손으로 잡았을 때는 밸류 체인지를 실행시키지 않고 손을 떼고 멈췄을 때만 밸류 체인지 함수 실행
        if beginTrackingFlag == false {
            self.sendActions(for: .valueChanged)
        }
    }
    
    
    //Select a wedge with an index offset relative to 0 position. May be positive or negative.
    @objc func selectWedgeAtIndexOffset(index: Int, animated: Bool) {
        snapDestinationRadians = -(snappingPositionRadians) + (CGFloat(index) * radiansPerWedge) - (radiansPerWedge / 2)
        
        if currentRadians != snapDestinationRadians {
            snapIncrementRadians = radiansToDestinationSlice / SpinWheelControl.kWedgeSnapVelocityMultiplier
        }
        else {
            return
        }
        
        currentStatus = .snapping
        
        snapDisplayLink?.invalidate()
        snapDisplayLink = CADisplayLink(target: self, selector: #selector(snapStep))
        if #available(iOS 10.0, *) {
            snapDisplayLink?.preferredFramesPerSecond = SpinWheelControl.kPreferredFramesPerSecond
        } else {
            // TODO: Fallback on earlier versions
            snapDisplayLink?.preferredFramesPerSecond = SpinWheelControl.kPreferredFramesPerSecond
        }
        snapDisplayLink?.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
    }
    
    //MARK: - ssg 아래 부터 내가 추가한 부분
    
    ///페이지 이동 연타 시 사용할 타이머
    private var movePageTimer = Timer()
    
    /// 웨지 이동
    /// - Parameter isNext: 다음인지 이전인지 Bool 값
    func movePage(isNext: Bool) {
        ///selectedIndex 가 될 인덱스
        var moveIdx = selectedIndex
        ///마지막 인덱스
        let lastIdx = Int(numberOfWedges) - 1
        
        if isNext { //다음일 경우
            if moveIdx == 0 { //첫번째 인덱스면
                moveIdx = lastIdx //마지막 인덱스로 지정
            } else { //첫번째 인덱스 아닐 경우 - 1
                moveIdx -= 1
            }
        } else { //이전일 경우
            if moveIdx == lastIdx { //마지막 인덱스면
                moveIdx = 0 //0으로 지정
            } else { //마지막 인덱스 아닐 경우 + 1
                moveIdx += 1
            }
        }
        
        //이동 버튼 연타 시 계산을 위해 selectedIndex 지정
        selectedIndex = moveIdx
        
        ///한 조각 당 각도
        let calcAngle: CGFloat = (.pi * 2) / CGFloat(numberOfWedges)
        
        ///회전할 각도
        var spinWheelViewAngle: CGFloat {
            if isNext {
                return currentRadians + calcAngle //현재 각도 플러스 회전할 각도
            } else {
                return currentRadians - calcAngle
            }
        }
        ///회전할 각도
        var wedgeFixViewAngle: CGFloat {
            if isNext {
                return wedgeFixViewCurrentRadians + calcAngle //현재 각도 플러스 회전할 각도
            } else {
                return wedgeFixViewCurrentRadians - calcAngle
            }
        }
        
        //이동 버튼 연타 시 마지막 이동 후에 완료 델리게이트 날리기 위해 타이머 추가
        movePageTimer.invalidate()
        
        ///이동 시간
        let duration: TimeInterval = 0.3
                
        //이동 시작
        UIView.animate(withDuration: duration) { [weak self] in
            guard let self else { return }
            spinWheelView.transform = .init(rotationAngle: spinWheelViewAngle) //전체 스핀휠뷰 회전
            wedgeFixViewContainer.transform = .init(rotationAngle: wedgeFixViewAngle) //웨지 고정뷰 컨테이너 먼저 회전
            wedgeFixViews.forEach {
                $0.transform = .init(rotationAngle: -self.wedgeFixViewCurrentRadians) //각 웨지 고정 뷰를 컨테이너 회전한 만큼 반대로 회전
            }
        }
        //마지막 이동 완료 후 델리게이트 날림
        movePageTimer = .scheduledTimer(withTimeInterval: duration, repeats: false, block: { [weak self] _ in
            self?.didEndRotationOnWedgeAtIndex(index: UInt(moveIdx))
        })
    }
    
    ///웨지 고정 뷰 컨테이너가 얼마나 회전했는지 값
    @objc var wedgeFixViewCurrentRadians: Radians {
        return atan2(self.wedgeFixViewContainer.transform.b, self.wedgeFixViewContainer.transform.a)
    }
    
    ///각 웨지에 앵글 고정되어 회전할 뷰들을 감쌀 뷰
    private var wedgeFixViewContainer = UIView()
    ///각 웨지에 앵글 고정되어 회전할 뷰 배열
    var wedgeFixViews = [UIStackView]()
    
    ///웨지 고정 뷰 제거
    private func removeWedgeFixViews() {
        wedgeFixViews.forEach {
            $0.removeFromSuperview()
        }
        wedgeFixViews.removeAll()
    }
    
    ///웨지 고정뷰 위치 조정
    @objc private func setFixViewPosition() {
        let wedges = spinWheelView.subviews.compactMap { $0 as? SpinWheelWedge }
        
        wedges.forEach { wedge in
            guard let fixView = wedgeFixViews.first(where: { $0.tag == wedge.tag }) else { return }
            
            let btn = wedge.button
            let rect = btn.convert(btn.bounds, to: self)
            
            fixView.center = .init(x: rect.midX, y: rect.midY)
        }
    }
    
    ///회전 Tracking 델리게이트
    private func spinWheelDidRotateByRadians(radians: CGFloat) {
        setFixViewPosition()
        delegate?.spinWheelDidRotateByRadians?(radians: radians)
    }
    
    //스핀뷰 다 그려졌을 경우
    open override func draw(_ rect: CGRect) {
        super.draw(rect)
        setFixViewPosition() //고정뷰 위치 조정
        //setCenterBtn() //중앙 버튼 설정
        setCenterView() //중앙 뷰 설정
    }
    
//    ///중앙 버튼
//    private var centerBtn = UIButton(type: .system)
//    ///중앙 버튼 설정
//    private func setCenterBtn() {
//        let size: CGFloat = 100
//
//        centerBtn.backgroundColor = .red.withAlphaComponent(0.1)
//        centerBtn.layer.cornerRadius = size / 2
//        centerBtn.addTarget(self, action: #selector(centerBtnTap), for: .touchUpInside)
//
//        centerBtn.removeFromSuperview()
//        self.addSubview(centerBtn)
//        centerBtn.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            centerBtn.widthAnchor.constraint(equalToConstant: size),
//            centerBtn.heightAnchor.constraint(equalTo: centerBtn.widthAnchor, multiplier: 1),
//            centerBtn.centerXAnchor.constraint(equalTo: self.centerXAnchor),
//            centerBtn.centerYAnchor.constraint(equalTo: self.centerYAnchor)
//        ])
//    }
//    ///중앙 버튼 터치
//    @objc private func centerBtnTap() {
//        delegate?.spinWheelCenterTap?()
//    }
    
    ///중앙 뷰
    private var centerView = UIStackView()
    ///중앙 뷰 설정
    private func setCenterView() {
        let size: CGFloat = 100
        
        centerView.backgroundColor = .red.withAlphaComponent(0.1)
        centerView.layer.cornerRadius = size / 2
        centerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(centerViewTap)))
        
        centerView.removeFromSuperview()
        self.addSubview(centerView)
        centerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            centerView.widthAnchor.constraint(equalToConstant: size),
            centerView.heightAnchor.constraint(equalTo: centerView.widthAnchor, multiplier: 1),
            centerView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            centerView.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }
    ///중앙 뷰 터치
    @objc private func centerViewTap() {
        delegate?.spinWheelCenterTap?()
    }
    
    ///움직이는 도중에 손으로 잡았을 때는 밸류 체인지를 실행시키지 않기 위해 플래그 값 추가 (손을 떼고 멈췄을 때만 밸류 체인지 함수 실행)
    private var beginTrackingFlag = false
}
