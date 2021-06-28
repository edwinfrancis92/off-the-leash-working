//
//  TrackMyWalkViewController.swift
//  12HD
//
//  Created by Edwin Cheah Yu Ping on 3/6/21.
//

import UIKit
import MapKit
import CoreLocation
import CoreMotion
import Firebase
import FirebaseFirestoreSwift

class TrackMyWalkViewController: UIViewController, CLLocationManagerDelegate,MKMapViewDelegate, UITabBarControllerDelegate {

    @IBOutlet weak var recordMapKitView: MKMapView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var kmWalked: UILabel!
    @IBOutlet weak var stepsTaken: UILabel!
    @IBOutlet weak var evelvationGain: UILabel!
    @IBOutlet weak var durationOfWalk: UILabel!
    
    
    //A set of variables to store data for various things
    let recordingLocationManager = CLLocationManager()
    private var seconds = 0 //A variable to keep track of seconds past from the walk
    private var timer: Timer? //Timer object to keep time
    private var distance = Measurement(value: 0, unit: UnitLength.meters) //A variable to hold the distance walked
    private var locationList: [CLLocation] = [] //A list to keep all prvious locations walked
    private var steps: CMPedometerData? //A pedometerData object to help count steps
    private var finalSteps: Int = 0 //An object to hold the final amount of steps taken when recording stops
    private var pedometer = CMPedometer() //A pedometer object to help count steps
    private var gain: Double = 0 //A variable to store the cummalative gain
    private var oldGain: Double = 0 //A variable to store old gain
    private var newGain: Double = 0 //A varialbe to store latest current gain to
    private var recordingWalk = false //A varialbe to track if the walk is still being recorded
    private var goals: Goals = Goals(distanceGoal: 0, stepGoal: 0) //A Goal object to hold goal data
    private var distanceGoal = false //A varialbe to track if distance goal has been met
    private var stepGoal = false //A variable to track if step goals have been met
    private var currrent2DLocationArray : [CLLocationCoordinate2D] = [CLLocationCoordinate2D]() //A CLLocationCoordinate2D array to hold all points walked for PolyLine Drawing
    private var stopDistance = 0.0 //A variable to hold the distance data when recording is stopped
    private var startDate = Date() //Variable to hold date
    
    //A button function that starts or stops the recording of the walk
    @IBAction func recordButton(_ sender: Any) {
            if(recordingWalk == false){ //If not recording when button is pressed, start the recording
                startRecording()
            }else if (recordingWalk){ //If the walk is being recorded when button is pressed, stop the recording.
                stopRecording()
            }
            
}
    func startRecording(){
        changeTabItemState(state: false) //Disable tabs
        
        recordingLocationManager.allowsBackgroundLocationUpdates = true;
        resetGain()
        locationList.removeAll() //Erases all the past locations just in case
        print("Current location start \(currrent2DLocationArray.count)")
        currrent2DLocationArray.removeAll() //Erases all the past locations walked to record a new polyline when recording starts just in case
        seconds = 0 //Resets the timer
        distance = Measurement(value: 0, unit: UnitLength.meters) //Resets the distance walked to 0
        
        updateDisplay() //Updates the labels on the view
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
        eachSecond() //Adds a second to the second counter and updates the display
        }
        
        pedometer = CMPedometer() //Resets the pedometer object
        pedometer.startUpdates(from: Date(), withHandler: { (pedometerData, error) in //Starts the pedometer to count steps
            if let pedData = pedometerData{
                self.steps = pedData
            }
        })
        
        startDate = Date()
        
        recordButton.backgroundColor = UIColor.red //Change the record button to red to indicate that it is recording
        recordButton.setTitle("Stop Walk", for: .normal) //Change the label to prompt user to press button to stop the walk
        recordingWalk = true //Change the boolean to let all those interested know that the walk is being recorded
        
    }
    
    
    func stopRecording(){
        changeTabItemState(state: true)
        locationList.removeAll()
        recordingLocationManager.allowsBackgroundLocationUpdates = false;
        let storedOverlays = recordMapKitView.overlays //Get the array of overlays currently on the map kit view
        recordMapKitView.removeOverlays(storedOverlays) //Remmove all overlays in the mapkit view
        
        stopDistance = distance.value //Gets the distance at point of stopping the recording
        timer?.invalidate() //Stops timer
        pedometer.stopUpdates() //Stops updates
        recordButton.backgroundColor = UIColor.gray //Change the button colour back to grey
        recordButton.setTitle("Record Walk!", for: .normal) //Change thhe button title to Record Walk
        recordingWalk = false // Change the recordingWalk bool to false to let all those interested know that the recording has stoped

        //The block below sends out an alreat to ask if user wants to the recorded walk data
        let alert = UIAlertController(title: "Do you want to save your walk data?", message: "", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: {action in //If yes save the data and reset the screen
            self.writeToFirebaseCollections() //Writes to the database
            self.resetDisplay() //Resets the diplay to 0 after saving data
            self.currrent2DLocationArray.removeAll()
        }))
        
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: {action in //If no don't save data, but reset the screen
            self.resetDisplay() //Resets the diplay
            self.currrent2DLocationArray.removeAll()
        }))

        self.present(alert, animated: true) //Presents the table
        
        print("Size of 2D location array after stop is \(currrent2DLocationArray.count)")
    }
    
    //Function to help change the tab item state more easily
    func changeTabItemState(state: Bool){
        let tabBarArray = self.tabBarController?.tabBar.items //Gets the tabBar objects (the navigation bar items)
        
        for tabBar in tabBarArray!{ //Loops through to disable the navigation bar while recording is happening
            tabBar.isEnabled = state
        }
        
    }
    
    //Updates the seconds value and display every one second
    func eachSecond() {
      seconds += 1
      updateDisplay()
    }
    
    //Function to help convert meters to seconds
    private func metersToKillometers(meters: Double) -> Double {
        let converted = meters/1000
  
        return converted
    }
    
    //Fucntion to convert the seconds to hh mm ss - taken from https://stackoverflow.com/questions/26794703/swift-integer-conversion-to-hours-minutes-seconds
    func secondsToHoursMinutesSeconds (seconds : Int) -> (Int, Int, Int) {
      return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }
    
    private func updateDisplay(){
        let convertedDistanceInKm = metersToKillometers(meters: distance.value) //Converted meters value to distance
        let convertedString = String(format: "%.2f", convertedDistanceInKm) //Changes it to two decimal format.
        
        if(convertedDistanceInKm >= goals.distanceGoal){ //Checks if goal is met in km! if so display " - Goal Met!"
            kmWalked.text = "Distance Walked: \(convertedString) Km - Goal Met!"
            distanceGoal = true //Sets the distance goal to true for storage
        } else{
            kmWalked.text = "Distance Walked: \(convertedString) Km"
            distanceGoal = false //When goal is not met, set the value to false for storage
        }
        
        let gain2Decimals = String(format: "%.2f", gain) //Changes it to two decimal format.
        
        evelvationGain.text = "Cummalative Elevation Gain: \(gain2Decimals) M"
        
        let (hh, mm, ss) = secondsToHoursMinutesSeconds(seconds: seconds) //Get tuple of hour, minute and seconds
  
        durationOfWalk.text = "Current Duration of Walk: \(hh):\(mm):\(ss)"
        
        if (steps?.numberOfSteps) != nil { //Unwrap the number of steps collected by the pedometer. if not nill, save it to the fialSteps variable for display update
            finalSteps = steps!.numberOfSteps.intValue
        }else {
            return stepsTaken.text = "Steps Taken: 0"
        }
        
        if(Int(finalSteps) >= goals.stepGoal){ //If step goal is met update the diplay with " - Goal Met!" if not dont.
            stepsTaken.text = "Steps Taken: \(finalSteps) - Goal Met!"
            stepGoal = true //Sets stepGoal variable to true for database storeage
        } else {
            stepsTaken.text = "Steps Taken: \(finalSteps)"
            stepGoal = false //Sets stepGoal variable to false when goal not met for database storeage
        }
    
            
    }
    
    //Resets the diaply accordingly
    private func resetDisplay(){
        kmWalked.text = "Distance Walked v2:"
        evelvationGain.text = "Cummalative Elevation Gain:"
        durationOfWalk.text = "Current Duration of Walk:"
        stepsTaken.text = "Steps Taken:"
    }
    
    
    //Standard Location Manager functions
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let first = locations.first else {
            return
        }
        
        let currentLocation = CLLocation(latitude: first.coordinate.latitude, longitude: first.coordinate.longitude) //Gets urrent location of user when location is updated
        
            recordMapKitView.centerToLocation(currentLocation) //Updates location into te mapkit
        
        if(recordingWalk == true){ //If walk is recording, start to draw the poly line with the current location of the user
            
            //As the polyline object needs a CLLocationCoordinate2D object, create one and add to an array for the poy line
            let current2DLocation = CLLocationCoordinate2D(latitude: first.coordinate.latitude, longitude:  first.coordinate.longitude)
            currrent2DLocationArray.append(current2DLocation)
            
            print("Current location array post append \(currrent2DLocationArray.count)")
            //Create a polyline object with the currrent2DLocationArray Array and add it as an overlay to the map
            let myPolyline = MKPolyline(coordinates: currrent2DLocationArray, count: currrent2DLocationArray.count)
            recordMapKitView.addOverlay(myPolyline)
        
            for newLocation in locations {
                let howRecent = newLocation.timestamp.timeIntervalSinceNow //Get time since last location point
        
                guard newLocation.horizontalAccuracy < 20 && abs(howRecent) < 10 else { continue } //If the accuracy is less then 20 and time interval since last location update is less then 10, continue with function!

                if let lastLocation = locationList.last { //Uses the last location to determine the latest current disntace travelled
                    let delta = newLocation.distance(from: lastLocation)
                    distance = distance + Measurement(value: delta, unit: UnitLength.meters)
                    print("Distance is \(distance)")
                } else{
                    print("Distance is nill yay")
                }
                
                locationList.append(newLocation) //Add the latests location into the location lists for later.
                calculateGain(location: newLocation)
          }
        }
    }
    
    func calculateGain(location: CLLocation){
        newGain = location.altitude //Get the altitude from the location
        print("\(locationList.count) is the list count")
        if(locationList.count > 1){
            let gainDifference: Double = newGain - oldGain //Calculate cummarliev gain
            gain += max(0, gainDifference) //0 if no cummalative gain in elevation, else get the new gain
            print("Gain is \(gain)")
            print("Pre-Popped index \(locationList.count)")
            locationList.removeFirst() //Pop first to save memory
            print("Popped index \(locationList.count)")
        }
        
            oldGain = newGain //Store it for new calculations later.
    }
    
    //Standard map view functions to render a poly line
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let routePolyline = overlay as? MKPolyline {
              let renderer = MKPolylineRenderer(polyline: routePolyline)
              renderer.strokeColor = UIColor.blue
              renderer.lineWidth = 7
              return renderer
          }

          return MKOverlayRenderer()
    }
    
    func resetGain(){
        newGain = 0
        oldGain = 0
        gain = 0
    }
    
    //sets up location manager settings
    func setupLocationManger(){
        self.recordingLocationManager.delegate = self
        self.recordingLocationManager.activityType = .fitness
        self.recordingLocationManager.distanceFilter = 10
        self.recordingLocationManager.desiredAccuracy = kCLLocationAccuracyKilometer // Sets accuracy of app to one kilometer
        self.recordingLocationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled(){
            self.recordingLocationManager.startUpdatingLocation()
            
            return
        }
        
    }
    
    
    //stops everything when view stops
    override func viewWillDisappear(_ animated: Bool) {
      super.viewWillDisappear(animated)
      timer?.invalidate()
        //locationManager.stopUpdatingLocation()
    }
    
    
    //Function to write the walk data to the firestore database
    func writeToFirebaseCollections(){
        let walkRecordQuery = loadUpFirebaseWalkCollections() //Get the walkRecord collection from database
        
        var geoArray:[GeoPoint] = [] //Inoitalize a GeoPoint Array
        
        for cords in currrent2DLocationArray{ //Used to conver the currrent2DLocationArray into GeoPoint data
            geoArray.append(GeoPoint(latitude: cords.latitude, longitude: cords.longitude))
        }

        print("Current location array post firebase \(currrent2DLocationArray.count)")
        //Ctreate a WalkData object with all the collected data
        let writeData: WalkData = WalkData(dateSaved: startDate, distanceGoalMet: distanceGoal, distanceWalked: stopDistance, durationWalked: seconds, evelvationGain: gain, geoData: geoArray, stepGoalMet: stepGoal, stepsTaken: finalSteps)
        geoArray.removeAll()
        //Finally write add the data as a documetn in the firestore database
        do{
            _ = try walkRecordQuery.addDocument(from: writeData)
            print("Collection added")
        } catch let error {
            print("Storage Error \(error)")
            
        }
    }
    
    
    //Gets the goals document. No snapshot listener is used for the session. So that the goals wont change randomly
    func getFirebaseGoalsDocument(){
        let goalRecord = getFirebaseGoalsRef()
        
        goalRecord.getDocument { (document, error) in
            let result = Result {
            try document?.data(as: Goals.self) //Retrieve goals document and decodes it as a Goals object
          }
              switch result {
              case .success(let goals): //If decoding is scucessful, assign to the global goals variable for use by the ap
                  if let goals = goals {
                    self.goals = goals
                  } else {
                      print("Document does not exist")
                  }
              case .failure(let error):
                  print("Error decoding city: \(error)")
              }
        
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
           recordingLocationManager.stopUpdatingLocation() //Stops updating location when this view is not being used
    }
    
    override func viewWillAppear(_ animated: Bool) {
        getFirebaseGoalsDocument() //Gets document rightbeofre the view appreas
        setupLocationManger() //Restart location manager
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        recordMapKitView.delegate = self
        recordMapKitView.showsUserLocation = true;
        setupLocationManger()
    }
    
    
    
   


}

//Extension to help cetner map location to a point
private extension MKMapView {
  func centerToLocation(
    _ location: CLLocation,
    regionRadius: CLLocationDistance = 1000
  ) {
    let coordinateRegion = MKCoordinateRegion(
      center: location.coordinate,
      latitudinalMeters: regionRadius,
      longitudinalMeters: regionRadius)
    setRegion(coordinateRegion, animated: true)
  }
}

