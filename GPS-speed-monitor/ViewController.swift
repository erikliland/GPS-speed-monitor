import UIKit
import Foundation
import CoreLocation


//Gløshaugen
//Lat:  63,415898
//Long:	10,411530

@IBDesignable class ViewController: UIViewController, CLLocationManagerDelegate, NSXMLParserDelegate {
	let debug = false
	let gradientLayer = CAGradientLayer()
	@IBOutlet weak var speedometer:SpeedometerView! = SpeedometerView()
	var locationManager: CLLocationManager! = CLLocationManager()
	var parser: NSXMLParser!
	var weHaveGPS = false {
		didSet{
			if !weHaveGPS {
				speedometer.speed = 0
				speedometer.speedLimit = 0
			}
		}
	}
	var weHaveDataset = false {
		didSet{
			if !weHaveDataset{
				speedometer.speedLimit = 0
			}
		}
	}

	
	var weAreInsideARoadObject = false
	var weAreInsideASpeedObject = false
	var currentParsedElement: String!
	var entrySpeed: uint!
	var entryPositionString = ""
	var entryPositions = [CLLocation]()
	var speedLimits = [roadObject]()
	var activeSpeedLimit:uint = 0
	let validSpeedLimits:[uint] = [30, 40, 50, 60, 70, 80, 90, 100, 110]
	

	override func viewDidLoad() {
		super.viewDidLoad()
		let notificationCenter = NSNotificationCenter.defaultCenter()
		notificationCenter.addObserver(self, selector: #selector(ViewController.applicationDidBecomeActive), name: UIApplicationDidBecomeActiveNotification, object: nil)
		initBackgroundColor()
		initLocationManager()
		initXMLParser("gloshaugen")
		initSpeedometer()
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	func applicationDidBecomeActive() {
		//print("View did become active")
		weHaveGPS = CLLocationManager.locationServicesEnabled() && (CLLocationManager.authorizationStatus() == .AuthorizedWhenInUse)
		if debug {print("We have GPS: \(weHaveGPS), We have dataset: \(weHaveDataset)") }
	}
	
	func initBackgroundColor() {
		//Set background color gradient
		let backgroundColor = UIColor(hue: 110.0/360.0, saturation: 0.9, brightness: 0.7, alpha: 1.0)
		let foregroundColor = UIColor(red: 0.37,green: 0.75, blue: 0.9, alpha: 1)
		let gradientWidth  = 0.7
		let gradientCenter = 0.43
		gradientLayer.frame = self.view.bounds
		gradientLayer.colors = [backgroundColor.CGColor, foregroundColor.CGColor]
		gradientLayer.locations = [gradientCenter-gradientWidth/2, gradientCenter+gradientWidth/2]
		view.layer.addSublayer(gradientLayer)
	}
	
	func initSpeedometer() {
		speedometer.superview?.bringSubviewToFront(speedometer)
		speedometer.backgroundColor = UIColor.clearColor()
	}
	
	//MARK: XML Parser
	func initXMLParser(file: String) {
		let urlpath = NSBundle.mainBundle().pathForResource(file, ofType: "xml")
		if urlpath != nil{
			let url:NSURL = NSURL.fileURLWithPath(urlpath!)
			parser = NSXMLParser(contentsOfURL: url)!
			parser.delegate = self
			parser.parse()
			weHaveDataset = true
		} else {
			weHaveDataset = false
		}
	}
	
	func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]){
		currentParsedElement = elementName
		if (elementName as NSString).isEqualToString("vegObjekt"){
			if debug { print("didStartElement \t\(elementName)") }
			weAreInsideARoadObject = true
		}
		if weAreInsideARoadObject {
			if (elementName as NSString).isEqualToString("kortVerdi"){
				if debug { print("didStartElement \t\(elementName)") }
				weAreInsideASpeedObject = true
			} else if (elementName as NSString).isEqualToString("geometriWgs84"){
				if debug { print("didStartElement \t\(elementName)") }
			}
		}
	}
	
	func parser(parser: NSXMLParser, foundCharacters string: String){
		if weAreInsideARoadObject{
			if weAreInsideASpeedObject && currentParsedElement == "kortVerdi"{
				let tempSpeed:uint? = uint(string)
				if (tempSpeed != nil) {
					if validSpeedLimits.contains(tempSpeed!){
						entrySpeed = tempSpeed
						if debug { print("Found speed:\t \(entrySpeed) km/t") }
					}
				}
			}
			else if currentParsedElement == "geometriWgs84" {
				entryPositionString += string
			}
		}
	}
	
	func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?){
		var multilineArray: [String] = []
		if (elementName as NSString).isEqualToString("kortVerdi") {
			if debug { print("didEndElement \t\t\(elementName)") }
			weAreInsideASpeedObject = false
		}
		if (elementName as NSString).isEqualToString("vegObjekt") {
			if debug { print("didEndElement \t\t\(elementName)\n") }
			weAreInsideARoadObject = false
			
		}
		if (elementName as NSString).isEqualToString("geometriWgs84") {
			if debug { print("didEndElement \t\t\(elementName)") }
			weAreInsideARoadObject = false
			entryPositionString = entryPositionString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
			if entryPositionString.hasPrefix("LINESTRING"){
				entryPositionString.removeRange(entryPositionString.startIndex ..< entryPositionString.startIndex.advancedBy(11)) //TODO: Bør byttes ut med noe dynamisk
				multilineArray.append(entryPositionString)
			} else if entryPositionString.hasPrefix("MULTILINESTRING"){
				entryPositionString.removeRange(entryPositionString.startIndex ..< entryPositionString.startIndex.advancedBy(17)) //TODO: Bør byttes ut med noe dynamisk
				entryPositionString.removeAtIndex(entryPositionString.endIndex.advancedBy(-1))
				multilineArray += parseMultiLineString(entryPositionString)
			}
			
			for linestring in multilineArray {
				entryPositions += parseLineString(linestring)
			}
			if debug { print("Found \t\(entryPositions.count) positions") }
			speedLimits.append(roadObject(speedLimit: entrySpeed, positions: entryPositions ))
			
			entryPositionString = ""
			entryPositions.removeAll()
		}
	}
	
	func parseLineString(string: String) -> [CLLocation]{
		var stringCopy = string
		var tempPos = [CLLocation]()
		stringCopy.removeAtIndex(stringCopy.startIndex)
		stringCopy.removeAtIndex(stringCopy.endIndex.predecessor())
		let doublePosArr = stringCopy.componentsSeparatedByString(",")
		for var coordinate in doublePosArr {
			if coordinate.characters.first == " "{
				coordinate.removeAtIndex(coordinate.startIndex)
			}
			let pos = coordinate.componentsSeparatedByString(" ")
			tempPos.append(CLLocation( latitude: Double(pos[1])! , longitude: Double(pos[0])!  ))
		}
		return tempPos
	}
	
	func parseMultiLineString(multilinestring: String) -> [String]{
		var tempArr: [String] = entryPositionString.componentsSeparatedByString("), ")
		for (index,element) in tempArr.enumerate() {
			if element[element.endIndex.predecessor()] != ")" {
				tempArr[index] += ")"
			}
		}
		return tempArr
	}
	
	// MARK: Location Services
	func initLocationManager(){
		locationManager.requestWhenInUseAuthorization()
		locationManager.delegate = self
		locationManager.desiredAccuracy = kCLLocationAccuracyBest
		locationManager.startUpdatingLocation()
	}
	
	func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
		if status == .AuthorizedWhenInUse || status == .AuthorizedAlways{
			if debug { print("We got location permission") }
			weHaveGPS = true
			locationManager.startUpdatingLocation()
		} else {
			if debug { print("We did not get location permission") }
			weHaveGPS = false
		}
		
	}
	
	func locationManager(manager: CLLocationManager,didUpdateLocations locations: [CLLocation]){
		let speedKMPH = 40.0 + sin(0.2 * NSDate().timeIntervalSince1970)*20 //locations[0].speed*3.6
		activeSpeedLimit = findActiveSpeedLimit(locations[0])
		speedometer.speedLimit = activeSpeedLimit
		speedometer.speed = Double(speedKMPH)
		if debug {print("You are doing \(Int(speedKMPH)) km/h, and the speed limit is \(activeSpeedLimit)")}
	}
	
	func findActiveSpeedLimit(myLocation: CLLocation) -> uint {
		let distanceThreshold:Double = 100 //meter
		if speedLimits.count > 0 {
			let n = speedLimits.count
			var distanceArr = [Double](count: n, repeatedValue: Double(FP_INFINITE))
			for i in 0 ..< n {
				let tempDistance = speedLimits[i].shortestDistanceToPoint(myLocation)
				distanceArr[i] = tempDistance
				
			}
			let shortestDistance = distanceArr.minElement()
			if debug { print("Shortest distance \(round(shortestDistance!)) meters") }
			let arrayIndex = distanceArr.indexOf(shortestDistance!)
			if shortestDistance <= distanceThreshold{
				return speedLimits[arrayIndex!].speedLimit
			}else{
				return 0
			}
			
		} else {
			if debug { print("No road objects") }
			return 0
		}
	}
}

struct roadObject {
	var speedLimit:uint = 0
	var positions = [CLLocation]()
	
	func shortestDistanceToPoint(myLocation: CLLocation) -> Double {
		var shortestDistance:Double = Double.infinity
		for position in positions {
			let distance = myLocation.distanceFromLocation( position )
			if distance < shortestDistance {
				shortestDistance = distance
			}
		}
		return shortestDistance
	}
}
