//
//  ReviewViewController.swift
//  12HD
//
//  Created by Edwin Cheah Yu Ping on 3/6/21.
//

import UIKit
import MapKit
import CoreLocation
import Firebase
import FirebaseFirestoreSwift

class ReviewViewController: UIViewController,  CLLocationManagerDelegate, MKMapViewDelegate, UITableViewDataSource, UITableViewDelegate {
    
 
    
    private var walkRecord: [WalkData] = [] //An array to hold Walk Data from the database

    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var mapKit: MKMapView!
    @IBOutlet weak var distanceWalkedLabel: UILabel!
    @IBOutlet weak var stepsTakenLabel: UILabel!
    @IBOutlet weak var gainLabel: UILabel!
    @IBOutlet weak var timeTakenLabel: UILabel!
    @IBOutlet weak var reviewTable: UITableView!
    
    //Method to setup table view
    func setupTableView(){
        reviewTable.delegate = self
        reviewTable.dataSource = self
    }
    
    //The usual table view controller methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return walkRecord.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = reviewTable.dequeueReusableCell(withIdentifier: "reviewCell", for: indexPath) as? ReviewTableCell else {
            fatalError("The dequeued cell is not an instance of ReviewTableCell.")
        }
        
        let dateWalked = formatDate(date: walkRecord[indexPath.row].dateSaved) //Get the date of the walk from the datebase and format to something more readable.
        
        cell.reviewCell.text = "Date of Walk - \(dateWalked)"
        
        //This if...else block changes the cell colour depending on wheater the walking or step goals have been met
        if(walkRecord[indexPath.row].distanceGoalMet||walkRecord[indexPath.row].stepGoalMet){
            cell.backgroundColor = UIColor.systemGreen
            cell.reviewCell.textColor = UIColor.white
        }else{
            cell.backgroundColor = UIColor.orange
            cell.reviewCell.textColor = UIColor.white
        }
        
        return cell
    }
    
    //When a row is selected, refresh polylines, zoom to the selected record location and refresh the labels to reflect the selected data
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        refreshPolyLines(record: walkRecord[indexPath.row])
        zoomToOverlay()
        refreshLabels(record: walkRecord[indexPath.row])

    }
    
    //Function to format date to dd MMM yyyy - hh:mma
    func formatDate (date: Date) -> String {
        let dateFormatterPrint = DateFormatter()
        dateFormatterPrint.dateFormat = "dd MMM yyyy - hh:mma"

        return dateFormatterPrint.string(from: date)
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
    

    //FUnction to setup a snapshotlistener for the recorded walk records in the firestore database. It updates the walkRecord array and reloads the tableview cells accordingly
    func getUserHistory(){
        let walkRecordQuery = loadUpFirebaseWalkCollections() //Loads up a Collection Reference to the walk record
        
        if(!walkRecord.isEmpty){ //If the walkRecord Array is not empty, empty it to reinialize.
            walkRecord.removeAll()
        }
        
        //Sets up snapshotlistener to query by date in decending order, making use of the server to do some sorting rather then running it locally.
        walkRecordQuery.order(by: "dateSaved", descending: true).addSnapshotListener { (querySnapshot, err) in
            if let err = err { //Throws an error if there is any issue.
                print("Error getting documents: \(err)")
            } else {
                
                //A for loop to iterate through each document, decode it to a WalkData object and if it is successful in decoding, add it to the walkRecord array
                for document in querySnapshot!.documents {
                    let result = Result {
                        try document.data(as: WalkData.self)
                       }
                    switch result {
                       case .success(let walkData):
                           if let walkData = walkData {
                            self.walkRecord.append(walkData) //Adds to walkRecord array if decoding is scuessful
                           } else {
                               print("ERROR: Document does not exist")
                           }
                       case .failure(let error):
                           print("Error decoding Walk Data: \(error)")
                       }
                    
                    DispatchQueue.main.async { [self] in
                        
                        if(!walkRecord.isEmpty){ //Double checks if the newly intalized walkRecord array is not empty as it should now have the new list of walk data from the database
                            
                            refreshLabels(record: walkRecord.first!) //Refresh/rewrite the text labels on the interface with the first new record
                            
                            self.reviewTable.reloadData() //Reloads the table view cells with the new data
                        
                            refreshPolyLines(record: walkRecord.first!) //Draws the polylines out from the first walkData in the walk record array
                            
                            zoomToOverlay() //Zooms in to the first walk data record in the walkRecord Array
                        }
                    }
               
                }
            }
        }
    }
    
    //Deafult mapView functions used to refender polyline overlays when the overlay array contains coordinates
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let routePolyline = overlay as? MKPolyline {
              let renderer = MKPolylineRenderer(polyline: routePolyline)
              renderer.strokeColor = UIColor.blue
              renderer.lineWidth = 7
              return renderer
          }
          return MKOverlayRenderer()
    }
    
   
    //Function to refresh labels on the UI
    func refreshLabels(record: WalkData){
        
        let (hh, mm, ss) = secondsToHoursMinutesSeconds(seconds: Int(record.durationWalked)) //Converts the seconds to hh mm ss
        
        let convertedDistance = metersToKillometers(meters: record.distanceWalked)
       
        let dateToString = formatDate(date: record.dateSaved) //Convers the date to a string while formmating it.

        dateLabel.text = "Date: \(dateToString)"
        timeTakenLabel.text = "Time taken: \(hh):\(mm):\(ss)"
        
        gainLabel.text = "Cummalative Evelation Gain: \(String(format: "%.2f", record.evelvationGain)) M"
        
        if(record.distanceGoalMet){ //If the distance goal is met, add a " - GOAL MET!" at the end, else display normally
            distanceWalkedLabel.text = "Distance Walked: \(String(format: "%.2f",convertedDistance)) Km - GOAL MET!"
        } else{
            distanceWalkedLabel.text = "Distance Walked: \(String(format: "%.2f",convertedDistance)) Km"
        }
        
        if(record.stepGoalMet){//If the step goal is met, add a " - GOAL MET!" at the end, else display normally
            stepsTakenLabel.text = "Steps taken: \(record.stepsTaken) - GOAL MET!"
        }else{
            stepsTakenLabel.text = "Steps taken: \(record.stepsTaken)"
        }
        
    
    }
    
    //Function to automatically zoom to the overlays drawn
    func zoomToOverlay() {
        let insets = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)
        guard let initial = mapKit.overlays.first?.boundingMapRect else {return}
        mapKit.setVisibleMapRect(initial, edgePadding: insets, animated: true)
    }
    
    //Function to add the new polylines and remove the old
    func refreshPolyLines(record: WalkData){
        mapKit.removeOverlays(mapKit.overlays) //Clears out the old overlays
        let geoDataArray = record.geoData //Get the geoData from the recieved record
        var locationArray: [CLLocationCoordinate2D] = [] //Intalized a CLLocationCoordinate2D array
    
        for geoData in geoDataArray{ //Extrax the geoData objects and convert them into CLLocationCoordinate2D objects and put them into the locationArray
            locationArray.append(CLLocationCoordinate2D(latitude: geoData.latitude, longitude: geoData.longitude))
        }
        
        let myPolyline = MKPolyline(coordinates: locationArray, count: locationArray.count) //Create a polyline objet
            mapKit.addOverlay(myPolyline) //Add the new polyline object to the map view to be rendered.
        
    }
    
    //Runs getUserHistory() again to get updated list
    override func viewWillAppear(_ animated: Bool) {
        getUserHistory()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapKit.delegate = self
        setupTableView()
        getUserHistory()
   
    }


}
