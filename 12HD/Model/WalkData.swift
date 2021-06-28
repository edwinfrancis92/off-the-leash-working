//
//  FirebaseTempData.swift
//  12HD
//
//  Created by Edwin Cheah Yu Ping on 8/6/21.
//

import UIKit
import Firebase
import FirebaseFirestoreSwift

//A struct for to hold Walk data, and to decode and encore to the firestore database
struct WalkData: Codable{
    var dateSaved: Date
    var distanceGoalMet: Bool
    var distanceWalked: Double
    var durationWalked: Int
    var evelvationGain: Double
    var geoData: [GeoPoint]
    var stepGoalMet: Bool
    var stepsTaken: Int
}

//A struct for to hold Goals data, and to decode and encore to the firestore database
struct Goals: Codable{
    var distanceGoal: Double
    var stepGoal: Int
    
}

//Returns a walkRecord collection of the current user from the firestore databse.
func loadUpFirebaseWalkCollections() -> CollectionReference {
    var fireStoreDB = Firestore.firestore()
    fireStoreDB = Firestore.firestore()
    let walkRecordQuery = fireStoreDB.collection("users").document("IoZ3IZyIhGOgPVgEmesm").collection("walkRecord")
 
    return walkRecordQuery
}

//Function to help write GOals data to the Goals document in Firestore. It takes in a goal object
func writeGoalData(newGoal: Goals){
    var fireStoreDB = Firestore.firestore()
    fireStoreDB = Firestore.firestore()
    
    let goalRecord = fireStoreDB.collection("users").document("IoZ3IZyIhGOgPVgEmesm").collection("goals").document("AT1Ia9Rgk5ywpWcZL8PT")
    
    do{
        try goalRecord.setData(from: newGoal)
        print("Document Update added")
    } catch let error {
        print("Storage Error \(error)")
        
    }
}

//Fucnion to help get a document reference to the Goals document in firestore
func getFirebaseGoalsRef() -> DocumentReference{
    var fireStoreDB = Firestore.firestore()
    fireStoreDB = Firestore.firestore()
    let goalRecord = fireStoreDB.collection("users").document("IoZ3IZyIhGOgPVgEmesm").collection("goals").document("AT1Ia9Rgk5ywpWcZL8PT")
        
    return goalRecord
}
