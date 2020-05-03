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
    
    private let session = Session(serverTrustManager: CustomServerTrustPolicyManager(allHostsMustBeEvaluated: true, evaluators: [:]))

    override func viewDidLoad() {
        super.viewDidLoad()
              
        serverTextField.stringValue = KeychainHelper.server
        usernameTextField.stringValue = KeychainHelper.username
        passwordTextField.stringValue = KeychainHelper.password
        certificateSwitch.state = KeychainHelper.allowUntrustedCertificate ? .on : .off
        if KeychainHelper.server.isEmpty {
            statusLabel.stringValue = NSLocalizedString("Not connected to Notes on a server", comment: "Status information, not connected")
        } else {
            statusLabel.stringValue = NSLocalizedString("Connected to Notes on the server", comment: "Status information, connected")
        }
    }
    
    @IBAction func onConnect(_ sender: Any) {
        self.connectionActivityIndicator.startAnimation(nil)
        let serverAddress = serverTextField.stringValue
        let username = self.usernameTextField.stringValue
        let password = self.passwordTextField.stringValue

        NotesManager.shared.login(server: serverAddress, username: username, password: password) { [weak self] in
            self?.connectionActivityIndicator.stopAnimation(nil)
        }
    }
    
    @IBAction func onCertificateSwitch(_ sender: Any) {
        KeychainHelper.allowUntrustedCertificate = certificateSwitch.state == .on
    }
    
}

