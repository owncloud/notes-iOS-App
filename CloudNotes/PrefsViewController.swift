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
    
    @IBOutlet var serverTextField: NSTextField!
    @IBOutlet var usernameTextField: NSTextField!
    @IBOutlet var passwordTextField: NSSecureTextField!
    @IBOutlet var certificateSwitch: NSButton!
    @IBOutlet var connectionActivityIndicator: NSProgressIndicator!
    @IBOutlet var statusLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
              
        serverTextField.stringValue = KeychainHelper.server
        usernameTextField.stringValue = KeychainHelper.username
        passwordTextField.stringValue = KeychainHelper.password
        certificateSwitch.state = KeychainHelper.allowUntrustedCertificate ? .on : .off
        if KeychainHelper.server.isEmpty {
            statusLabel.stringValue = "Not connected to Notes on a server"
        } else {
            statusLabel.stringValue = "Connected to Notes on the server"
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
                    } else {
                        self?.pickServer()
                    }
                    self?.statusLabel.stringValue = "Connected to Notes on the server"
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
    
    @IBAction func onCertificateSwitch(_ sender: Any) {
        KeychainHelper.allowUntrustedCertificate = certificateSwitch.state == .on
    }
    
    func pickServer() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = NSLocalizedString("Server", comment: "Alert title for selecting server brand")
        alert.informativeText = NSLocalizedString("Unable to automatically detect type of server.\nPlease select:", comment: "Alert message for selecting server brand")
        alert.addButton(withTitle: "Nextcloud")
        alert.addButton(withTitle: "ownCloud")
        alert.buttons[0].keyEquivalent = "n"
        alert.buttons[1].keyEquivalent = "o"
        alert.beginSheetModal(for: self.view.window!) { response in
            switch response {
            case .alertFirstButtonReturn:
                KeychainHelper.isNextCloud = true
            case .alertSecondButtonReturn:
                KeychainHelper.isNextCloud = false
            default:
                KeychainHelper.isNextCloud = true
            }
        }
    }

}

