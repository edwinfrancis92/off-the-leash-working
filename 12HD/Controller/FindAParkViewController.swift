//
//  FindAParkViewController.swift
//  12HD
//
//  Created by Edwin Cheah Yu Ping on 2/6/21.
//

import UIKit
import MapKit

class FindAParkViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var mapKitView: MKMapView!
    @IBOutlet weak var findParkTable: UITableView!
    @IBOutlet weak var recenter: UIButton!
    
    private let locationManger: CLLocationManager = CLLocationManager() //LocationManager Variable
    private var currentLocation:  CLLocation? //Sets up an option to be unwrapped for CLLocation to be determined later
    private var sortedProperties: [Properties] = []
    
    private var annotationSelected = false //Helps track if an annotaion is selected
    
    //Sets up location manager deleage
    required init?(coder: NSCoder) {
        super.init(coder:coder)
        self.locationManger.delegate = self
    }
    
    //Function that helps recenter the map to current location
    @IBAction func recenter(_ sender: Any) {
        annotationSelected = false
        mapKitView.centerToLocation(currentLocation!)
    }
    
    
    func setupPropertiesList(){
        sortedProperties.removeAll() //CLears the list for reinialization
        for property in propertiesArray{ //Gets each off leash location property from the properties array
            
            if currentLocation == nil{ //Just incase currentlocation is not yet initalized. current location will be the first property
                currentLocation = CLLocation.init(latitude: Double(property.y!)!, longitude: Double(property.x!)!) //setting the current location to the closets annotation point
            }

            let parkDistance = CLLocation.init(latitude: Double(property.y!)!, longitude: Double(property.x!)!).distance(from: currentLocation!) //Get the distance of the current park object from the current user location (or first array item if user location unknown)
              
                    property.distance = round(parkDistance)/1000.0 //Convers to KM
                    sortedProperties.append(property) //Stores the distance
            
        }
        sortedProperties = sortedProperties.sorted(by:{$0.distance! < $1.distance!}) //Sort the array by distance
    }
    
    
    //gets coordinates of current location
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let first = locations.first else {
            return
        }
        
        currentLocation = CLLocation(latitude: first.coordinate.latitude, longitude: first.coordinate.longitude) //Current location of user
        
        if(annotationSelected == false){
            mapKitView.centerToLocation(currentLocation!) //Center location on user if no annocation is selected
            
        }
            setupPropertiesList()
            findParkTable.reloadData()
    }
    
    //sets up location manager settings
    func setupLocationManger(){
        self.locationManger.desiredAccuracy = kCLLocationAccuracyKilometer // Sets accuracy of app to one kilometer
        self.locationManger.requestWhenInUseAuthorization()
        
        //checks if location services is enabled and starts to update location if needed
        if CLLocationManager.locationServicesEnabled(){
            self.locationManger.startUpdatingLocation()
            
            return
        }
    }
    
    
    //Standard table view functions
    //Create n-number of rows based on the toiletDataArray element count
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedProperties.count
    }
    
    //When a row is selected, get the data of the selected row and change the view of the map to corresponding annotation and change the annocation to a selected state
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let selecteProperty = sortedProperties[indexPath.row]
        for annotation in mapKitView.annotations {
            if annotation.title == selecteProperty.location{
                mapKitView.selectAnnotation(annotation, animated: true) //Selectes the annoication when the selected item matchs it
                annotationSelected = true
            }
        }
    }
    
    //Handles refreshing of cells
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = findParkTable.dequeueReusableCell(withIdentifier: "FindParkViewCell", for: indexPath) as? FindParkTableCell else {
            fatalError("The dequeued cell is not an instance of FindParkTableCell.")
        }
        
        //Set table view cell labels
        cell.findParkViewCellLabel.text = "\(sortedProperties[indexPath.row].location!) - \(String(format: "%.2f", sortedProperties[indexPath.row].distance!)) Km"
        
        return cell
    }
    
    //Pulls data task to main thread to ensure that sorted Data is initalized before assigning it to workingData. the table views are reloaded once done
    func reloadViewAfterDataTask(){
       DispatchQueue.main.async { [self] in
            self.findParkTable.reloadData()
        }
    }
    
    //Setup dataTableView in main storyboard
    func setupDataTableView(){
        findParkTable.delegate = self
        findParkTable.dataSource = self
    }
    
    //Setup the pin annotation posisons! Done by looping through properties and assigning them to the annoications
    func setupPinPositions(){
        for property in sortedProperties {
            let annotation = MKPointAnnotation()
            let lat = Double(property.y!)
            let long = Double(property.x!)
            
            annotation.title = property.location
            annotation.coordinate = CLLocationCoordinate2D(latitude: lat!, longitude: long!)
            mapKitView.addAnnotation(annotation)
        }
    
    }

    //MapView Functions, for handling annnoication selections
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        let region = MKCoordinateRegion(center: view.annotation!.coordinate, span: mapView.region.span) //Setup a coordinate region to zoom too
            mapView.setRegion(region, animated: true) //Sets region to where the annocation is selected
        
    }
    
    //MapView fnction to handle the annotion view setup
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is MKPointAnnotation else { return nil }

        let identifier = "Annotation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

        if annotationView == nil { //If annotation view is not setup
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView!.canShowCallout = true
            annotationView!.displayPriority = .required
        } else {
            annotationView!.annotation = annotation //Adds the annotation to the annotation view to show
        }
        return annotationView
    }
    
    //Tries to load the GeoJSON files, if cannot connect, use offline backup
    func loadAndErrorHandleGeoJson(){
        if(getGeoJsonFile() == false){
            print("alret supposed tp print")
            DispatchQueue.main.async { [self] in
                let alert = UIAlertController(title: "Unable to connect to server to obtain park data", message: "\"Off the Leash!\" will use an offline backup of the park data instead.", preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: {action in
                    
                }))
                self.present(alert, animated: true)
            }
        }else{
            print("Loaded online data")
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.locationManger.stopUpdatingLocation() //Stops updating location when this view is not being used
    }
    
    //Runs the location manager setup and retireves park data gain when view is about to appear
    override func viewWillAppear(_ animated: Bool) {
        
        setupLocationManger()
   
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapKitView.delegate = self
        mapKitView.showsUserLocation = true;
        loadAndErrorHandleGeoJson()
        
        DispatchQueue.main.async { [self] in
            getProperties()
            setupPropertiesList()
            setupDataTableView()
            setupPinPositions()
        }
        reloadViewAfterDataTask()
    }
    
  
}

private extension MKMapView {
  func centerToLocation(
    _ location: CLLocation,
    regionRadius: CLLocationDistance = 5000
  ) {
    let coordinateRegion = MKCoordinateRegion(
      center: location.coordinate,
      latitudinalMeters: regionRadius,
      longitudinalMeters: regionRadius)
    setRegion(coordinateRegion, animated: true)
  }
}

