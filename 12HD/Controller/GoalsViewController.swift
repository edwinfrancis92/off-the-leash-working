//
//  GoalsViewController.swift
//  12HD
//
//  Created by Edwin Cheah Yu Ping on 3/6/21.
//

import UIKit
import Firebase
import FirebaseFirestoreSwift

class GoalsViewController: UIViewController, UITextFieldDelegate {


    @IBOutlet weak var currentDistanceGoal: UILabel!
    @IBOutlet weak var currentStepGoal: UILabel!
    
    @IBOutlet weak var distanceGoalInput: UITextField!
    @IBOutlet weak var stepGoalInput: UITextField!
    
    @IBOutlet weak var setGoalButton: UIButton!
    
    private var tempGoal = Goals(distanceGoal: 0.0, stepGoal: 0) //A goal object as a temporary holder to pass the data around. Initalized at 0 for all values firsts
    
    
    //Methods to start listening to the goals document in the firestore database
    func getGoalsFromDocRef(){
        let goalsDocRef = getFirebaseGoalsRef()
        goalsDocRef.addSnapshotListener  { (document, error) in
          
              let result = Result {
              try document?.data(as: Goals.self)
            }
                switch result {
                case .success(let goals):
                    if let goals = goals {
                    
                        //Intalizes the current temporary goal variable to be passed around
                        self.tempGoal.distanceGoal = goals.distanceGoal
                        self.tempGoal.stepGoal = goals.stepGoal
                        
                        //Sets the label fields to the current set goal
                        self.currentDistanceGoal.text = "Distance Goal: \(goals.distanceGoal)Km"
                        self.currentStepGoal.text = "Steps Goal: \(goals.stepGoal) Steps"
                    } else {
                        print("Document does not exist") //An Error message.
                    }
                case .failure(let error):
                    print("Error decoding Goal Data: \(error)")  //More error messages just in case
                }
          
          }
    }
    
    //setGoal button action function that sends off the new goal data into the firestore database
    @IBAction func setGoal(_ sender: Any) {
        var newGoal:Goals = Goals(distanceGoal: 0, stepGoal: 0) //Makes a new goal object for sending
        
        //Unwraps the user input and casts them down into a Double value and assigns them to the newGoal object for sending off. No input validation required as the numberpad is used thus no way to input false data.
        if let unwrappedNewDistanceGoal:Double = Double(distanceGoalInput.text!) {
            newGoal.distanceGoal = unwrappedNewDistanceGoal
        } else { //If user doesn't input anything, intalize the goal's distance variable to current set goal
            newGoal.distanceGoal = tempGoal.distanceGoal
        }
        
        //Unwraps the user input and casts them down into a Double value and assigns them to the newGoal object for sending off. No input validation required as the numberpad is used thus no way to input false data.
        if let unwrapedNewStepGoal:Int = Int(stepGoalInput.text!) {
            newGoal.stepGoal = unwrapedNewStepGoal
        }else { //If user doesn't input anything, intalize the goal's step variable to current set goal
            newGoal.stepGoal = tempGoal.stepGoal
        }
        
        
        writeGoalData(newGoal: newGoal) //Finally send off the data!
        distanceGoalInput.text = "" //Clears the input text field
        stepGoalInput.text = "" //Clears the input text field
    }
    
    //The UITextField Delegate for handling return commands on text fields. Essentially helps close the numberpad by resigning the selected textfield's first responder status
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        distanceGoalInput.resignFirstResponder()
        stepGoalInput.resignFirstResponder()
        return true
    }
    
    //When a UI touch occurs outside the numberpad, end the filed editing status, allowingfor "return" type action on the text fields
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        distanceGoalInput.delegate = self
        stepGoalInput.delegate = self
        getGoalsFromDocRef() //Runs it so that the listener starts up and listens
        
    }


}
