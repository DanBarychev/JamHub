//
//  CurrentJamViewController.swift
//  JamCenter
//
//  Created by Daniel Barychev on 7/3/17.
//  Copyright © 2017 Daniel Barychev. All rights reserved.
//

import UIKit
import Firebase

class CurrentJamViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: Properties
    
    var currentSession: Session?
    var origin: String?
    var musicians = [Musician]()
    var invitees = [Musician]()
    var sessionCode = String()
    var sessionID = String()
    var sessionHostUID = String()
    var currentUserMusician = Musician()
    
    @IBOutlet weak var startTimeLabel: UILabel!
    @IBOutlet weak var hostNameLabel: UILabel!
    @IBOutlet weak var hostImageView: UIImageView!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var genreLabel: UILabel!
    @IBOutlet weak var manageButton: UIBarButtonItem!
    @IBOutlet weak var inviteMusiciansButton: UIButton!
    @IBOutlet weak var joinSessionButton: UIButton!
    
    @IBOutlet weak var tableView: UITableView!
    
    typealias MusicianClosure = (Musician?) -> Void
    typealias PresenceClosure = (Bool?) -> Void
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        manageButton.isEnabled = false
        inviteMusiciansButton.isHidden = true
        
        tableView.delegate = self
        tableView.dataSource = self
        
        self.hostImageView.layer.cornerRadius = self.hostImageView.frame.size.width / 2
        self.hostImageView.clipsToBounds = true
        
        joinSessionButton.layer.cornerRadius = 25
        joinSessionButton.layer.borderWidth = 2
        joinSessionButton.layer.borderColor = UIColor.black.cgColor
        
        startTimeLabel.layer.cornerRadius = 8
        startTimeLabel.layer.borderWidth = 1
        startTimeLabel.layer.borderColor = UIColor.black.cgColor
        
        setupJamSesion()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Remove observer
        Database.database().reference().removeAllObservers()
    }
    
    // MARK: Session Setup Through Firebase
    
    func setupJamSesion() {
        if let currentJamSession = currentSession {
            navigationItem.title = currentJamSession.name
            startTimeLabel.text = currentJamSession.startTime
            hostNameLabel.text = currentJamSession.host
            locationLabel.text = currentJamSession.location
            genreLabel.text = currentJamSession.genre
            sessionCode = currentJamSession.code ?? ""
            sessionID = currentJamSession.ID ?? ""
            sessionHostUID = currentJamSession.hostUID ?? ""
            
            //See what to do with the current user
            if let userID = Auth.auth().currentUser?.uid {
                getMusician(musicianID: userID) { (musician) in
                    if let musician = musician {
                        self.currentUserMusician = musician
                        
                        // If we come from SetTime, the user is the only musician
                        if self.origin == "SetTime" {
                            if let hostImageURL = musician.profileImageURL {
                                self.hostImageView.loadImageUsingCacheWithURLString(urlString: hostImageURL)
                            }
                            
                            self.musicians = [musician]
                            
                            DispatchQueue.main.async {
                                self.tableView.reloadData()
                            }
                        }
                    }
                }
                
                if currentJamSession.hostUID == userID {
                    manageButton.isEnabled = true
                    inviteMusiciansButton.isHidden = false
                    self.joinSessionButton.setTitle("View Media", for: UIControlState.normal)
                } else {
                    checkMusicianParticipation(musicianID: userID)
                }
            }
            
            // Get all session musicians if we don't come from NewSession
            if origin != "SetTime" {
                getMusicians(sessionID: sessionID)
            }
        }
    }

    // MARK: Table View
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return musicians.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print(musicians)
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "CurrentJamMusicianCell", for: indexPath) as! CurrentJamMusicianTableViewCell

        let musician = musicians[indexPath.row]
        
        cell.nameLabel.text = musician.name
        cell.instrumentsLabel.text = musician.instruments
        if let profileImageURL = musician.profileImageURL {
            cell.profileImageView.loadImageUsingCacheWithURLString(urlString: profileImageURL)
        }
        cell.profileImageView.layer.cornerRadius = cell.profileImageView.frame.size.width / 2
        cell.profileImageView.clipsToBounds = true
        
        return cell
    }
    
    func requestSessionCode() {
        let alertController = UIAlertController(title: "Session Code", message: "Please input the session code", preferredStyle: .alert)
        
        let confirmAction = UIAlertAction(title: "Join", style: .default) { (_) in
            if let field = alertController.textFields?[0] {
                if field.text == self.sessionCode {
                    self.joinSessionFromCode()
                } else {
                    self.presentIncorrectCodeAlert()
                }
            } else {
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
        
        alertController.addTextField { (textField) in
            textField.placeholder = "Session Code"
        }
        
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func presentIncorrectCodeAlert() {
        let alertController = UIAlertController(title: "Incorrect Code", message: "An invalid code was entered", preferredStyle: .alert)
        
        let confirmAction = UIAlertAction(title: "OK", style: .default)
        
        alertController.addAction(confirmAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    // MARK: Firebase Functions
    
    func getMusicians(sessionID: String) {
        self.musicians.removeAll()
        
        let allSessionsRef = Database.database().reference().child("all sessions")
        let musiciansRef = allSessionsRef.child(sessionID).child("musicians")
        
        musiciansRef.observe(.childAdded, with: {(musicianSnapshot) in
            if let dictionary = musicianSnapshot.value as? [String: AnyObject] {
                if let musicianID = dictionary["musicianID"] as? String {
                    self.getMusician(musicianID: musicianID) { (musician) in
                        if let musician = musician {
                            // If we have found the host, set the host image
                            if musicianID == self.sessionHostUID {
                                if let hostImageURL = musician.profileImageURL {
                                    self.hostImageView.loadImageUsingCacheWithURLString(urlString: hostImageURL)
                                }
                            }
                            
                            self.musicians.append(musician)
                            
                            DispatchQueue.main.async {
                                self.tableView.reloadData()
                            }
                        }
                    }
                }
            }
        })
        
        allSessionsRef.removeAllObservers()
    }
    
    func getMusician(musicianID: String, completionHandler: @escaping MusicianClosure) {
        let ref = Database.database().reference()
        let musicianRef = ref.child("users").child(musicianID)
        
        musicianRef.observe(.value, with: { (snapshot) in
            if let dictionary = snapshot.value as? [String: AnyObject] {
                let musician = Musician()

                musician.uid = musicianID
                musician.name = dictionary["name"] as? String
                musician.genres = dictionary["genres"] as? String
                musician.instruments = dictionary["instruments"] as? String
                musician.profileImageURL = dictionary["profileImageURL"] as? String
                musician.city = dictionary["city"] as? String
                musician.country = dictionary["country"] as? String
                musician.numSessions = Int((dictionary["numSessions"] as? String) ?? "0")
                
                completionHandler(musician)
            }
        }, withCancel: nil)
    }
    
    func checkMusicianParticipation(musicianID: String) {
        let ref = Database.database().reference()
        let sessionKey = ref.child("all sessions").child(sessionID)
        let sessionMusiciansKey = sessionKey.child("musicians")
        let sessionInviteesKey = sessionKey.child("invitees")
        
        sessionMusiciansKey.observe(.childAdded, with: {(snapshot) in
            if let dictionary = snapshot.value as? [String: AnyObject] {
                
                let sessionMusicianID = dictionary["musicianID"] as? String
                
                if musicianID == sessionMusicianID {
                    self.joinSessionButton.setTitle("View Media", for: UIControlState.normal)
                } else {
                    checkIfMusicianIsInvited()
                }
            }
        })
        
        func checkIfMusicianIsInvited() {
            // Checking musician invitation
            sessionInviteesKey.observe(.childAdded, with: {(snapshot) in
                if let dictionary = snapshot.value as? [String: AnyObject] {
                    
                    let sessionMusicianID = dictionary["musicianID"] as? String
                    
                    if musicianID == sessionMusicianID {
                        self.joinSessionButton.setTitle("Accept Invitation", for: UIControlState.normal)
                    }
                }
            })
        }
        
        sessionKey.removeAllObservers()
        sessionMusiciansKey.removeAllObservers()
        sessionInviteesKey.removeAllObservers()
    }
    
    func addMusicianToSession() {
        musicians.append(currentUserMusician)
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
        
        let ref = Database.database().reference()
        let allSessionsKey = ref.child("all sessions").child(sessionID)
        
        let allSessionsMusiciansKey = allSessionsKey.child("musicians").childByAutoId()
        
        guard let musicianID = Auth.auth().currentUser?.uid
            else {
                return
        }
        
        let musicianValues = ["musicianID": musicianID]
        
        allSessionsMusiciansKey.updateChildValues(musicianValues, withCompletionBlock: { (error, ref) in
            if let error = error {
                print(error)
                
                return
            } else {
                // Current user added to session
            }
        })
        
        allSessionsKey.removeAllObservers()
        allSessionsMusiciansKey.removeAllObservers()
    }
    
    func joinSessionFromCode() {
        addMusicianToSession()
        updateUserInfo()
        performSegue(withIdentifier: "JoinSession", sender: nil)
    }
    
    func joinSessionFromInvitation() {
        addMusicianToSession()
        updateUserInfo()
        deleteInvitation()
        performSegue(withIdentifier: "JoinSession", sender: nil)
    }
    
    func deleteInvitation() {
        let ref = Database.database().reference()
        if let uid = Auth.auth().currentUser?.uid {
            let invitationsRef = ref.child("users").child(uid).child("invitations")
            
            invitationsRef.observe(.childAdded, with: {(snapshot) in
                if let dictionary = snapshot.value as? [String: AnyObject] {
                    if let invitationSessionID = dictionary["sessionID"] as? String {
                        if invitationSessionID == self.sessionID {
                            snapshot.ref.removeValue()
                        }
                    }
                }
            })
            
            let inviteesRef = ref.child("all sessions").child(sessionID).child("invitees")
            inviteesRef.observe(.childAdded, with: {(snapshot) in
                if let inviteesDictionary = snapshot.value as? [String: AnyObject] {
                    if let inviteeUID = inviteesDictionary["musicianID"] as? String {
                        if inviteeUID == uid {
                            snapshot.ref.removeValue()
                        }
                    }
                }
            })
            
            inviteesRef.removeAllObservers()
            invitationsRef.removeAllObservers()
        }
    }
    
    func updateUserInfo() {
        let ref = Database.database().reference()
        let uid = Auth.auth().currentUser?.uid
        let userKey = ref.child("users").child(uid!)
        
        let numSessions = String((currentUserMusician.numSessions ?? 0) + 1)
        guard let lastSession = navigationItem.title
            else {
                return
        }
        
        let values = ["numSessions": numSessions, "lastSession": lastSession]
        
        userKey.updateChildValues(values, withCompletionBlock: { (error, ref) in
            if let error = error {
                print(error)
                
                return
            } else {
                // Musician information updated
            }
        })
        
        userKey.removeAllObservers()
    }
    
    // MARK: Actions
    
    @IBAction func joinSession(_ sender: Any) {
        if joinSessionButton.currentTitle == "Join Session" {
            requestSessionCode()
        } else if joinSessionButton.currentTitle == "Accept Invitation" {
            joinSessionFromInvitation()
        } else {
            performSegue(withIdentifier: "JoinSession", sender: nil)
        }
    }
    
    @IBAction func backButtonTapped(_ sender: UIBarButtonItem) {
        if origin == "MySessions" || origin == "SetTime" {
            self.performSegue(withIdentifier: "UnwindToMySessionsFromCurrentJam", sender: nil)
        } else if origin == "CurrentJams" {
            self.performSegue(withIdentifier: "UnwindToCurrentJamsFromCurrentJam", sender: nil)
        } else if origin == "Invitations" {
            self.performSegue(withIdentifier: "UnwindToInvitationsFromCurrentJam", sender: nil)
        }
    }
    
    @IBAction func inviteMusicianTapped(_ sender: UIButton) {
        performSegue(withIdentifier: "GoToInviteMusiciansFromCurrentJam", sender: nil)
    }
    
    @IBAction func manageJamSession(_ sender: Any) {
        performSegue(withIdentifier: "GoToMyActiveSessionFromCurrentJam", sender: nil)
    }
    
    // MARK: Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "JoinSession" {
            let nav = segue.destination as! UINavigationController
            let newViewController = nav.topViewController as! ActiveCurrentSessionViewController
            
            newViewController.currentSession = currentSession
        } else if segue.identifier == "ViewMusician" {
            let nav = segue.destination as! UINavigationController
            let newViewController = nav.topViewController as! OtherMusicianProfileViewController
            
            if let selectedJamCell = sender as? CurrentJamMusicianTableViewCell
            {
                let indexPath = tableView.indexPath(for: selectedJamCell)!
                let selectedMusician = musicians[indexPath.row]
                newViewController.selectedMusician = selectedMusician
                newViewController.origin = "CurrentJam"
            }
        } else if segue.identifier == "GoToMyActiveSessionFromCurrentJam" {
            let nav = segue.destination as! UINavigationController
            let newViewController = nav.topViewController as! MyActiveSessionViewController
            
            newViewController.mySession = currentSession
        } else if segue.identifier == "GoToInviteMusiciansFromCurrentJam" {
            let nav = segue.destination as! UINavigationController
            let newViewController = nav.topViewController as! InviteMusiciansTableViewController
            
            newViewController.origin = "CurrentJam"
            newViewController.currentSession = currentSession
        }
    }
    
    @IBAction func unwindToCurrentJam(sender: UIStoryboardSegue) {
        setupJamSesion()
    }
}
