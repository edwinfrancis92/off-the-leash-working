//
//  OffLeashData.swift
//  12HD
//
//  Created by Edwin Cheah Yu Ping on 3/6/21.
//

import UIKit
import MapKit


class OffLeashGeoData: Codable {
    var type: String?
    var features: [Feature]
  
}

class Feature: Codable {
    var type: String?
    var coordinates: [[[[Double?]]]]
    var geometry_name: String?
    var properties: Properties
    
}

class Properties: Codable {
    var name: String?
    var snippet: String?
    var location: String?
    var type: String?
    var x: String?
    var y: String?
    var mi_prinx: String?
    var distance: Double?
    
    
}
 

var offLeashDataArray: [MKGeoJSONFeature] = [] //Array to hold decoded public toilet JSON data
var propertiesArray: [Properties] = []


let session = URLSession.shared
let fileManager = FileManager.default //Defines a fileManager for easy usage

//URL to off-leash dataset
let urlToServer = URL(string: "https://data.gov.au/geoserver/dandenong-dog-off-leash-areas/wfs?request=GetFeature&typeName=ckan_8e4738e5_c3ec_43ab_a459_81b94a57cb06&outputFormat=json")!

let sourceFilePath = Bundle.main.url(forResource: "backupOffLeashData", withExtension: "json") //Searches for file in bundle

let detinationFilePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("backupOffLeashData.json") //defines document directory destination for file

var offLeashOverlayArray = [MKOverlay]()

func setupPolygonOverlays() -> [MKOverlay]{ //For multipolygon area overlay feature. The feature is currently not implemented. The data is there for future.
    for item in offLeashDataArray {
            for geo in item.geometry{
                if let multiPolygon = geo as? MKMultiPolygon{
                    offLeashOverlayArray.append(multiPolygon)
                }
            }
    }
    return offLeashOverlayArray
}

//Function to get the off-leash data properties from the firestore database
func getProperties(){
    for item in offLeashDataArray {
        do {
            let property = try JSONDecoder().decode(Properties.self, from: item.properties!)
            propertiesArray.append(property)
         } catch {
             print("Error during JSON serialization: \(error.localizedDescription)")
         }
        
    }
    print("Final Property Array count \(propertiesArray.count) and first property name is \(String(describing: propertiesArray.first?.location!))")
}

//Function to help get the GeoJson file from the network, provides a offline fallback if cannot connect ot network. If can connect a new backup is created to ensure the data is up to date.
func getGeoJsonFile() -> Bool {
    do {
        let data = try Data(contentsOf: urlToServer)
        guard let feauture = try MKGeoJSONDecoder().decode(data) as? [MKGeoJSONFeature] else {
            fatalError("Passing MKGeoJSONFeature Failed")
        }
        writeToOfflineStore()
        offLeashDataArray = feauture
        print("Parks decoded \(offLeashDataArray.count)")
        
        return true
    } catch {
        print("Unable to parse GeoJson file, possible network conncetion or URL broken. Using saved data")
        copyFileToDirecotry() //Checks if an offline back up for the off leash data exists. if it doesn, it copies the bundled version over to the file path
        offLeashDataArray = readFromFilePath() //Reads offline backup
        
        return false
    }
}

//Function to write the GeoJson/Json file to offline storeage as a backup
func writeToOfflineStore(){
    if let backupOffLeashData = URL(string: urlToServer.absoluteString) {
        URLSession.shared.downloadTask(with: backupOffLeashData) { (tempURL, response, error) in
            
            // 4
            if let fileTempURL = tempURL {
                do {
                    // 1
                    let fileData = try Data(contentsOf: fileTempURL)
                    print("Writing to file for backup")
                    // 2
                    try fileData.write(to: detinationFilePath)
                } catch {
                    print("Error failed to write to file")
                }
            }
        }.resume()
    }
}


//Function to read from file patch
func readFromFilePath() -> [MKGeoJSONFeature] {
    var offlineData: [MKGeoJSONFeature] = []
    do{
        
        let data = try Data(contentsOf: detinationFilePath)
        guard let offline = try MKGeoJSONDecoder().decode(data) as? [MKGeoJSONFeature] else {
            fatalError("Passing MKGeoJSONFeature Failed")
        }
        offlineData = offline
    }catch{
        fatalError("Failed to read from offline backup")
    }
    return offlineData
}

//Function to copy file from directory to bunle
func copyFileToDirecotry(){
    if (fileManager.fileExists(atPath: detinationFilePath.path) == false) { //Checks if file exits, if not copy file
        guard let unwrappedSourceFilePath = sourceFilePath else {
            print("indended url path does not exists")
            return
        }
        do{
            try fileManager.copyItem(at: unwrappedSourceFilePath, to: detinationFilePath)
            print("File copied")
        } catch {
            print("File copy failed")
        }
    }else{
        print("File Already exitss")
        
    }
    
}
