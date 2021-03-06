//
//  ProfileSettingsTableViewController.swift
//  JamCenter
//
//  Created by Daniel Barychev on 6/11/18.
//  Copyright © 2018 Daniel Barychev. All rights reserved.
//

import UIKit
import Firebase

class ProfileSettingsTableViewController: UITableViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: Properties
    
    typealias deletedUserFromMusiciansClosure = (Bool?) -> Void
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var instrumentsLabel: UILabel!
    @IBOutlet weak var genresLabel: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!
    
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        imagePicker.delegate = self
        profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
        profileImageView.clipsToBounds = true
        
        getData()
        
        self.tableView.addSubview(self.myRefreshControl)
    }
    
    // MARK: Refresh Control
    
    lazy var myRefreshControl: UIRefreshControl = {
        let myRefreshControl = UIRefreshControl()
        myRefreshControl.addTarget(self, action:
            #selector(MySessionsViewController.handleRefresh(_:)),
                                   for: UIControlEvents.valueChanged)
        
        return myRefreshControl
    }()
    
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        getData()
        refreshControl.endRefreshing()
    }
    
    // MARK: Image Picker
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            profileImageView.contentMode = .scaleAspectFit
            profileImageView.image = pickedImage
        }
        
        // Profile image upload
        let imageName = NSUUID().uuidString
        let storageRef = Storage.storage().reference().child("profile_images").child("\(imageName).png")
        
        if let profileImage = self.profileImageView.image, let uploadData = UIImageJPEGRepresentation(profileImage, 0.1) {
            storageRef.putData(uploadData, metadata: nil, completion:
                {(metadata, error) in
                    if let error = error {
                        print(error)
                        return
                    }
                    else {
                        storageRef.downloadURL { (url, error) in
                            guard let profileImageURL = url?.absoluteString else {
                                return
                            }
                            self.userDataUpdateWithProfileImage(profileImageLink: profileImageURL)
                        }
                    }
            })
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: Actions
    
    @IBAction func profileImageSettingTapped(_ sender: Any) {
        imagePicker.allowsEditing = true
        imagePicker.sourceType = .photoLibrary
        
        present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func deleteAccountTapped(_ sender: Any) {
        let deleteAlert = UIAlertController(title: "Delete User", message: "This will permanently delete your account", preferredStyle: UIAlertControllerStyle.alert)
        
        let okAction = UIAlertAction(title: "OK", style: .default) { (action:UIAlertAction) in
            self.deleteUser()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: nil)
        
        deleteAlert.addAction(okAction)
        deleteAlert.addAction(cancelAction)
        
        self.present(deleteAlert, animated: true, completion: nil)
    }
    
    
    // MARK: Firebase Data Download
    
    func getData() {
        let uid = Auth.auth().currentUser?.uid
        Database.database().reference().child("users").child(uid!).observeSingleEvent(of: .value, with: {
            (snapshot) in
            
            if let dictionary = snapshot.value as? [String: AnyObject] {
                self.nameLabel.text = dictionary["name"] as? String
                self.genresLabel.text = dictionary["genres"] as? String
                self.instrumentsLabel.text = dictionary["instruments"] as? String
                if let profileImageURL = dictionary["profileImageURL"] as? String {
                    self.profileImageView.loadImageUsingCacheWithURLString(urlString: profileImageURL)
                }
                
                let city = dictionary["city"] as? String
                let country = dictionary["country"] as? String
                self.locationLabel.text = "\(city ?? ""), \(country ?? "")"
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        })
    }
    
    // MARK: Firebase Data Upload
    
    func userDataUpdateWithProfileImage(profileImageLink: String) {
        // Update the user photoURL
        let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
        changeRequest?.photoURL = NSURL(string: profileImageLink)! as URL
        changeRequest?.commitChanges { (error) in
            if let error = error {
                print(error)
            } else {
                // Change request successful
            }
        }
        let ref = Database.database().reference()
        let uid = Auth.auth().currentUser?.uid
        let usersRef = ref.child("users").child(uid!)
        let values = ["profileImageURL": profileImageLink]
        usersRef.updateChildValues(values, withCompletionBlock: { (error, ref) in
            if let error = error {
                print(error)
                return
            }
            else {
                // User data successfully updated
            }
        })
    }
    
    // MARK: User Deletion
    
    func deleteUser() {
        // Delete the user's data node
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }
        
        // Delete the user's sessions and delete the user from other sessions
        filterUserFromSessions(uid: uid)
        
        let ref = Database.database().reference()
        let userRef = ref.child("users").child(uid)
        
        userRef.removeValue()
        
        // Delete the user's profile
        let user = Auth.auth().currentUser
        
        user?.delete { error in
            if let error = error {
                print(error)
            } else {
                print ("User successfully deleted")
                
                self.performSegue(withIdentifier: "UnwindToLoginFromSettings", sender: nil)
            }
        }
    }
    
    func filterUserFromSessions(uid: String) {
        let allSessionsRef = Database.database().reference().child("all sessions")
        
        allSessionsRef.observe(.childAdded, with: {(snapshot) in
            if let dictionary = snapshot.value as? [String: AnyObject] {
                
                guard let hostUID = dictionary["hostUID"] as? String, let sessionID = dictionary["ID"] as? String
                    else {
                        return
                }
            
                // If the user is the host, delete the session
                // Otherwise, delete the user from the musician and invitee lists
                if uid == hostUID {
                    allSessionsRef.child(sessionID).removeValue()
                } else {
                    self.deleteUserFromSessionMusicians(uid: uid, sessionID: sessionID) { (userMusicianDeleted) in
                        if let _ = userMusicianDeleted {
                            self.deleteUserFromSessionInvitees(uid: uid, sessionID: sessionID)
                        }
                    }
                }
            }
        }, withCancel: nil)
    }
    
    func deleteUserFromSessionMusicians(uid: String, sessionID: String,
                                        completionHandler: @escaping deletedUserFromMusiciansClosure) {
        let allSessionsRef = Database.database().reference().child("all sessions")
        let sessionMusiciansRef = allSessionsRef.child(sessionID).child("musicians")
        
        sessionMusiciansRef.observe(.childAdded, with: {(snapshot) in
            if let dictionary = snapshot.value as? [String: AnyObject] {
                guard let musicianID = dictionary["musicianID"] as? String else {
                    return
                }
                
                if uid == musicianID {
                    sessionMusiciansRef.child(snapshot.key).removeValue()
                    completionHandler(true)
                }
            }
        })
        
        completionHandler(false)
    }
    
    func deleteUserFromSessionInvitees(uid: String, sessionID: String) {
        let allSessionsRef = Database.database().reference().child("all sessions")
        let sessionInviteesRef = allSessionsRef.child(sessionID).child("invitees")
        
        sessionInviteesRef.observe(.childAdded, with: {(snapshot) in
            if let dictionary = snapshot.value as? [String: AnyObject] {
                guard let musicianID = dictionary["musicianID"] as? String else {
                    return
                }
                
                if uid == musicianID {
                    sessionInviteesRef.child(snapshot.key).removeValue()
                }
            }
        })
    }
    
    // MARK: Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "EditName" || segue.identifier == "EditLocation"
            || segue.identifier == "EditInstruments" || segue.identifier == "EditGenres" {
            let nav = segue.destination as! UINavigationController
            let editSettingViewController = nav.topViewController as! EditSettingViewController
            
            var settingName = String()
            var settingVal = String()
            
            if segue.identifier == "EditName" {
                settingName = "Name"
                settingVal = nameLabel.text ?? ""
            } else if segue.identifier == "EditInstruments" {
                settingName = "Instruments"
                settingVal = instrumentsLabel.text ?? ""
            } else if segue.identifier == "EditGenres" {
                settingName = "Genres"
                settingVal = genresLabel.text ?? ""
            }
            
            editSettingViewController.settingName = settingName
            editSettingViewController.settingVal = settingVal
        }
    }
    
    @IBAction func unwindToProfileSettingsView(sender: UIStoryboardSegue) {
        getData()
    }
}
