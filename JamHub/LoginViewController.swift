//
//  LoginViewController.swift
//  JamHub
//
//  Created by Daniel Barychev on 5/18/17.
//  Copyright © 2017 Daniel Barychev. All rights reserved.
//

import UIKit
import Firebase
import SwiftVideoBackground

class LoginViewController: UIViewController, UITextFieldDelegate {
    
    // MARK: Properties
    @IBOutlet weak var backgroundVideo: BackgroundVideo!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        backgroundVideo.createBackgroundVideo(name: "MonkBackground", type: "mp4", alpha: 0.5)
        emailTextField.delegate = self
        passwordTextField.delegate = self
        // Do any additional setup after loading the view.
    }
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
    }
    
    func handleLogin() {
        guard let email = emailTextField.text, let password = passwordTextField.text
            else {
                //invalid entry
                return
        }
        
        Auth.auth().signIn(withEmail: email, password: password, completion: { (user, error) in
            if error != nil {
                print(error!)
                
                let loginAlert = UIAlertController(title: "Invalid Login", message: "Incorrect Email or Password", preferredStyle: UIAlertControllerStyle.alert)
                loginAlert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                self.present(loginAlert, animated: true, completion: nil)
                
                return
            }
            
            else {
                print("User Successfully Logged In")
                
                self.performSegue(withIdentifier: "Login", sender: nil)
            }
        })
        
    }
    
    // MARK: Navigation

    @IBAction func unwindToLoginScreen(sender: UIStoryboardSegue) {
    }

    // MARK: Actions
    
    @IBAction func login(_ sender: UIButton) {
        handleLogin()
    }
    


}
