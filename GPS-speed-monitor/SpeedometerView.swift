import UIKit
import CoreGraphics

let π:CGFloat = CGFloat(M_PI)
let deg2rad = M_PI/180.0
let rad2deg = 180.0/M_PI

@IBDesignable class SpeedometerView: UIView {
	//Drawing variables and constants
	private let smallLargeRadiusRatio:CGFloat = 4
	private let speedometerStrokeWidth:CGFloat = 2
	private let speedStrokeWidth:CGFloat = 5
	private let speedLimitStrokeWidth:CGFloat = 2
	
	private var centerPoint = CGPoint()
	private var largeRadius = CGFloat()
	private var smallRadius = CGFloat()
	
	private var maxSpeed:Double = 200 // km/h
	
	@IBInspectable private var speedLabel:UILabel = UILabel()
	@IBInspectable private var speedUnitLabel:UILabel = UILabel()
	@IBInspectable private var speedLimitLabel: UILabel = UILabel()
	
	@IBInspectable var speedColor: UIColor = UIColor.whiteColor()
	
	@IBInspectable var speed: Double = 96 {
		didSet {
			if speed < 0 {
				speed = 0
			}
			if speed != oldValue {
				setNeedsDisplay()
				setNeedsLayout()
			}
		}
	}
	
	@IBInspectable var speedLimit: uint = 100 {
		didSet {
			if speedLimit > 0 && speedLimit <= 110 {
				maxSpeed = Double(speedLimit)*2
			} else if speedLimit <= 0{
				speedLimit = 0
				maxSpeed = 200
			}
			if speedLimit != oldValue {
				setNeedsDisplay()
				setNeedsLayout()
			}
		}
	}

	
	override init(frame: CGRect) {
		super.init(frame: frame)
		//print("Frame init")
		didLoad()
		
	}
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		//print("Coder init")
		didLoad()
	}
	
	convenience init() {
		self.init(frame: CGRectZero)
		//print("Convenience init")
		didLoad()
	}
	
	func didLoad() {
		addSubview(speedLabel)
		addSubview(speedUnitLabel)
		addSubview(speedLimitLabel)
	}
	
	
	override func layoutSubviews() {
		//layer.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.2).CGColor
		let aspecRatio = (2*smallLargeRadiusRatio)/11
		if (bounds.height >= bounds.width*aspecRatio) { //With is limit
			largeRadius = bounds.width/2
		} else { //Height is limit
			largeRadius = (bounds.height * smallLargeRadiusRatio)/(2 * smallLargeRadiusRatio + 1)
		}
		smallRadius = largeRadius/smallLargeRadiusRatio
		centerPoint = CGPoint(x: bounds.size.width/2, y: bounds.size.height/2 - smallRadius/2)
/*		print("Frame size \(frame.size)")
		print("Aspect ratio \(aspecRatio)")
		print("Bounds \(bounds)")
		print("Center \(center)")
		print("Center point: \(centerPoint)")
		print("Large radi \(largeRadius), small radi \(smallRadius)")
*/
		
		//Speed label
		let speedFontSize = CGFloat(largeRadius*2/3)
		speedLabel.textAlignment = NSTextAlignment.Center
		speedLabel.text = String(Int(speed))
		speedLabel.font = UIFont.systemFontOfSize(speedFontSize, weight: UIFontWeightUltraLight )
		speedLabel.textColor = UIColor.whiteColor()
		let speedLabelSize = CGSize(width:  bounds.size.width,
		                            height: speedLabel.requiredHeight())
		let speedLabelOrigin = CGPoint(x: centerPoint.x - speedLabelSize.width/2,
		                               y: centerPoint.y - speedLabelSize.height/2)
		speedLabel.frame = CGRect(origin: speedLabelOrigin, size: speedLabelSize)
		
		
		//Speed unit label
		speedUnitLabel.text = "km/h"
		speedUnitLabel.textAlignment = NSTextAlignment.Center
		speedUnitLabel.font = UIFont.systemFontOfSize(25, weight: UIFontWeightUltraLight )
		speedUnitLabel.textColor = UIColor.whiteColor()
		let speedUnitLabelSize = CGSize(width: speedLabelSize.width,
		                                height: speedUnitLabel.requiredHeight())
		let speedUnitLabelOrigin = CGPoint(x: centerPoint.x - speedUnitLabelSize.width/2,
		                                   y: speedLabelOrigin.y + speedLabelSize.height - speedUnitLabelSize.height/2)
		speedUnitLabel.frame = CGRect(origin: speedUnitLabelOrigin, size: speedUnitLabelSize)
		
		//Speed limit label
		let speedLimitFontSize = 1.5*speedFontSize/smallLargeRadiusRatio
		let speedLimitLabelSize = CGSize(width: smallRadius*2, height: smallRadius*2)
		let speedLimitLabelOrigin = CGPoint(x: centerPoint.x - speedLimitLabelSize.width/2,
		                                    y: centerPoint.y - speedLimitLabelSize.height/2 + largeRadius )
		
		var speedLimitString:String
		if speedLimit == 0 {
			speedLimitString = "?"
		} else {
			speedLimitString = String(speedLimit)
		}
		speedLimitLabel.frame = CGRect(origin: speedLimitLabelOrigin, size: speedLimitLabelSize)
		speedLimitLabel.layer.borderColor = UIColor.whiteColor().CGColor
		speedLimitLabel.layer.borderWidth = speedLimitStrokeWidth;
		speedLimitLabel.layer.cornerRadius = speedLimitLabel.frame.height/2
		speedLimitLabel.textAlignment = NSTextAlignment.Center
		speedLimitLabel.text = speedLimitString
		speedLimitLabel.font = UIFont.systemFontOfSize(speedLimitFontSize, weight: UIFontWeightThin )
		speedLimitLabel.textColor = UIColor.whiteColor()
		speedLimitLabel.adjustsFontSizeToFitWidth = true
	}

	override func drawRect(rect: CGRect) {
		//Speedometer outline
		let speedometerStartAngle = CGFloat(108*deg2rad) //TODO: Need to be calculated
		let speedometerEndAngle = CGFloat(72*deg2rad)	 //TODO: Need to be calculated
		let dotOutlinePath = UIBezierPath(
			arcCenter:	centerPoint,
			radius:		largeRadius-speedStrokeWidth/2,
			startAngle: speedometerStartAngle,
			endAngle:	speedometerEndAngle,
			clockwise:	true)
		dotOutlinePath.lineWidth = speedometerStrokeWidth
		dotOutlinePath.setLineDash([2.0, 2.0], count: 2, phase: 1)
		UIColor.whiteColor().setStroke()
		dotOutlinePath.stroke()
		
		//Speed
		let totalAngle = abs( CGFloat(2*M_PI) - speedometerStartAngle + speedometerEndAngle )
		let arcAngleKMPH = CGFloat(speed/maxSpeed) * totalAngle
		let speedOutlinePath = UIBezierPath(
			arcCenter: centerPoint,
			radius: largeRadius-speedStrokeWidth/2,
			startAngle: speedometerStartAngle,
			endAngle: (speedometerStartAngle + arcAngleKMPH)%CGFloat(2*M_PI),
			clockwise: true )
		speedOutlinePath.lineWidth = speedStrokeWidth
		speedColor.setStroke()
		speedOutlinePath.stroke()

	}
}

extension UILabel{
	func requiredHeight() -> CGFloat{
		let label:UILabel = UILabel(frame: CGRectMake(0, 0, self.frame.width, CGFloat.max))
		label.numberOfLines = 0
		label.lineBreakMode = NSLineBreakMode.ByWordWrapping
		label.font = self.font
		label.text = self.text
		label.sizeToFit()
		return label.frame.height
	}
}