//
//  PrefsViewController.swift
//  CloudNews
//
//  Created by Peter Hedlund on 11/23/18.
//  Copyright © 2018 Peter Hedlund. All rights reserved.
//

import Cocoa
import KeychainAccess
import Alamofire

class PrefsViewController: NSViewController {
    
    @IBOutlet var syncCheckbox: NSButton!
    @IBOutlet var intervalPopup: NSPopUpButton!
    @IBOutlet var serverTextField: NSTextField!
    @IBOutlet var usernameTextField: NSTextField!
    @IBOutlet var passwordTextField: NSSecureTextField!
    @IBOutlet var connectionActivityIndicator: NSProgressIndicator!
    @IBOutlet var statusLabel: NSTextField!
    @IBOutlet var tabView: NSTabView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let sync = UserDefaults.standard.bool(forKey: "sync")
        self.syncCheckbox.state = sync == true ? .on : .off
        self.intervalPopup.isEnabled = sync
        let interval = UserDefaults.standard.integer(forKey: "interval")
        self.intervalPopup.selectItem(at: interval)
        
        let keychain = Keychain(service: "com.peterandlinda.CloudNews")
        let username = keychain["username"]
        let password = keychain["password"]
        let server = UserDefaults.standard.string(forKey: "server")
        let version = UserDefaults.standard.string(forKey: "version")
        self.serverTextField.stringValue = server ?? ""
        self.usernameTextField.stringValue = username ?? ""
        self.passwordTextField.stringValue = password ?? ""
        if server == nil || server?.count == 0 {
            self.tabView.selectLastTabViewItem(nil)
        }
        if let version = version, version.count > 0 {
            self.statusLabel.stringValue = "News version \(version) found on server"
        } else {
            self.statusLabel.stringValue = "Not connected to News on a server"
        }
    }
    
    @IBAction func onConnect(_ sender: Any) {
        self.connectionActivityIndicator.startAnimation(nil)
        var serverAddress = serverTextField.stringValue
        let username = self.usernameTextField.stringValue
        let password = self.passwordTextField.stringValue

        serverAddress = serverAddress.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        if !serverAddress.contains("://"),
            !serverAddress.hasPrefix("http") {
            serverAddress = "https://\(serverAddress)"
        }
        KeychainHelper.server = serverAddress
        KeychainHelper.username = username
        KeychainHelper.password = password
        let shouldRetry = !serverAddress.hasSuffix(".php")
        
        let router = Router.allNotes(exclude: "")
        NoteSessionManager
            .shared
            .request(router)
            .validate(statusCode: 200..<300)
            .validate(contentType: [Router.applicationJson])
            .responseDecodable { [weak self] (response: DataResponse<[NoteStruct]>) in
                var message: String?
                var title: String?
                switch response.result {
                case .success:
                    if let notes = response.value, !notes.isEmpty {
                        if let firstNote = notes.first, !firstNote.etag.isEmpty {
                            KeychainHelper.isNextCloud = true
                        } else {
                            KeychainHelper.isNextCloud = false
                        }
                        //self?.showSyncMessage()
                    } else {
                        self?.pickServer()
                    }
                case .failure(let error):
                    if (shouldRetry) {
                        self?.serverTextField.stringValue = "\(serverAddress)/index.php"
                        self?.onConnect(self as Any)
                        return
                    }
                    KeychainHelper.server = ""
                    KeychainHelper.username = ""
                    KeychainHelper.password = ""
                    if let urlResponse = response.response {
                        switch urlResponse.statusCode {
                        case 200:
                            title = NSLocalizedString("Notes not found", comment: "An error message title")
                            message = NSLocalizedString("Notes could not be found on your server. Make sure it is installed and enabled", comment: "An error message");
                        case 401:
                            title = NSLocalizedString("Unauthorized", comment: "An error message title")
                            message = NSLocalizedString("Check username and password.", comment: "An error message")
                        case 404:
                            title = NSLocalizedString("Server not found", comment: "An error message title")
                            message = NSLocalizedString("A server installation could not be found. Check the server address.", comment: "An error message")
                        default:
                            title = NSLocalizedString("Connection failure", comment: "An error message title")
                            message = error.localizedDescription
                        }
                    } else {
                        title = NSLocalizedString("Connection failure", comment: "An error message title")
                        message = error.localizedDescription
                    }
                    if let title = title, let body = message {
                        NotesManager.shared.showErrorMessage(message: ErrorMessage(title: title, body: body))
                    }
                }
                self?.connectionActivityIndicator.stopAnimation(nil)
        }
    }
    
    @IBAction func onSyncCheckbox(_ sender: Any) {
        if self.syncCheckbox.state == .on {
            self.intervalPopup.isEnabled = true
            UserDefaults.standard.set(true, forKey: "sync")
        } else {
            self.intervalPopup.isEnabled = false
            UserDefaults.standard.set(false, forKey: "sync")
        }
    }
    
    @IBAction func onIntervalPopup(_ sender: Any) {
        UserDefaults.standard.set(self.intervalPopup.indexOfSelectedItem, forKey: "interval")
//TODO        NewsManager.shared.setupSyncTimer()
    }
    
    func pickServer() {
//        let alert = UIAlertController(title: NSLocalizedString("Server", comment: "Alert title for selecting server brand"),
//                                      message: NSLocalizedString("Unable to automatically detect type of server.\nPlease select:", comment: "Alert message for selecting server brand"),
//                                      preferredStyle: .alert)
//        let nextCloudAction = UIAlertAction(title: "NextCloud", style: .default) { [weak self] (_) in
//            KeychainHelper.isNextCloud = true
//            self?.showSyncMessage()
//        }
//        let ownCloudAction = UIAlertAction(title: "ownCloud", style: .default) { [weak self] (_) in
//            KeychainHelper.isNextCloud = false
//            self?.showSyncMessage()
//        }
//        alert.addAction(nextCloudAction)
//        alert.addAction(ownCloudAction)
//        self.present(alert, animated: true, completion: nil)
    }

}

