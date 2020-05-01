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
        
        let router = Router.allNotes(exclude: "")
        session
            .request(router, interceptor: LoginRequestInterceptor())
            .validate(contentType: [Router.applicationJson])
            .responseDecodable(of: [NoteStruct].self) { [weak self] response in
                var message: String?
                var title: String?
                switch response.result {
                case let .success(result):
                    if !result.isEmpty {
                        if let firstNote = result.first, !firstNote.etag.isEmpty {
                            KeychainHelper.isNextCloud = true
                        } else {
                            KeychainHelper.isNextCloud = false
                        }
                        self?.showSyncMessage()
                    } else {
                        self?.pickServer()
                    }
                case let .failure(error):
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

    func showSyncMessage() {
        #if os(iOS)
        var config = SwiftMessages.defaultConfig
        config.duration = .forever
        config.preferredStatusBarStyle = .default
        config.presentationContext = .viewController(self)
        SwiftMessages.show(config: config, viewProvider: {
            let view = MessageView.viewFromNib(layout: .cardView)
            view.configureTheme(.success, iconStyle: .default)
            view.configureDropShadow()
            view.configureContent(title: NSLocalizedString("Success", comment: "A message title"),
                                  body: NSLocalizedString("You are now connected to Notes on your server", comment: "A message"),
                                  iconImage: Icon.success.image,
                                  iconText: nil,
                                  buttonImage: nil,
                                  buttonTitle: NSLocalizedString("Close & Sync", comment: "Title of a button allowing the user to close the login screen and sync with the server"),
                                  buttonTapHandler: { [weak self] _ in
                                    SwiftMessages.hide()
                                    self?.dismiss(animated: true, completion: nil)
                                    NotificationCenter.default.post(name: .syncNotes, object: nil)
            })
            return view
        })
        #endif
    }

}

